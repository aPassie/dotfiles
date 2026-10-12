pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Minimal niri IPC shim, scoped to what the curated bar / OSD / sidebar modules
// actually consume from the original Quickshell.Hyprland module:
//   - workspaces list with id/idx/output/is_active/is_focused
//   - focusedMonitor.name (which output is focused)
//   - activeWindow.{id,title,appId}
//   - dispatch(action) for the small set of commands the bar issues
Singleton {
    id: root

    property var workspaces: []
    property var focusedMonitor: ({ name: "" })
    property var activeWindow: null
    // Full window list (id, app_id, title, workspace_id, is_focused, is_urgent, layout),
    // kept current from the event stream. Used by the glass bar's app strip.
    property var windows: []

    readonly property int focusedWorkspaceId: {
        for (let i = 0; i < workspaces.length; i++)
            if (workspaces[i].is_focused) return workspaces[i].id
        return -1
    }

    readonly property int focusedWorkspaceIdx: {
        for (let i = 0; i < workspaces.length; i++)
            if (workspaces[i].is_focused) return workspaces[i].idx
        return 1
    }

    function workspacesForOutput(output) {
        return workspaces.filter(w => w.output === output)
                         .sort((a, b) => a.idx - b.idx)
    }

    function dispatch(action) {
        const a = String(action).trim()

        // workspace N  ->  focus-workspace N
        let m = a.match(/^workspace\s+(\d+)$/)
        if (m) { _action(["focus-workspace", m[1]]); return }

        // workspace r+1 / r-1  ->  focus-workspace-down / -up
        if (a === "workspace r+1") { _action(["focus-workspace-down"]); return }
        if (a === "workspace r-1") { _action(["focus-workspace-up"]); return }

        // togglespecialworkspace -> niri has no special workspace; map to overview
        if (a.startsWith("togglespecialworkspace")) { _action(["toggle-overview"]); return }

        // exec ...  -> just spawn the command (bar uses this for wallpaper switcher)
        if (a.startsWith("exec ")) {
            Quickshell.execDetached(["bash", "-lc", a.slice(5)])
            return
        }

        // Unknown — log and ignore
        console.log("[Niri] unhandled dispatch:", a)
    }

    function _action(args) {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args))
    }

    // Long-lived event stream. Niri prints one JSON object per line.
    Process {
        id: events
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: (line) => root._onEvent(line)
        }
    }

    function _onEvent(line) {
        let ev
        try { ev = JSON.parse(line) } catch (e) { return }
        _trackWindows(ev)

        if (ev.WorkspacesChanged) {
            root.workspaces = ev.WorkspacesChanged.workspaces || []
            _refreshFocusedOutput()
            return
        }

        if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id
            const focused = !!ev.WorkspaceActivated.focused
            // The activated workspace's output becomes the active output for that
            // output. Other workspaces on the same output become inactive.
            let target = root.workspaces.find(w => w.id === id)
            const out = target ? target.output : null
            root.workspaces = root.workspaces.map(w => {
                let nw = Object.assign({}, w)
                if (out && w.output === out) nw.is_active = (w.id === id)
                if (focused) nw.is_focused = (w.id === id)
                return nw
            })
            if (focused) _refreshFocusedOutput()
            return
        }

        if (ev.WindowsChanged) {
            const list = ev.WindowsChanged.windows || []
            const f = list.find(w => w.is_focused)
            root.activeWindow = f ? { id: f.id, title: f.title || "", appId: f.app_id || "" } : null
            return
        }

        if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window
            if (w && w.is_focused)
                root.activeWindow = { id: w.id, title: w.title || "", appId: w.app_id || "" }
            else if (root.activeWindow && w && w.id === root.activeWindow.id)
                root.activeWindow = { id: w.id, title: w.title || "", appId: w.app_id || "" }
            return
        }

        if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id
            if (id === null || id === undefined) { root.activeWindow = null; return }
            // Need to query for full info; event only carries id.
            fetchWin.running = true
            return
        }

        if (ev.WindowClosed) {
            if (root.activeWindow && root.activeWindow.id === ev.WindowClosed.id)
                root.activeWindow = null
            return
        }
    }

    function _trackWindows(ev) {
        if (ev.WindowsChanged) {
            root.windows = ev.WindowsChanged.windows || []
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window
            if (!w) return
            let found = false
            const list = root.windows.map(o => {
                if (o.id === w.id) { found = true; return w }
                return (w.is_focused && o.is_focused) ? Object.assign({}, o, { is_focused: false }) : o
            })
            if (!found) list.push(w)
            root.windows = list
        } else if (ev.WindowClosed) {
            root.windows = root.windows.filter(o => o.id !== ev.WindowClosed.id)
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id
            root.windows = root.windows.map(o => (o.is_focused !== (o.id === id))
                ? Object.assign({}, o, { is_focused: o.id === id }) : o)
        } else if (ev.WindowLayoutsChanged) {
            const m = {}
            const ch = ev.WindowLayoutsChanged.changes || []
            for (let i = 0; i < ch.length; i++) m[ch[i][0]] = ch[i][1]
            root.windows = root.windows.map(o => (o.id in m) ? Object.assign({}, o, { layout: m[o.id] }) : o)
        } else if (ev.WindowUrgencyChanged) {
            const u = ev.WindowUrgencyChanged
            root.windows = root.windows.map(o => o.id === u.id ? Object.assign({}, o, { is_urgent: u.urgent }) : o)
        }
    }

    function focusWindow(id) {
        _action(["focus-window", "--id", String(id)])
    }

    function closeWindow(id) {
        _action(["close-window", "--id", String(id)])
    }

    function _refreshFocusedOutput() {
        for (let i = 0; i < workspaces.length; i++) {
            if (workspaces[i].is_focused) {
                root.focusedMonitor = { name: workspaces[i].output || "" }
                return
            }
        }
    }

    // Initial state — event-stream emits a synthetic WorkspacesChanged on
    // connect, but we also fetch the focused window so the bar title is filled
    // before the first WindowFocusChanged.
    Process {
        id: fetchWin
        command: ["niri", "msg", "--json", "focused-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (!t || t === "null") { root.activeWindow = null; return }
                try {
                    const w = JSON.parse(t)
                    root.activeWindow = { id: w.id, title: w.title || "", appId: w.app_id || "" }
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: fetchWin.running = true
}
