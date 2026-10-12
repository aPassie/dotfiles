pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.ii.bar

// Bluetooth hover pop-up: the connected devices and their battery, where they report one.
StyledPopup {
    id: root
    peekName: "bluetooth"

    readonly property var devices: BluetoothStatus.connectedDevices
    function glyphFor(icon) {
        const s = String(icon || "")
        if (s.includes("head") || s.includes("audio")) return GlassPanels.sf.headphones
        if (s.includes("mouse")) return GlassPanels.sf.mouse
        if (s.includes("keyboard")) return GlassPanels.sf.keyboard
        if (s.includes("phone")) return GlassPanels.sf.phone
        if (s.includes("computer") || s.includes("laptop")) return GlassPanels.sf.laptop
        return GlassPanels.sf.speaker
    }

    Column {
        id: col
        anchors.centerIn: parent
        width: 250
        spacing: 6

        Item {
            width: col.width
            height: 40
            GlassText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 21
                font.weight: Font.DemiBold
                text: BluetoothStatus.enabled ? Translation.tr("Bluetooth") : Translation.tr("Bluetooth off")
            }
            GlassText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: BluetoothStatus.enabled
                color: root.devices.length > 0 ? "white" : Qt.rgba(1, 1, 1, 0.7)
                font.pixelSize: root.devices.length > 0 ? 13 : 12
                font.weight: root.devices.length > 0 ? Font.DemiBold : Font.Normal
                text: root.devices.length > 0 ? Translation.tr("%1 connected").arg(root.devices.length) : Translation.tr("No devices connected")
            }
        }
        Rectangle {
            visible: BluetoothStatus.enabled && root.devices.length > 0
            width: col.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }
        Repeater {
            model: BluetoothStatus.enabled ? root.devices : []
            Item {
                id: dev
                required property var modelData
                readonly property bool hasBattery: modelData.batteryAvailable
                width: col.width
                height: 24
                Text {
                    id: icon
                    width: 18
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    color: "white"
                    font.family: GlassPanels.symbols
                    font.pixelSize: 13
                    text: String.fromCodePoint(root.glyphFor(dev.modelData.icon))
                }
                GlassText {
                    anchors.left: icon.right
                    anchors.leftMargin: 10
                    anchors.right: tail.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: dev.modelData.name
                }
                Row {
                    id: tail
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    GlassMeter {
                        visible: dev.hasBattery
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 5
                        value: dev.modelData.battery
                        fill: dev.modelData.battery <= 0.2 ? "#ff453a" : "white"
                    }
                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: dev.hasBattery ? 34 : implicitWidth
                        horizontalAlignment: Text.AlignRight
                        color: dev.hasBattery ? "white" : Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: dev.hasBattery ? 13 : 12
                        font.weight: dev.hasBattery ? Font.DemiBold : Font.Normal
                        text: dev.hasBattery ? Math.round(dev.modelData.battery * 100) + "%" : Translation.tr("no battery info")
                    }
                }
            }
        }
        GlassText {
            visible: !BluetoothStatus.enabled
            width: col.width
            horizontalAlignment: Text.AlignHCenter
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 11
            font.weight: Font.Normal
            text: Translation.tr("Click to open Bluetooth")
        }
    }
}
