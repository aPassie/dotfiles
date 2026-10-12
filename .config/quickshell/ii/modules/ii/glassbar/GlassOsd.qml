pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// Volume / brightness pop-up: one glass capsule under the middle of the bar.
// Replaces modules/ii/onScreenDisplay.
Scope {
    id: root

    property string kind: "volume"       // "volume" or "brightness"
    property string protectionMessage: ""
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Niri.focusedMonitor?.name) ?? null
    readonly property real barH: Appearance.sizes.baseBarHeight

    function show(what) {
        kind = what
        GlobalStates.osdVolumeOpen = true
        hide.restart()
    }
    Timer {
        id: hide
        interval: Config.options?.osd?.timeout ?? 1000
        onTriggered: {
            GlobalStates.osdVolumeOpen = false
            root.protectionMessage = ""
        }
    }
    Connections {
        target: Brightness
        function onBrightnessChanged() { root.protectionMessage = ""; root.show("brightness") }
    }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() { if (Audio.ready) root.show("volume") }
        function onMutedChanged() { if (Audio.ready) root.show("volume") }
    }
    Connections {
        target: Audio
        function onSinkProtectionTriggered(reason) { root.protectionMessage = reason; root.show("volume") }
    }

    Timer { id: unload; interval: 180 }
    Connections {
        target: GlobalStates
        function onOsdVolumeOpenChanged() { if (!GlobalStates.osdVolumeOpen) unload.restart() }
    }

    LazyLoader {
        active: GlobalStates.osdVolumeOpen || unload.running

        component: PanelWindow {
            id: win
            screen: root.focusedScreen

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:glass"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors.top: true
            implicitWidth: 300
            implicitHeight: root.barH + 130
            mask: Region {} // never takes the pointer
            BackgroundEffect.blurRegion: Region {
                Region { item: pill; radius: 22 }
                Region { item: note.visible ? note : null; radius: 14 }
            }

            readonly property bool muted: Audio.sink?.audio?.muted ?? false
            readonly property real level: root.kind === "volume"
                ? (Audio.sink?.audio?.volume ?? 0)
                : (Brightness.getMonitorForScreen(win.screen)?.brightness ?? 0)
            readonly property int glyph: root.kind === "volume"
                ? (muted ? 0x1002A3 : level < 0.02 ? 0x1002A1 : 0x1002A9)
                : (level < 0.4 ? 0x1001AC : 0x1001AE)

            GlassPiece {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.barH + 8
                width: 264
                height: 44
                radius: 22
                tintStrength: 0.66
                opacity: GlobalStates.osdVolumeOpen ? 1 : 0
                scale: GlobalStates.osdVolumeOpen ? 1 : 0.92
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Text {
                    id: icon
                    x: 15
                    width: 22
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: String.fromCodePoint(win.glyph)
                    color: (root.kind === "volume" && win.muted) ? "#ff7a70" : "white"
                    font.family: GlassPanels.symbols
                    font.pixelSize: 15
                }
                Item { // level
                    id: track
                    anchors.left: icon.right
                    anchors.leftMargin: 12
                    anchors.right: value.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    Rectangle { anchors.fill: parent; radius: 3; color: Qt.rgba(1, 1, 1, 0.2) }
                    Rectangle {
                        width: parent.width * Math.min(Math.max(win.level, 0), 1)
                        height: parent.height
                        radius: 3
                        color: (root.kind === "volume" && win.muted) ? Qt.rgba(1, 1, 1, 0.45) : "white"
                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }
                    Rectangle { // past 100%
                        visible: win.level > 1
                        anchors.right: parent.right
                        width: parent.width * Math.min(win.level - 1, 1)
                        height: parent.height
                        radius: 3
                        color: "#ffb224"
                    }
                }
                GlassText {
                    id: value
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    font.weight: Font.DemiBold
                    text: (root.kind === "volume" && win.muted) ? Translation.tr("Mute") : Math.round(win.level * 100)
                }
            }

            GlassPiece { // e.g. "volume limited to protect your ears"
                id: note
                visible: root.protectionMessage.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: pill.y + pill.height + 8
                width: Math.min(noteText.implicitWidth + 28, 290)
                height: 28
                radius: 14
                tintStrength: 0.66
                GlassText { id: noteText; anchors.centerIn: parent; width: Math.min(implicitWidth, 262); font.pixelSize: 12; text: root.protectionMessage }
            }
        }
    }

    IpcHandler {
        target: "osdVolume"
        function trigger(): void { root.show("volume") }
        function hide(): void { GlobalStates.osdVolumeOpen = false }
        function toggle(): void { GlobalStates.osdVolumeOpen = !GlobalStates.osdVolumeOpen }
    }
}
