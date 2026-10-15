pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// A small progress pop-up for files moving to or from the phone (when the phone panel is
// not open): name, link, speed and a bar; it says "Sent" / "Received" and fades.
Scope {
    id: root
    readonly property var t: PhoneLink.transfers.length > 0 ? PhoneLink.transfers[0] : null
    property bool showing: false
    property string lastDone: ""
    readonly property real barH: Appearance.sizes.baseBarHeight

    onTChanged: {
        if (!t) { showing = false; return }
        if (t.status === "active") { showing = true; linger.stop() }
        else if (showing && t.id !== lastDone) { lastDone = t.id; linger.restart() }
    }
    Timer { id: linger; interval: 2500; onTriggered: root.showing = false }

    PanelWindow {
        id: win
        visible: root.showing && GlassPanels.open !== "phone" && !GlobalStates.screenLocked
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

        GlassPiece {
            id: card
            x: 34
            y: root.barH + 6
            width: 340
            height: 64
            radius: 20
            tintStrength: 0.7
            readonly property var t: root.t ?? ({})
            readonly property bool done: t.status === "done"

            Rectangle {
                id: disc
                x: 14; y: 13
                width: 38; height: 38; radius: 19
                color: Qt.rgba(1, 1, 1, 0.14)
                Text { anchors.centerIn: parent; color: "white"; font.family: GlassPanels.symbols; font.pixelSize: 15; text: String.fromCodePoint(GlassPanels.sf.phone) }
            }
            Column {
                anchors.left: disc.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 11
                spacing: 1
                GlassText {
                    width: parent.width
                    font.weight: Font.DemiBold
                    text: card.done ? (card.t.dir === "in" ? Translation.tr("Received from %1") : Translation.tr("Sent to %1")).arg(PhoneLink.name)
                        : card.t.status === "failed" ? Translation.tr("Transfer failed")
                        : (card.t.dir === "in" ? Translation.tr("Receiving from %1") : Translation.tr("Sending to %1")).arg(PhoneLink.name)
                }
                GlassText {
                    width: parent.width
                    color: Qt.rgba(1, 1, 1, 0.66)
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    text: (card.t.name ?? "") + " · " + (card.t.via === "wi-fi direct" ? "Wi-Fi Direct" : "Bluetooth")
                        + (card.t.status === "active" && card.t.rate > 0 ? " · " + PhoneLink.size(card.t.rate) + "/s" : "")
                }
                Item { width: 1; height: 4 }
                GlassMeter { width: parent.width; value: card.t.size > 0 ? card.t.done / card.t.size : 0 }
            }
        }
    }
}
