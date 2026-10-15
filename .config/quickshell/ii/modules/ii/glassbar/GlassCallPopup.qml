pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// Phone calls from PhoneLink: a pop-up with Answer / Decline while the phone rings, then a
// one-line bar with a timer and End call. On the overlay layer, so it also shows over a
// full-screen window. Audio stays on the phone.
Scope {
    id: root
    readonly property bool ringing: PhoneLink.call === "ringing"
    readonly property bool talking: PhoneLink.call === "offhook"
    readonly property bool present: (ringing || talking) && !GlobalStates.screenLocked
    readonly property real barH: Appearance.sizes.baseBarHeight

    property double now: Date.now() / 1000
    Timer { interval: 1000; repeat: true; running: root.talking; triggeredOnStart: true; onTriggered: root.now = Date.now() / 1000 }
    function clock(secs) {
        const s = Math.max(0, Math.round(secs))
        return Math.floor(s / 60).toString().padStart(2, "0") + ":" + (s % 60).toString().padStart(2, "0")
    }

    PanelWindow {
        id: win
        visible: root.present
        screen: Quickshell.screens.find(s => s.name === Niri.focusedMonitor?.name) ?? null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:glass"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; right: true }
        implicitWidth: card.width + 16 + 34
        implicitHeight: root.barH + card.height + 40
        mask: Region { item: card }
        BackgroundEffect.blurRegion: Region { item: card; radius: 20 }

        readonly property bool covered: {
            const w = Niri.windows.find(w => w.is_focused)
            const size = w?.layout?.window_size
            return !!size && !!win.screen && size[0] >= win.screen.width && size[1] >= win.screen.height
        }

        GlassPiece {
            id: card
            x: 34
            y: win.covered ? 8 : root.barH + 6
            width: 340
            height: root.ringing ? 120 : 60
            radius: 20
            tintStrength: 0.7
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
                id: disc
                x: 14; y: 11
                width: 38; height: 38; radius: 19
                color: Qt.rgba(1, 1, 1, 0.14)
                GlassText { anchors.centerIn: parent; font.pixelSize: 16; text: (PhoneLink.caller || "?").charAt(0).toUpperCase() }
            }
            Column {
                anchors.left: disc.right
                anchors.leftMargin: 12
                anchors.right: root.talking ? endBtn.left : parent.right
                anchors.rightMargin: 12
                y: 12
                GlassText { width: parent.width; font.pixelSize: root.ringing ? 16 : 13.5; font.weight: Font.DemiBold; text: PhoneLink.caller || Translation.tr("Call") }
                GlassText {
                    width: parent.width
                    color: Qt.rgba(1, 1, 1, 0.66)
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    text: root.ringing ? (PhoneLink.callDetail || Translation.tr("Incoming call"))
                        : Translation.tr("On the phone") + (PhoneLink.callSince > 0 ? " · " + root.clock(root.now - PhoneLink.callSince) : "")
                }
            }
            Row {
                visible: root.ringing
                x: 14
                y: card.height - 52
                spacing: 10
                GlassPillButton { width: (card.width - 38) / 2; tint: "#ff3b30"; label: Translation.tr("Decline"); onClicked: PhoneLink.decline() }
                GlassPillButton { width: (card.width - 38) / 2; tint: "#34c759"; label: Translation.tr("Answer"); onClicked: PhoneLink.answer() }
            }
            GlassPillButton {
                id: endBtn
                visible: root.talking
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 96
                height: 34
                tint: "#ff3b30"
                label: Translation.tr("End call")
                onClicked: PhoneLink.decline()
            }
        }
    }
}
