pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// Right-click menu for one app in the bar's app island: its windows, then the app's own
// background (tray) menu, then New Window / Close all. Filled from GlassPanels.appMenu.
GlassPanel {
    id: root
    name: "app"
    panelWidth: 240
    anchorRight: GlassPanels.appMenuX + panelWidth / 2

    body: Column {
        id: col
        spacing: 2

        readonly property var app: GlassPanels.appMenu ?? ({ name: "", appId: "", ids: [], titles: [], focused: -1, tray: null, icon: "" })
        readonly property var tray: app.tray
        readonly property bool hasWindows: app.ids.length > 0
        property var path: []   // sub-menus opened, innermost last
        readonly property var handle: path.length > 0 ? path[path.length - 1] : (tray && tray.hasMenu ? tray.menu : null)
        readonly property var entries: handle ? opener.children.values : []
        onAppChanged: path = []
        // The background app quit while its menu was showing: nothing left to offer.
        readonly property bool gone: !hasWindows && !tray
        onGoneChanged: if (gone && root.wanted) GlassPanels.close()

        // dbusmenu marks keyboard mnemonics with an underscore
        function clean(s) { return String(s || "").replace(/_([^_])/g, "$1") }

        QsMenuOpener { id: opener; menu: col.handle }

        Item {
            width: parent.width
            height: 34
            Image {
                id: headIcon
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                sourceSize: Qt.size(64, 64)
                mipmap: true
                source: col.app.icon
            }
            GlassText {
                anchors.left: headIcon.right
                anchors.leftMargin: 9
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: col.app.name
            }
        }
        Rectangle { x: 8; width: parent.width - 16; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }

        // ── its windows ──
        GlassCaption { visible: col.hasWindows && col.path.length === 0; text: "Windows" }
        Repeater {
            model: col.path.length === 0 ? col.app.ids : []
            GlassMenuRow {
                required property var modelData
                required property int index
                text: col.app.titles[index] || col.app.name
                selected: index === col.app.focused
                onChosen: { Niri.focusWindow(modelData); GlassPanels.close() }
            }
        }
        Rectangle {
            visible: col.hasWindows && col.path.length === 0 && col.entries.length > 0
            x: 8; width: parent.width - 16; height: 1; color: Qt.rgba(1, 1, 1, 0.12)
        }

        // ── the app's own menu ──
        GlassMenuRow {
            visible: col.path.length > 0
            text: "Back"
            onChosen: col.path = col.path.slice(0, -1)
        }
        Repeater {
            model: col.entries
            Item {
                id: entry
                required property var modelData
                width: col.width
                height: modelData.isSeparator ? 9 : 30
                Rectangle {
                    visible: entry.modelData.isSeparator
                    x: 8; y: 4; width: parent.width - 16; height: 1; color: Qt.rgba(1, 1, 1, 0.12)
                }
                GlassMenuRow {
                    visible: !entry.modelData.isSeparator
                    enabled: entry.modelData.enabled
                    text: col.clean(entry.modelData.text)
                    danger: /^(quit|exit)\b/i.test(text)
                    ticked: entry.modelData.buttonType !== QsMenuButtonType.None && entry.modelData.checkState !== Qt.Unchecked
                    more: entry.modelData.hasChildren
                    onChosen: {
                        if (entry.modelData.hasChildren) { col.path = col.path.concat([entry.modelData]); return }
                        entry.modelData.triggered()
                        GlassPanels.close()
                    }
                }
            }
        }
        GlassMenuRow { // a background app that offers no menu of its own
            visible: !col.hasWindows && col.tray && !col.tray.hasMenu
            text: "Open " + col.app.name
            onChosen: { col.tray.activate(); GlassPanels.close() }
        }

        // ── for apps with windows ──
        Rectangle {
            visible: col.hasWindows && col.path.length === 0
            x: 8; width: parent.width - 16; height: 1; color: Qt.rgba(1, 1, 1, 0.12)
        }
        GlassMenuRow {
            readonly property var desktop: DesktopEntries.byId(col.app.appId) ?? DesktopEntries.heuristicLookup(col.app.appId)
            visible: col.hasWindows && col.path.length === 0 && desktop !== null
            text: "New Window"
            onChosen: { desktop.execute(); GlassPanels.close() }
        }
        GlassMenuRow {
            visible: col.hasWindows && col.path.length === 0
            text: col.app.ids.length > 1 ? "Close all" : "Close"
            danger: true
            onChosen: {
                for (let i = 0; i < col.app.ids.length; i++) Niri.closeWindow(col.app.ids[i])
                GlassPanels.close()
            }
        }
    }
}
