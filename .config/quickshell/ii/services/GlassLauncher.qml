pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

// State and search behind the glass launcher (Super+Space) and clipboard picker (Super+Y).
// Modes: "" (everything), "apps", "clipboard", "files", "actions".
Singleton {
    id: root

    property bool open: false
    property string mode: ""
    property string query: ""
    property bool rail: false          // the four mode buttons are showing
    property string armed: ""          // key of an action waiting for a second Enter
    property int thumbRev: 0
    readonly property var modes: ["apps", "clipboard", "files", "actions"]
    readonly property var modeNames: ({ apps: "Applications", clipboard: "Clipboard", files: "Files", actions: "Actions" })
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/glassbar/clip"
    readonly property string home: Quickshell.env("HOME")
    // names of the macOS-style app icons that exist, so a row never asks for a missing file
    property var macIcons: ({})
    Process {
        running: true
        command: ["sh", "-c", "ls /usr/share/icons/WhiteSur-dark/apps/scalable/ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}
                text.split("\n").forEach(f => { if (f.endsWith(".svg")) m[f.slice(0, -4)] = true })
                root.macIcons = m
            }
        }
    }

    function show(m) {
        mode = m ?? ""
        rail = mode.length > 0
        query = ""
        armed = ""
        open = true
        if (!rail) railSoon.restart()
        GlassPanels.close()
        if (mode === "clipboard" || mode === "") Cliphist.refresh()
        if (mode === "clipboard") makeThumbs()
    }
    function hide() { open = false; armed = ""; railSoon.stop() }
    // Two seconds after opening, the mode buttons slide out on their own.
    Timer { id: railSoon; interval: 2000; onTriggered: if (root.open) root.rail = true }
    function toggle(m) {
        if (open && mode === (m ?? "")) hide()
        else show(m)
    }
    function setMode(m) {
        mode = (mode === m) ? "" : m
        rail = true
        armed = ""
        if (mode === "clipboard") { Cliphist.refresh(); makeThumbs() }
    }
    onQueryChanged: { armed = ""; if (mode === "files") fileDebounce.restart() }
    onModeChanged: if (mode === "files") fileDebounce.restart()

    // ── Actions ─────────────────────────────────────────────────────────────
    readonly property var actionList: [
        { key: "lock", title: "Lock", glyph: 0x1003A1, run: () => GlassControls.session("lock") },
        { key: "sleep", title: "Sleep", glyph: 0x1001BA, run: () => GlassControls.session("sleep") },
        { key: "restart", title: "Restart", glyph: 0x100148, confirm: true, run: () => GlassControls.session("restart") },
        { key: "shutdown", title: "Shut down", glyph: 0x1001A8, confirm: true, run: () => GlassControls.session("shutdown") },
        { key: "logout", title: "Log out", glyph: 0x100189, confirm: true, run: () => GlassControls.session("logout") },
        { key: "night", title: "Night Light", state: () => GlassControls.nightOn ? "On" : "Off", glyph: 0x1001BA, run: () => GlassControls.toggleNight() },
        { key: "awake", title: "Keep Awake", state: () => Idle.inhibit ? "On" : "Off", glyph: 0x100E19, run: () => Idle.inhibit ? GlassControls.stopAwake() : GlassControls.keepAwake(GlassControls.awakeChoice) },
        { key: "mic", title: "Microphone", state: () => (Audio.source?.audio?.muted ?? false) ? "Muted" : "On", glyph: 0x1002B1, run: () => Audio.toggleMicMute() },
        { key: "mute", title: "Mute sound", state: () => (Audio.sink?.audio?.muted ?? false) ? "Muted" : "On", glyph: 0x1002A3, run: () => Audio.toggleMute() },
        { key: "dnd", title: "Do not disturb", state: () => Notifications.silent ? "On" : "Off", glyph: 0x1002DE, run: () => { Notifications.silent = !Notifications.silent } },
        { key: "control", title: "Control Centre", glyph: 0x1008CB, run: () => { GlassPanels.open = "control" } },
        { key: "wifi", title: "Wi-Fi", glyph: 0x100647, run: () => { GlassPanels.open = "wifi" } },
        { key: "bluetooth", title: "Bluetooth", glyph: 0x100448, run: () => { GlassPanels.open = "bluetooth" } },
        { key: "notifications", title: "Notifications", glyph: 0x1002DA, run: () => { GlassPanels.open = "notifications" } },
        { key: "screenshot", title: "Screenshot a region", glyph: 0x1008B9, run: () => Quickshell.execDetached(["niri", "msg", "action", "screenshot"]) },
        { key: "reload", title: "Reload shell and niri", glyph: 0x100148, run: () => GlassControls.session("reload") },
        { key: "tasks", title: "Task manager", glyph: 0x100AE5, run: () => GlassControls.session("tasks") },
        { key: "settings", title: "Shell settings", glyph: 0x1008CB, run: () => GlassControls.session("settings") }
    ]

    // ── Results ─────────────────────────────────────────────────────────────
    function appItems(limit) {
        const q = query.trim()
        const list = q.length > 0 ? AppSearch.fuzzyQuery(q)
            : AppSearch.list.filter(e => !e.noDisplay).slice().sort((a, b) => a.name.localeCompare(b.name))
        return list.slice(0, limit).map(e => ({
            kind: "app", key: "app:" + e.id, title: e.name, subtitle: e.comment || e.genericName || "",
            iconKind: "app", icon: e.icon, data: e
        }))
    }
    function clipItems(limit) {
        const q = query.trim()
        const list = q.length > 0 ? Cliphist.fuzzyQuery(q) : Cliphist.entries
        return list.slice(0, limit).map(entry => {
            const tab = entry.indexOf("\t")
            const id = entry.slice(0, tab), text = entry.slice(tab + 1)
            if (Cliphist.entryIsImage(entry)) {
                const m = text.match(/binary data (.+?) (\w+) (\d+)x(\d+)/)
                return { kind: "clip", key: "clip:" + id, title: m ? `Image ${m[3]} × ${m[4]}` : "Image", subtitle: m ? `Image · ${m[1]}` : "Image",
                         iconKind: "thumb", icon: `${root.thumbDir}/${id}.png`, data: id }
            }
            const one = text.replace(/\s+/g, " ").trim()
            const colour = /^#([0-9a-f]{6}|[0-9a-f]{3})$/i.test(one)
            const link = /^https?:\/\//i.test(one)
            return { kind: "clip", key: "clip:" + id, title: one, subtitle: colour ? "Colour" : link ? "Link" : "Text",
                     iconKind: colour ? "swatch" : "drawn", icon: colour ? one : (link ? "link" : "text"), data: id }
        })
    }
    function actionItems(limit) {
        const q = query.trim().toLowerCase()
        return actionList.filter(a => q.length === 0 || a.title.toLowerCase().includes(q)).slice(0, limit).map(a => ({
            kind: "action", key: "action:" + a.key, title: a.title,
            subtitle: root.armed === a.key ? "Press Enter again to confirm" : (a.state ? a.state() : ""),
            iconKind: "glyph", glyph: a.glyph, data: a
        }))
    }
    property var fileHits: []
    function fileItems(limit) {
        return fileHits.slice(0, limit).map(p => {
            const dir = p.endsWith("/")
            const clean = dir ? p.slice(0, -1) : p
            const name = clean.slice(clean.lastIndexOf("/") + 1)
            const where = clean.slice(0, clean.lastIndexOf("/")).replace(root.home, "~")
            return { kind: "file", key: "file:" + p, title: name, subtitle: where, iconKind: "theme", icon: dir ? "folder" : "text-x-generic", data: clean }
        })
    }
    readonly property var results: {
        thumbRev
        if (!open) return []
        if (mode === "apps") return appItems(40)
        if (mode === "clipboard") return clipItems(60)
        if (mode === "files") return fileItems(40)
        if (mode === "actions") return actionItems(40)
        if (query.trim().length === 0) return []
        return appItems(5).concat(actionItems(3), clipItems(2)) // files only in their own mode: too noisy here
    }

    function activate(item) {
        if (!item) return
        if (item.kind === "app") { item.data.execute(); hide() }
        else if (item.kind === "clip") {
            Quickshell.execDetached(["sh", "-c", "printf '%s\\t' \"$1\" | cliphist decode | wl-copy", "sh", item.data])
            hide()
        }
        else if (item.kind === "file") { Quickshell.execDetached(["xdg-open", item.data]); hide() }
        else if (item.kind === "action") {
            const a = item.data
            if (a.confirm && root.armed !== a.key) { root.armed = a.key; return }
            hide()
            a.run()
        }
    }
    function remove(item) { // clipboard entries only
        if (!item || item.kind !== "clip") return
        removeProc.exec(["sh", "-c", "printf '%s\\t' \"$1\" | cliphist delete", "sh", item.data])
    }
    function clearClipboard() { Cliphist.wipe() }
    Process { id: removeProc; onExited: Cliphist.refresh() }

    // ── Files (fd) ──────────────────────────────────────────────────────────
    Timer { id: fileDebounce; interval: 180; onTriggered: root.searchFiles() }
    function searchFiles() {
        const q = query.trim()
        if (q.length < 2) { fileHits = []; return }
        fdProc.running = false
        fdProc.command = ["fd", "--max-results", "40", "--ignore-case", "--", q, root.home]
        fdProc.running = true
    }
    Process {
        id: fdProc
        stdout: StdioCollector { onStreamFinished: root.fileHits = text.split("\n").filter(l => l.length > 0) }
    }

    // ── Clipboard image thumbnails ──────────────────────────────────────────
    function makeThumbs() {
        const ids = Cliphist.entries.filter(e => Cliphist.entryIsImage(e)).slice(0, 30).map(e => e.slice(0, e.indexOf("\t")))
        if (ids.length === 0) return
        thumbProc.exec(["sh", "-c",
            'd="$1"; shift; mkdir -p "$d"; for id in "$@"; do [ -s "$d/$id.png" ] || printf "%s\\t" "$id" | cliphist decode > "$d/$id.png" 2>/dev/null; done',
            "sh", root.thumbDir].concat(ids))
    }
    Process { id: thumbProc; onExited: root.thumbRev++ }
    Connections {
        target: Cliphist
        function onEntriesChanged() { if (root.open && root.mode === "clipboard") root.makeThumbs() }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle("") }
        function clipboard(): void { root.toggle("clipboard") }
        function mode(name: string): void { root.show(name) }
        function search(text: string): void { if (!root.open) root.show(""); root.query = text }
        function close(): void { root.hide() }
    }
}
