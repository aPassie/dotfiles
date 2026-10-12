pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common

// Spotlight-style launcher: a glass pill in the upper middle of the screen, four mode
// buttons that spring out beside it (Tab), and results in a second pane below.
Scope {
    id: root

    Timer { id: unload; interval: 200 }
    Connections {
        target: GlassLauncher
        function onOpenChanged() { if (!GlassLauncher.open) unload.restart() }
    }

    LazyLoader {
        active: GlassLauncher.open || unload.running

        component: PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === Niri.focusedMonitor?.name) ?? null

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:glass"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlassLauncher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            readonly property real fullW: 600
            readonly property real beadD: 58
            readonly property real beadGap: 10
            readonly property real shortW: fullW - 4 * (beadD + beadGap)
            readonly property var results: GlassLauncher.results
            property int selected: 0
            onResultsChanged: selected = Math.min(selected, Math.max(results.length - 1, 0))
            Connections {
                target: GlassLauncher
                function onQueryChanged() { win.selected = 0; if (input.text !== GlassLauncher.query) input.text = GlassLauncher.query }
                function onModeChanged() { win.selected = 0 }
                function onOpenChanged() { if (GlassLauncher.open) { input.text = ""; input.forceActiveFocus() } }
            }

            BackgroundEffect.blurRegion: Region {
                Region { item: pill; radius: 29 }
                Region { item: GlassLauncher.rail ? bead0 : null; radius: 29 }
                Region { item: GlassLauncher.rail ? bead1 : null; radius: 29 }
                Region { item: GlassLauncher.rail ? bead2 : null; radius: 29 }
                Region { item: GlassLauncher.rail ? bead3 : null; radius: 29 }
                Region { item: pane.visible ? pane : null; radius: 26 }
            }

            MouseArea { // click anywhere else to close
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: GlassLauncher.hide()
            }

            Item {
                id: stack
                x: (win.width - win.fullW) / 2
                y: Math.round(win.height * 0.15)
                width: win.fullW
                height: pill.height + 8 + pane.height
                opacity: GlassLauncher.open ? 1 : 0
                scale: GlassLauncher.open ? 1 : 0.96
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.42; mass: 0.5 } }

                MouseArea { anchors.fill: parent } // clicks inside don't close

                // ── Search pill ────────────────────────────────────────────
                GlassPiece {
                    id: pill
                    width: GlassLauncher.rail ? win.shortW : win.fullW
                    height: 58
                    radius: 29
                    tintStrength: 0.66
                    Behavior on width { SpringAnimation { spring: 5.2; damping: 0.36; mass: 0.5 } }

                    Image {
                        id: lead
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        sourceSize: Qt.size(48, 48)
                        source: Qt.resolvedUrl(`../../../assets/icons/glassbar/${GlassLauncher.mode.length > 0 ? GlassLauncher.mode : "search"}.svg`)
                    }
                    TextInput {
                        id: input
                        anchors.left: lead.right
                        anchors.leftMargin: 12
                        anchors.right: hint.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        focus: true
                        color: "white"
                        selectionColor: Qt.rgba(1, 1, 1, 0.3)
                        font.family: "Outfit"
                        font.pixelSize: 20
                        font.letterSpacing: 0.3
                        onTextChanged: GlassLauncher.query = text
                        Component.onCompleted: forceActiveFocus()

                        Keys.onPressed: (event) => {
                            const ctrl = event.modifiers & Qt.ControlModifier, alt = event.modifiers & Qt.AltModifier
                            if (event.key === Qt.Key_Escape) GlassLauncher.hide()
                            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                if (GlassLauncher.rail) { GlassLauncher.rail = false; GlassLauncher.mode = "" }
                                else GlassLauncher.rail = true
                            }
                            else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) GlassLauncher.setMode(GlassLauncher.modes[event.key - Qt.Key_1])
                            else if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) GlassLauncher.activate(win.results[event.key - Qt.Key_1])
                            else if (event.key === Qt.Key_Down) win.selected = Math.min(win.selected + 1, win.results.length - 1)
                            else if (event.key === Qt.Key_Up) win.selected = Math.max(win.selected - 1, 0)
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) GlassLauncher.activate(win.results[win.selected])
                            else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) GlassLauncher.remove(win.results[win.selected])
                            else return
                            event.accepted = true
                        }
                    }
                    GlassText {
                        visible: input.text.length === 0
                        anchors.left: input.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.family: "Outfit"
                        font.pixelSize: 20
                        font.weight: Font.Normal
                        text: GlassLauncher.mode.length > 0 ? Translation.tr(GlassLauncher.modeNames[GlassLauncher.mode]) : Translation.tr("Search")
                    }
                    Row {
                        id: hint
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Rectangle {
                            width: tabText.implicitWidth + 14
                            height: 20
                            radius: 7
                            color: Qt.rgba(1, 1, 1, 0.14)
                            GlassText { id: tabText; anchors.centerIn: parent; font.family: "Outfit"; font.pixelSize: 11; text: "Tab" }
                        }
                        GlassText {
                            visible: !GlassLauncher.rail
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.family: "Outfit"
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            text: Translation.tr("modes")
                        }
                    }
                }

                // ── Mode buttons ───────────────────────────────────────────
                component ModeBead: GlassPiece {
                    id: bead
                    property int index: 0
                    readonly property string modeName: GlassLauncher.modes[index]
                    readonly property bool on: GlassLauncher.mode === modeName
                    x: win.shortW + win.beadGap + index * (win.beadD + win.beadGap)
                    width: win.beadD
                    height: win.beadD
                    radius: win.beadD / 2
                    tintStrength: on ? 1 : (area.containsMouse ? 0.5 : 0.66)
                    fill: on ? "white" : GlassBackdrop.tint
                    visible: scale > 0.02
                    scale: GlassLauncher.rail ? 1 : 0
                    opacity: GlassLauncher.rail ? 1 : 0
                    // later buttons are heavier, so they trail the first one out
                    Behavior on scale { SpringAnimation { spring: 5.2; damping: 0.34; mass: 0.45 + bead.index * 0.22 } }
                    Behavior on opacity { NumberAnimation { duration: 120 + bead.index * 40 } }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { GlassLauncher.setMode(bead.modeName); input.forceActiveFocus() }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        sourceSize: Qt.size(48, 48)
                        source: Qt.resolvedUrl(`../../../assets/icons/glassbar/${bead.modeName}${bead.on ? "-blue" : ""}.svg`)
                    }
                }
                ModeBead { id: bead0; index: 0 }
                ModeBead { id: bead1; index: 1 }
                ModeBead { id: bead2; index: 2 }
                ModeBead { id: bead3; index: 3 }

                // ── Results ────────────────────────────────────────────────
                GlassPiece {
                    id: pane
                    readonly property bool clip: GlassLauncher.mode === "clipboard"
                    readonly property string emptyText: GlassLauncher.mode === "files"
                        ? (GlassLauncher.query.trim().length < 2 ? Translation.tr("Type at least two letters to search your home folder") : Translation.tr("No files found"))
                        : GlassLauncher.mode === "clipboard" ? Translation.tr("Clipboard history is empty")
                        : GlassLauncher.mode.length > 0 || GlassLauncher.query.trim().length > 0 ? Translation.tr("No results") : ""
                    y: pill.height + 8
                    width: win.fullW
                    visible: win.results.length > 0 || emptyText.length > 0
                    height: !visible ? 0 : 16 + (win.results.length > 0 ? Math.min(win.results.length, 7) * 52 - 2 : 40) + (clip && win.results.length > 0 ? 34 : 0)
                    radius: 26
                    tintStrength: 0.66
                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    GlassText {
                        visible: win.results.length === 0
                        x: 20
                        y: 8
                        height: 40
                        verticalAlignment: Text.AlignVCenter
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font.family: "Outfit"
                        font.weight: Font.Normal
                        text: pane.emptyText
                    }

                    ListView {
                        id: view
                        x: 8
                        y: 8
                        width: parent.width - 16
                        height: Math.min(win.results.length, 7) * 52 - 2
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: ScriptModel { values: win.results; objectProp: "key" }
                        currentIndex: win.selected
                        highlightMoveDuration: 0

                        delegate: MouseArea {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool sel: index === win.selected
                            width: view.width
                            height: 50
                            hoverEnabled: true
                            onPositionChanged: win.selected = index
                            onClicked: GlassLauncher.activate(modelData)

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: Qt.rgba(1, 1, 1, row.sel ? 0.14 : 0)
                            }
                            Item { // icon
                                id: pic
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 36
                                IconImage {
                                    visible: row.modelData.iconKind === "app" || row.modelData.iconKind === "theme"
                                    anchors.fill: parent
                                    source: visible ? (row.modelData.iconKind === "app" ? row.appIcon : Quickshell.iconPath(row.modelData.icon, "text-x-generic")) : ""
                                }
                                Rectangle {
                                    visible: !(row.modelData.iconKind === "app" || row.modelData.iconKind === "theme")
                                    anchors.fill: parent
                                    radius: 9
                                    color: row.modelData.iconKind === "swatch" ? row.modelData.icon : Qt.rgba(1, 1, 1, 0.12)
                                    clip: true
                                    Text {
                                        visible: row.modelData.iconKind === "glyph"
                                        anchors.centerIn: parent
                                        text: row.modelData.iconKind === "glyph" ? String.fromCodePoint(row.modelData.glyph) : ""
                                        color: "white"
                                        font.family: GlassPanels.symbols
                                        font.pixelSize: 15
                                    }
                                    Image {
                                        visible: row.modelData.iconKind === "drawn"
                                        anchors.centerIn: parent
                                        width: 17
                                        height: 17
                                        sourceSize: Qt.size(40, 40)
                                        source: row.modelData.iconKind === "drawn" ? Qt.resolvedUrl(`../../../assets/icons/glassbar/${row.modelData.icon}.svg`) : ""
                                    }
                                    Image {
                                        visible: row.modelData.iconKind === "thumb"
                                        anchors.centerIn: parent
                                        width: 17
                                        height: 17
                                        sourceSize: Qt.size(40, 40)
                                        source: Qt.resolvedUrl("../../../assets/icons/glassbar/image.svg")
                                    }
                                }
                                ClippingRectangle { // picture from the clipboard
                                    visible: row.modelData.iconKind === "thumb" && thumb.status === Image.Ready
                                    anchors.fill: parent
                                    radius: 9
                                    color: "transparent"
                                    Image {
                                        id: thumb
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                        sourceSize: Qt.size(96, 96)
                                        source: row.modelData.iconKind === "thumb" ? `file://${row.modelData.icon}?${GlassLauncher.thumbRev}` : ""
                                    }
                                }
                            }
                            // apps use the macOS-style set, except file managers
                            readonly property string appIcon: {
                                if (modelData.iconKind !== "app") return ""
                                const name = AppSearch.guessIcon(modelData.icon || modelData.title)
                                if (name.startsWith("/")) return "file://" + name
                                const fm = /dolphin|nautilus|thunar|nemo|pcmanfm|file-?manager/i.test(name + " " + modelData.title)
                                const mac = `/usr/share/icons/WhiteSur-dark/apps/scalable/${name}.svg`
                                return (!fm && GlassLauncher.macIcons[name]) ? "file://" + mac : Quickshell.iconPath(name, "application-x-executable")
                            }
                            Column {
                                anchors.left: pic.right
                                anchors.leftMargin: 12
                                anchors.right: tail.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                GlassText { width: parent.width; font.family: "Outfit"; font.pixelSize: 14; text: row.modelData.title }
                                GlassText {
                                    visible: text.length > 0
                                    width: parent.width
                                    color: (row.modelData.kind === "action" && GlassLauncher.armed === row.modelData.data.key) ? "#ff7a70" : Qt.rgba(1, 1, 1, 0.66)
                                    font.family: "Outfit"
                                    font.pixelSize: 12
                                    font.weight: Font.Normal
                                    text: row.modelData.subtitle
                                }
                            }
                            Rectangle {
                                id: tail
                                visible: row.sel || row.index < 9
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(keyText.implicitWidth + 12, 22)
                                height: 20
                                radius: 7
                                color: Qt.rgba(1, 1, 1, row.sel ? 0.2 : 0.1)
                                GlassText {
                                    id: keyText
                                    anchors.centerIn: parent
                                    font.family: "Outfit"
                                    font.pixelSize: 11
                                    color: Qt.rgba(1, 1, 1, row.sel ? 1 : 0.7)
                                    text: row.sel ? "Enter" : "Alt " + (row.index + 1)
                                }
                            }
                        }
                    }

                    Item { // clipboard footer
                        visible: pane.clip && win.results.length > 0
                        x: 20
                        y: view.y + view.height + 6
                        width: parent.width - 40
                        height: 26
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }
                        GlassText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 3
                            color: Qt.rgba(1, 1, 1, 0.6)
                            font.family: "Outfit"
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            text: Translation.tr("Enter copies it back · Shift+Delete removes it")
                        }
                        MouseArea {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 3
                            width: clearText.implicitWidth + 18
                            height: 22
                            hoverEnabled: true
                            onClicked: GlassLauncher.clearClipboard()
                            Rectangle { anchors.fill: parent; radius: 11; color: Qt.rgba(1, 1, 1, parent.containsMouse ? 0.26 : 0.12) }
                            GlassText { id: clearText; anchors.centerIn: parent; font.family: "Outfit"; font.pixelSize: 11; text: Translation.tr("Clear history") }
                        }
                    }
                }
            }
        }
    }
}
