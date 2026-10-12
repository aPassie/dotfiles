pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Claude Code sessions and what each is doing, for the bar's Claude island.
// ~/.local/bin/claude-status-hook (run by Claude Code's hooks) keeps one file per session in
// ~/.local/state/claude-status and pokes `claudeStatus refresh`; this reads them back.
Singleton {
    id: root

    // [{ session, dir, cwd, state: "working" | "asking" | "done" | "idle", detail, since, win, pid }],
    // the one that most needs him first
    property var sessions: []
    readonly property var top: sessions.length > 0 ? sessions[0] : null
    property var seen: ({})          // session -> `since` of a "done" he has already looked at
    property var notice: null        // the session to announce
    property int noticeSerial: 0     // goes up with every announcement
    property bool loaded: false
    property var known: ({})         // session -> state at the last read

    // "done" turns back into plain "idle" once its terminal has been looked at
    function shown(s) {
        return s.state === "done" && root.seen[s.session] === s.since ? "idle" : s.state
    }
    function rank(s) {
        const k = shown(s)
        return k === "asking" ? 0 : k === "done" ? 1 : k === "working" ? 2 : 3
    }
    function focus(s) {
        if (s && s.win > 0) Niri.focusWindow(s.win)
    }
    function look() { // the focused window is a finished session's terminal: he has seen it
        const id = Niri.activeWindow?.id
        if (id === undefined || id === null) return
        let changed = false
        const next = Object.assign({}, root.seen)
        for (const s of root.sessions) {
            if (s.state === "done" && s.win === id && next[s.session] !== s.since) { next[s.session] = s.since; changed = true }
        }
        if (changed) { root.seen = next; root.sessions = root.sessions.slice().sort((a, b) => rank(a) - rank(b) || b.since - a.since) }
    }
    Connections {
        target: Niri
        function onActiveWindowChanged() { root.look() }
    }

    function take(text) {
        let list = []
        try { list = JSON.parse(text) } catch (e) { return }
        const now = {}
        let announce = null
        for (const s of list) {
            now[s.session] = s.state + ":" + s.since
            const fresh = root.known[s.session] !== now[s.session]
            if (root.loaded && fresh && (s.state === "asking" || s.state === "done")
                    && Niri.activeWindow?.id !== s.win && !Notifications.silent)
                if (!announce || s.since >= announce.since) announce = s
        }
        root.known = now
        root.sessions = list.sort((a, b) => rank(a) - rank(b) || b.since - a.since)
        root.loaded = true
        root.look()
        if (announce) { root.notice = announce; root.noticeSerial++ }
    }

    function refresh() {
        if (reader.running) again = true
        else reader.running = true
    }
    property bool again: false
    Process {
        id: reader
        command: [Quickshell.env("HOME") + "/.local/bin/claude-status-list"]
        stdout: StdioCollector { onStreamFinished: root.take(text) }
        onExited: if (root.again) { root.again = false; reader.running = true }
    }
    Timer { // clears sessions whose Claude process has gone away without a goodbye
        interval: 20000
        repeat: true
        running: root.sessions.length > 0
        onTriggered: root.refresh()
    }
    Component.onCompleted: refresh()

    IpcHandler {
        target: "claudeStatus"
        function refresh(): void { root.refresh() }
    }
}
