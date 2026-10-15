pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Which of the bar's drop-down glass panels is open (only one at a time), plus the
// few things they all share.
Singleton {
    id: root

    property string open: ""            // "", "wifi", "bluetooth", "notifications", "control", "app", "claude" or "phone"
    property real statusRight: 0        // right edge of the status island, in screen px
    property bool anchorHovered: false  // pointer is over the status island
    property string controlDetail: ""   // Control Centre: which control's settings are showing
    property string controlConfirm: ""  // Control Centre: "restart" or "shutdown" while asking
    property string peek: ""            // name of a hover pop-up to hold open (battery, weather, monitor)
    property bool pinned: false         // something in the open panel needs it to stay (typing a password)
    readonly property string symbols: sfFont.name
    property real claudeRight: 0        // right edge of the Claude island, in screen px
    property var appMenu: null          // the app whose right-click menu is showing (see AppStrip.openMenu)
    property real appMenuX: 0           // centre of that app's icon, in screen px

    function showAppMenu(app, x) {
        if (root.open === "app" && root.appMenu && root.appMenu.appId === app.appId) { root.open = ""; return }
        root.appMenu = app
        root.appMenuX = x
        root.open = "app"
    }

    function toggle(name) {
        root.open = (root.open === name) ? "" : name
    }
    function close() {
        root.open = ""
    }

    // The media panel and these panels never overlap.
    onOpenChanged: {
        if (open.length > 0) GlobalStates.mediaControlsOpen = false
        else pinned = false
        if (open !== "control") { controlDetail = ""; controlConfirm = "" }
    }
    Connections {
        target: GlobalStates
        function onMediaControlsOpenChanged() {
            if (GlobalStates.mediaControlsOpen) root.open = ""
        }
    }

    FontLoader {
        id: sfFont
        source: Qt.resolvedUrl("../assets/fonts/SF-Pro-Text-Medium.otf")
    }

    // SF Symbols used by the panels, by code point (each verified against the font)
    readonly property var sf: ({
        wifi: 0x100647, wifiSlash: 0x100648, bell: 0x1002DA, bellSlash: 0x1002DE,
        lock: 0x1003A1, check: 0x100185, xmark: 0x100184, chevron: 0x10018A,
        headphones: 0x100448, keyboard: 0x1001F3, mouse: 0x100EA3, phone: 0x1007DC,
        laptop: 0x1007DB, speaker: 0x10074F, shield: 0x100666, trash: 0x100211,
        gear: 0x1008CB, reload: 0x100148, power: 0x1001A8, arrow: 0x10018A
    })

    IpcHandler {
        target: "glassPanels"
        function toggle(name: string): void {
            root.toggle(name)
        }
        function close(): void {
            root.close()
        }
        function detail(name: string): void { // open the Control Centre on one control's settings
            root.open = "control"
            root.controlConfirm = ""
            root.controlDetail = name
        }
        function ask(what: string): void { // show the restart / shutdown question (it does not answer it)
            root.open = "control"
            root.controlDetail = ""
            root.controlConfirm = what
        }
        function peek(name: string): void { // hold a hover pop-up open; "" lets it go
            root.peek = name
        }
    }
}
