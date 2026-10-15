pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The phone linked by PhoneLink (~/phonelink): its state comes from the file phonelinkd keeps
// in ~/.local/state/phonelink/state.json (the daemon also pokes `phoneLink refresh`), and
// actions go back through the `phonelink` command.
Singleton {
    id: root

    property var st: ({})
    readonly property bool connected: st.connected === true
    readonly property string name: st.alias || st.name || "Phone"
    readonly property int battery: st.battery ?? -1
    readonly property bool charging: st.charging === true
    readonly property string call: connected ? (st.call || "idle") : "idle"
    readonly property string caller: st.caller || ""
    readonly property string callDetail: st.callDetail || ""
    readonly property int callSince: st.callSince || 0
    readonly property bool fastOpen: st.fast === "open"
    readonly property var transfers: st.transfers || []
    readonly property bool wifiReady: st.wifiReady === true         // can join the phone's Wi-Fi link
    readonly property bool looking: st.wifiJoin === "looking"        // a Connect tap is searching
    function connectWifi() { Quickshell.execDetached([bin, "wifi"]) }
    readonly property string link: st.via === "wi-fi" ? "Wi-Fi Direct" : fastOpen ? "Bluetooth + Wi-Fi Direct" : "Bluetooth"

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/phonelink"

    function refresh() { file.reload() }
    function answer() { Quickshell.execDetached([bin, "answer"]) }
    function decline() { Quickshell.execDetached([bin, "decline"]) }
    function sendClipboard() { Quickshell.execDetached([bin, "clip"]) }
    function sendPaths(paths) { if (paths.length > 0) Quickshell.execDetached([bin, "send"].concat(paths)) }
    function pickFiles() {
        Quickshell.execDetached(["bash", "-c",
            "kdialog --title 'Send to phone' --multiple --separate-output --getopenfilename \"$HOME\" | " +
            "{ mapfile -t f; [ ${#f[@]} -gt 0 ] && exec \"$1\" send \"${f[@]}\"; }", "bash", bin])
    }
    function openTransfer(t) {
        if (!t.path) return
        if (t.dir === "in") Quickshell.execDetached(["xdg-open", t.path])
        else Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/dolphin-macos", "--select", t.path])
    }

    function size(b) {
        if (b >= 1e9) return (b / 1e9).toFixed(1) + " GB"
        if (b >= 1e6) return (b / 1e6).toFixed(1) + " MB"
        if (b >= 1e3) return Math.round(b / 1e3) + " KB"
        return b + " B"
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/phonelink/state.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.st = JSON.parse(text()) } catch (e) {} }
    }

    IpcHandler {
        target: "phoneLink"
        function refresh(): void { root.refresh() }
    }
}
