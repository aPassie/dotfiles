pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// State behind the Control Centre's detail panels: night light (wlsunset, which works on niri;
// the shell's older Hyprsunset service needs Hyprland), the keep-awake timer, and dGPU info.
Singleton {
    id: root

    // ── Night light ─────────────────────────────────────────────────────────
    readonly property int minKelvin: 2500
    readonly property int maxKelvin: 6500
    property bool nightOn: false
    property real gamma: 1.0 // 0.5 .. 1.0
    readonly property int temperature: Math.min(Math.max(Config.options?.light?.night?.colorTemperature ?? 4000, minKelvin), maxKelvin)
    readonly property bool automatic: Config.options?.light?.night?.automatic ?? false
    readonly property string from: Config.options?.light?.night?.from ?? "19:00"
    readonly property string to: Config.options?.light?.night?.to ?? "06:30"

    function toggleNight() { nightOn = !nightOn }
    function setTemperature(k) {
        Config.options.light.night.colorTemperature = Math.round(Math.min(Math.max(k, minKelvin), maxKelvin) / 50) * 50
        apply()
    }
    function setGamma(g) {
        gamma = Math.round(Math.min(Math.max(g, 0.5), 1.0) * 100) / 100
        apply()
    }
    function setAutomatic(on) {
        Config.options.light.night.automatic = on
        if (on) nightOn = shouldBeOn
    }
    function minutesOf(s) { const p = String(s).split(":"); return Number(p[0]) * 60 + Number(p[1]) }
    function shiftTime(which, delta) { // which: "from" or "to"; delta in minutes
        let m = (minutesOf(which === "from" ? from : to) + delta + 1440) % 1440
        const text = String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0")
        if (which === "from") Config.options.light.night.from = text
        else Config.options.light.night.to = text
    }
    readonly property bool shouldBeOn: {
        const now = DateTime.clock.hours * 60 + DateTime.clock.minutes
        const a = minutesOf(from), b = minutesOf(to)
        return a <= b ? (now >= a && now < b) : (now >= a || now < b)
    }
    onShouldBeOnChanged: if (automatic) nightOn = shouldBeOn
    Component.onCompleted: if (automatic) nightOn = shouldBeOn

    onNightOnChanged: apply()
    function apply() { // wlsunset reads its settings at start, so changes mean a restart
        sunset.running = false
        relaunch.restart()
    }
    Timer { id: relaunch; interval: 180; onTriggered: sunset.running = root.nightOn }
    Process {
        id: sunset
        // both temperatures set (almost) equal, so the warmth holds whatever the time of day
        command: ["wlsunset", "-t", String(root.temperature), "-T", String(root.temperature + 1),
                  "-S", "06:00", "-s", "18:00", "-g", root.gamma.toFixed(2)]
    }

    IpcHandler { // e.g. for a key binding: qs -c ii ipc call nightLight toggle
        target: "nightLight"
        function toggle(): void { root.toggleNight() }
        function on(): void { root.nightOn = true }
        function off(): void { root.nightOn = false }
    }

    // ── Keep awake ──────────────────────────────────────────────────────────
    property int awakeChoice: 0      // minutes chosen; 0 = until switched off
    property double awakeUntil: 0    // ms timestamp, 0 = no limit
    property int awakeMinutesLeft: 0
    function keepAwake(minutes) {
        awakeChoice = minutes
        awakeUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0
        awakeMinutesLeft = minutes
        Idle.toggleInhibit(true)
    }
    function stopAwake() {
        awakeUntil = 0
        awakeMinutesLeft = 0
        Idle.toggleInhibit(false)
    }
    Timer {
        interval: 10000
        repeat: true
        running: root.awakeUntil > 0
        onTriggered: {
            const left = root.awakeUntil - Date.now()
            if (left <= 0) root.stopAwake()
            else root.awakeMinutesLeft = Math.ceil(left / 60000)
        }
    }

    // ── Session ─────────────────────────────────────────────────────────────
    // Set GLASS_DRY_RUN=1 in the shell's environment to log these instead of running them.
    readonly property bool dryRun: (Quickshell.env("GLASS_DRY_RUN") ?? "") !== ""
    readonly property var sessionCommands: ({
        lock: ["sh", "-c", "pidof hyprlock || hyprlock"],
        sleep: ["systemctl", "suspend"],
        hibernate: ["systemctl", "hibernate"],
        logout: ["niri", "msg", "action", "quit", "--skip-confirmation"],
        restart: ["systemctl", "reboot"],
        shutdown: ["systemctl", "poweroff"],
        firmware: ["systemctl", "reboot", "--firmware-setup"],
        tasks: ["bash", "-c", Config.options?.apps?.taskManager ?? "missioncenter"]
    })
    function session(action) {
        if (dryRun) { console.log("[glass] session (dry run):", action); return }
        if (action === "reload") {
            Quickshell.execDetached(["niri", "msg", "action", "reload-config"])
            Quickshell.reload(true)
            return
        }
        const cmd = sessionCommands[action]
        if (cmd) Quickshell.execDetached(cmd)
    }

    // ── dGPU ────────────────────────────────────────────────────────────────
    property string gpuPower: ""   // e.g. "18 W", empty when unknown
    property var gpuUsers: []      // [{ name, memory }]
    function refreshGpu() {
        if (Displays.dgpuMode === "off" || Displays.dgpuMode === "") {
            gpuPower = ""
            gpuUsers = []
            return
        }
        if (!gpuProc.running) gpuProc.running = true
    }
    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | head -n1; echo ---; nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---")
                const w = parseFloat((parts[0] || "").trim())
                root.gpuPower = isNaN(w) ? "" : Math.round(w) + " W"
                root.gpuUsers = (parts[1] || "").trim().split("\n").filter(l => l.trim().length > 0).map(l => {
                    const f = l.split(",")
                    return { name: f[0].trim().split("/").pop(), memory: (f[1] || "").trim() }
                })
            }
        }
    }
}
