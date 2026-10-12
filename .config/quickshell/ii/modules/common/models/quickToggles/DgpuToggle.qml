import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles

// Compute (CUDA) toggle for the NVIDIA dGPU. Drives dgpu-compute.service via
// systemctl (authorised passwordless for wheel by 49-dgpu-toggle.rules).
// Tap = on/off. (Display mode is a separate launcher — it needs a relogin.)
QuickToggleModel {
    id: root
    name: Translation.tr("dGPU (CUDA)")
    icon: "developer_board"
    tooltipText: Translation.tr("NVIDIA dGPU — compute (CUDA) mode")

    property bool busy: false
    property bool unitExists: false
    // Display mode is a superset of compute (it also loads nvidia + nvidia_uvm),
    // so CUDA is available in display mode without dgpu-compute.service being active.
    // Track that separately so the pill doesn't mislabel or tear the display down.
    property bool cudaViaDisplay: false
    available: unitExists
    statusText: busy ? Translation.tr("Switching…")
                     : (cudaViaDisplay ? Translation.tr("On · via display")
                                       : (toggled ? Translation.tr("On · CUDA")
                                                  : Translation.tr("Off")))

    mainAction: () => {
        if (root.busy || !root.unitExists) return;
        // In display mode CUDA already works. Starting dgpu-compute.service here
        // would stop dgpu-display.service (its ExecStartPre) and hot-remove the
        // card, killing the external monitor for no gain — refuse and explain.
        if (root.cudaViaDisplay) {
            Quickshell.execDetached(["notify-send", "-a", "dGPU",
                Translation.tr("CUDA already available"),
                Translation.tr("Display mode already provides CUDA. Turn off the Display toggle to release the GPU.")]);
            return;
        }
        root.busy = true;
        // Off goes through a helper: plain `systemctl stop` does nothing once the unit has failed,
        // and browsers that grabbed the card have to let go first.
        actionProc.command = root.toggled ? [Quickshell.shellPath("scripts/glassbar/dgpu-off.sh")]
                                          : ["systemctl", "start", "dgpu-compute.service"];
        actionProc.running = true;
    }

    Process {
        id: actionProc
        stderr: StdioCollector { id: actionErr }
        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "dGPU",
                    Translation.tr("Couldn't switch the dGPU"),
                    actionErr.text.trim() || ("exit " + code + " — see: journalctl -u dgpu-compute.service")]);
            }
            statePoll.running = true;
        }
    }

    // Reflect the real card mode via dgpu-status (off|compute|display|present) so
    // the pill is correct even when CUDA rides on display mode. Also catches
    // reboots / external changes.
    Process {
        id: statePoll
        running: true
        command: ["/usr/local/sbin/dgpu-status"]
        stdout: StdioCollector {
            id: stateOut
            onStreamFinished: {
                const s = stateOut.text.trim();
                root.cudaViaDisplay = (s === "display");
                root.toggled = (s === "compute" || s === "display");
            }
        }
    }
    Process {
        id: existsPoll
        running: true
        command: ["bash", "-c", "systemctl list-unit-files dgpu-compute.service >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            id: existsOut
            onStreamFinished: root.unitExists = (existsOut.text.trim() === "yes")
        }
    }
    Timer {
        interval: 6000; running: true; repeat: true
        onTriggered: if (!root.busy) statePoll.running = true
    }
}
