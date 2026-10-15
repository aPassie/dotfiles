pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// The phone panel (click the phone icon): battery and link, send files or the clipboard,
// a drop zone, and recent transfers with live progress.
GlassPanel {
    id: root
    name: "phone"
    panelWidth: 320

    body: Column {
        id: col
        spacing: 10

        Item { // header
            width: col.width
            height: 42
            Rectangle {
                id: disc
                width: 38; height: 38; radius: 19
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(GlassPanels.sf.phone)
                    color: "white"
                    font.family: GlassPanels.symbols
                    font.pixelSize: 16
                }
            }
            Column {
                anchors.left: disc.right
                anchors.leftMargin: 12
                anchors.right: pct.left
                anchors.verticalCenter: parent.verticalCenter
                GlassText { width: parent.width; font.pixelSize: 16; font.weight: Font.DemiBold; text: PhoneLink.name }
                GlassText {
                    width: parent.width
                    color: Qt.rgba(1, 1, 1, 0.66)
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    text: !PhoneLink.connected ? Translation.tr("Not connected")
                        : PhoneLink.fastOpen || PhoneLink.st.via === "wi-fi" ? PhoneLink.link : Translation.tr("Bluetooth · fast transfers ready")
                }
            }
            GlassText {
                id: pct
                visible: PhoneLink.connected && PhoneLink.battery >= 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: PhoneLink.battery + "%"
            }
        }
        GlassMeter { visible: PhoneLink.connected && PhoneLink.battery >= 0; value: PhoneLink.battery / 100 }

        // not connected (the phone's Bluetooth is off): one tap here, one on the phone
        GlassPillButton {
            visible: !PhoneLink.connected
            width: col.width
            primary: !PhoneLink.looking
            label: PhoneLink.looking ? Translation.tr("Looking for the phone…") : Translation.tr("Connect over Wi-Fi")
            onClicked: if (!PhoneLink.looking) PhoneLink.connectWifi()
        }
        GlassText {
            visible: !PhoneLink.connected
            width: col.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: Qt.rgba(1, 1, 1, 0.66)
            font.pixelSize: 12
            font.weight: Font.Normal
            text: Translation.tr("On the phone, tap Connect over Wi-Fi in PhoneLink or its Quick Settings tile. Bluetooth reconnects by itself when it is on.")
        }

        Row {
            visible: PhoneLink.connected
            spacing: 8
            GlassPillButton { width: (col.width - 8) / 2; primary: true; label: Translation.tr("Send files…"); onClicked: { PhoneLink.pickFiles(); GlassPanels.close() } }
            GlassPillButton { width: (col.width - 8) / 2; label: Translation.tr("Send clipboard"); onClicked: PhoneLink.sendClipboard() }
        }

        DropArea {
            id: drop
            visible: PhoneLink.connected
            width: col.width
            height: 64
            onDropped: (d) => {
                if (!d.hasUrls) return
                PhoneLink.sendPaths(d.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))))
                d.acceptProposedAction()
            }
            Rectangle {
                anchors.fill: parent
                radius: 16
                color: drop.containsDrag ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                border.width: 1.5
                border.color: drop.containsDrag ? "white" : Qt.rgba(1, 1, 1, 0.35)
            }
            GlassText {
                anchors.centerIn: parent
                color: drop.containsDrag ? "white" : Qt.rgba(1, 1, 1, 0.75)
                font.weight: Font.Normal
                text: drop.containsDrag ? Translation.tr("Drop to send") : Translation.tr("Drop files here to send")
            }
        }

        Rectangle { visible: PhoneLink.transfers.length > 0; width: col.width; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }
        GlassCaption {
            visible: PhoneLink.transfers.length > 0
            text: PhoneLink.transfers.some(t => t.status === "active") ? Translation.tr("Now") : Translation.tr("Recent")
        }
        Repeater {
            model: PhoneLink.transfers.slice(0, 4)
            MouseArea {
                id: tr
                required property var modelData
                readonly property bool active: modelData.status === "active"
                width: col.width
                height: active ? 50 : 42
                hoverEnabled: true
                enabled: modelData.status === "done" && (modelData.path ?? "").length > 0
                onClicked: { PhoneLink.openTransfer(modelData); GlassPanels.close() }
                Rectangle { anchors.fill: parent; radius: 12; color: Qt.rgba(1, 1, 1, tr.containsMouse ? 0.08 : 0) }
                Rectangle {
                    id: ic
                    x: 6; y: 8
                    width: 26; height: 26; radius: 13
                    color: Qt.rgba(1, 1, 1, 0.12)
                    GlassText { anchors.centerIn: parent; font.pixelSize: 12; text: tr.modelData.dir === "in" ? "↓" : "↑" }
                }
                Column {
                    anchors.left: ic.right
                    anchors.leftMargin: 10
                    anchors.right: right.left
                    anchors.rightMargin: 8
                    y: 4
                    GlassText { width: parent.width; text: tr.modelData.name }
                    GlassText {
                        width: parent.width
                        color: tr.modelData.status === "failed" ? "#ff8a80" : Qt.rgba(1, 1, 1, 0.66)
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        text: {
                            const t = tr.modelData
                            const via = t.via === "wi-fi direct" ? "Wi-Fi Direct" : "Bluetooth"
                            if (t.status === "active") {
                                const left = t.rate > 0 ? Math.max(0, Math.round((t.size - t.done) / t.rate)) : -1
                                return via + " · " + PhoneLink.size(t.rate) + "/s" + (left >= 0 ? " · " + left + " s left" : "")
                            }
                            if (t.status === "failed") return Translation.tr("failed")
                            return (t.dir === "in" ? Translation.tr("from phone") : Translation.tr("to phone")) + " · " + via
                        }
                    }
                    GlassMeter {
                        visible: tr.active
                        width: parent.width
                        value: tr.modelData.size > 0 ? tr.modelData.done / tr.modelData.size : 0
                    }
                }
                GlassText {
                    id: right
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 12
                    color: tr.active ? "white" : Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 12
                    text: tr.active && tr.modelData.size > 0 ? Math.round(100 * tr.modelData.done / tr.modelData.size) + "%" : PhoneLink.size(tr.modelData.size)
                }
            }
        }
    }
}
