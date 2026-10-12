pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.common

GlassPanel {
    id: root
    name: "bluetooth"
    panelWidth: 300

    // Look for nearby devices only while the panel is open.
    onWantedChanged: {
        const a = Bluetooth.defaultAdapter
        if (a && a.enabled) a.discovering = wanted
        if (wanted) pulse.restart()
    }

    // Refresh: restart the search for nearby devices and show it as busy for a few seconds.
    function rescan() {
        const a = Bluetooth.defaultAdapter
        if (!a || !a.enabled) return
        a.discovering = false
        restart.restart()
        pulse.restart()
    }
    Timer { id: restart; interval: 250; onTriggered: { const a = Bluetooth.defaultAdapter; if (a && a.enabled && root.wanted) a.discovering = true } }
    Timer { id: pulse; interval: 6000 }
    readonly property bool scanning: pulse.running

    function glyphFor(icon) {
        const s = String(icon || "")
        if (s.includes("head") || s.includes("audio")) return GlassPanels.sf.headphones
        if (s.includes("mouse")) return GlassPanels.sf.mouse
        if (s.includes("keyboard")) return GlassPanels.sf.keyboard
        if (s.includes("phone")) return GlassPanels.sf.phone
        if (s.includes("computer") || s.includes("laptop")) return GlassPanels.sf.laptop
        if (s.includes("speaker")) return GlassPanels.sf.speaker
        return 0
    }

    body: Column {
        id: col
        spacing: 0

        readonly property bool on: Bluetooth.defaultAdapter?.enabled ?? false
        property string menuFor: "" // address of the device whose menu is open
        readonly property var mine: on ? [...BluetoothStatus.connectedDevices, ...BluetoothStatus.pairedButNotConnectedDevices] : []
        readonly property var nearby: on ? BluetoothStatus.unpairedDevices.filter(d => (d.name ?? "").length > 0 && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(d.name)).slice(0, 4) : []

        Item { // header
            width: col.width
            height: 32
            GlassText { x: 6; anchors.verticalCenter: parent.verticalCenter; text: "Bluetooth"; font.pixelSize: 14; font.weight: Font.DemiBold }
            GlassSwitch {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                checked: col.on
                onToggled: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !col.on
            }
        }

        GlassText {
            visible: !col.on
            width: col.width
            height: 34
            leftPadding: 8
            verticalAlignment: Text.AlignVCenter
            color: Qt.rgba(1, 1, 1, 0.7)
            font.weight: Font.Normal
            text: Translation.tr("Bluetooth is off")
        }

        GlassCaption { visible: col.on; text: Translation.tr("My devices") }
        GlassText {
            visible: col.on && col.mine.length === 0
            width: col.width
            height: 30
            leftPadding: 8
            verticalAlignment: Text.AlignVCenter
            color: Qt.rgba(1, 1, 1, 0.7)
            font.weight: Font.Normal
            text: Translation.tr("No paired devices")
        }
        Repeater {
            model: ScriptModel { values: col.mine }
            Column {
                id: dev
                required property BluetoothDevice modelData
                readonly property int g: root.glyphFor(modelData.icon)
                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                width: col.width
                GlassRow {
                    glyph: dev.g
                    drawn: dev.g === 0 ? "bluetooth" : ""
                    title: dev.modelData.name || dev.modelData.address
                    subtitle: dev.modelData.state === BluetoothDeviceState.Connecting ? Translation.tr("Connecting…")
                            : dev.modelData.state === BluetoothDeviceState.Disconnecting ? Translation.tr("Disconnecting…")
                            : dev.modelData.connected ? Translation.tr("Connected") : Translation.tr("Not connected")
                    trailing: (dev.modelData.connected && dev.modelData.batteryAvailable) ? Math.round(dev.modelData.battery * 100) + "%" : ""
                    selected: dev.modelData.connected
                    menu: true
                    onMenuRequested: col.menuFor = (col.menuFor === dev.modelData.address ? "" : dev.modelData.address)
                    onChosen: {
                        col.menuFor = ""
                        if (dev.busy) return
                        dev.modelData.connected ? dev.modelData.disconnect() : dev.modelData.connect()
                    }
                }
                GlassActions {
                    open: col.menuFor === dev.modelData.address
                    actions: [
                        dev.modelData.connected
                            ? { label: Translation.tr("Disconnect"), run: () => { dev.modelData.disconnect(); col.menuFor = "" } }
                            : { label: Translation.tr("Connect"), run: () => { dev.modelData.connect(); col.menuFor = "" } },
                        { label: Translation.tr("Forget"), danger: true, run: () => { col.menuFor = ""; dev.modelData.forget() } }
                    ]
                }
            }
        }

        Item { // section line with its refresh button
            visible: col.on
            width: col.width
            height: btCaption.implicitHeight
            GlassCaption {
                id: btCaption
                text: root.scanning ? Translation.tr("Looking for devices…") : Translation.tr("Nearby")
            }
            GlassRefresh {
                anchors.right: parent.right
                anchors.rightMargin: 6
                y: 3
                busy: root.scanning
                onClicked: if (!root.scanning) root.rescan()
            }
        }
        GlassText {
            visible: col.on && col.nearby.length === 0
            width: col.width
            height: 30
            leftPadding: 8
            verticalAlignment: Text.AlignVCenter
            color: Qt.rgba(1, 1, 1, 0.7)
            font.weight: Font.Normal
            text: root.scanning ? Translation.tr("Searching…") : Translation.tr("No new devices nearby")
        }
        Repeater {
            model: ScriptModel { values: col.nearby }
            GlassRow {
                required property BluetoothDevice modelData
                readonly property int g: root.glyphFor(modelData.icon)
                glyph: g
                drawn: g === 0 ? "bluetooth" : ""
                title: modelData.name
                trailing: modelData.pairing ? Translation.tr("Pairing…") : Translation.tr("Pair")
                onChosen: modelData.pair()
            }
        }

        Rectangle { width: col.width - 12; x: 6; height: 1; color: Qt.rgba(1, 1, 1, 0.14) }
        Item { height: 4; width: 1 }
        GlassRow {
            height: 34
            glyph: GlassPanels.sf.gear
            title: Translation.tr("Bluetooth settings")
            trailingGlyph: GlassPanels.sf.chevron
            onChosen: {
                Quickshell.execDetached(["bash", "-c", Config.options.apps.bluetooth])
                GlassPanels.close()
            }
        }
    }
}
