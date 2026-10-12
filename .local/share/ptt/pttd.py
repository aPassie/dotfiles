#!/usr/bin/env python3
"""Push-to-talk dictation daemon (Parakeet Redux, CPU).

Reads "down"/"up" lines from $XDG_RUNTIME_DIR/ptt.fifo (written by xremap on
Right Ctrl press/release): record while held, transcribe + type on release.
"""
import os, signal, subprocess, sys, time, threading

MIN_AUDIO_S = 0.35
RUN = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
FIFO = f"{RUN}/ptt.fifo"
WAV = f"{RUN}/ptt.wav"
NOTIFY_ID = "91731"


def notify(msg, urgency="low", timeout=2000):
    subprocess.Popen(["notify-send", "-a", "Dictation", "-u", urgency, "-t", str(timeout),
                      "-r", NOTIFY_ID, "-h", "string:x-canonical-private-synchronous:ptt",
                      "Dictation", msg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def log(*a):
    print(*a, file=sys.stderr, flush=True)


class PTT:
    def __init__(self, speech):
        self.speech = speech
        self.rec = None          # pw-record process
        self.lock = threading.Lock()

    def start(self):
        try:
            os.unlink(WAV)
        except FileNotFoundError:
            pass
        self.rec = subprocess.Popen(
            ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", WAV],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def finish(self):
        rec, self.rec = self.rec, None
        rec.send_signal(signal.SIGINT)   # lets pw-record finalize the WAV header
        try:
            rec.wait(2)
        except subprocess.TimeoutExpired:
            rec.kill()
        threading.Thread(target=self.transcribe, daemon=True).start()

    def transcribe(self):
        with self.lock:
            try:
                size = os.path.getsize(WAV)
            except FileNotFoundError:
                return
            if (size - 44) / 32000 < MIN_AUDIO_S:
                return
            t = time.time()
            try:
                text = self.speech.transcribe(audio=WAV)["text"].strip()
            except Exception as e:
                log("transcribe failed:", e)
                notify(f"Transcription failed: {e}", "critical", 4000)
                return
            log(f"{time.time() - t:.2f}s: {text!r}")
            if text:
                subprocess.run(["wtype", "--", text + " "])

    def down(self):
        if self.rec is None:
            self.start()

    def up(self):
        if self.rec is not None:
            self.finish()


def main():
    import moondream as md
    speech = md.photon("moondream/parakeet-redux", device="cpu").__enter__()
    ptt = PTT(speech)
    if not os.path.exists(FIFO):
        os.mkfifo(FIFO, 0o600)
    log("ready")
    # O_RDWR keeps a writer open ourselves, so the FIFO never hits EOF between presses
    with os.fdopen(os.open(FIFO, os.O_RDWR), "rb", buffering=0) as f:
        for line in iter(f.readline, b""):
            cmd = line.strip()
            if cmd == b"down":
                ptt.down()
            elif cmd == b"up":
                ptt.up()


if __name__ == "__main__":
    main()
