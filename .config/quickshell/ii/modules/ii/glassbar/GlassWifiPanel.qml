pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.services.network
import qs.modules.common

GlassPanel {
    id: root
    name: "wifi"
    panelWidth: 300

    onWantedChanged: {
        if (wanted) {
            if (Network.wifiEnabled) Network.rescanWifi()
        } else {
            Network.wifiNetworks.forEach(n => { n.askingPassword = false; n.error = "" })
        }
    }

    // Keep what is shown current while the panel is open: re-read the list every few seconds and
    // ask for a fresh scan now and then. Paused while a menu is open or a password is being typed,
    // so rows don't move under the pointer.
    property bool busyWithRow: false
    Timer {
        interval: 4000
        repeat: true
        running: root.wanted && Network.wifiEnabled && !root.busyWithRow
        onTriggered: Network.refreshList()
    }
    Timer {
        interval: 20000
        repeat: true
        running: root.wanted && Network.wifiEnabled && !root.busyWithRow
        onTriggered: Network.quietRescan()
    }

    // Turning Wi-Fi on while the panel is open: look for networks once the radio is up.
    Timer {
        id: rescanSoon
        interval: 1800
        onTriggered: if (root.wanted && Network.wifiEnabled) Network.rescanWifi()
    }
    Connections {
        target: Network
        function onWifiEnabledChanged() { if (Network.wifiEnabled) rescanSoon.restart() }
    }

    body: Column {
        id: col
        spacing: 0

        readonly property var others: Network.friendlyWifiNetworks.filter(n => !n.active).slice(0, 8)
        property string typingFor: "" // network whose password field has text in it
        property string menuFor: ""   // network whose menu is open ("@active" for the connected one)

        // Stay open while a password is being typed or a connection is being made, even if the
        // pointer drifts off the panel.
        Binding { target: root; property: "busyWithRow"; value: col.menuFor.length > 0 || col.typingFor.length > 0 || col.others.some(n => n.askingPassword) }
        Binding {
            target: GlassPanels
            property: "pinned"
            value: root.wanted && (Network.wifiConnecting || col.typingFor.length > 0)
        }

        Item { // header
            width: col.width
            height: 32
            GlassText { x: 6; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi"; font.pixelSize: 14; font.weight: Font.DemiBold }
            GlassSwitch {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                checked: Network.wifiEnabled
                onToggled: Network.toggleWifi()
            }
        }

        GlassRow {
            visible: Network.ethernet
            glyph: GlassPanels.sf.laptop
            title: Translation.tr("Ethernet")
            subtitle: Translation.tr("Connected")
            selected: true
        }
        GlassRow { // the network in use
            visible: !!Network.active
            glyph: GlassPanels.sf.wifi
            title: Network.active?.ssid ?? ""
            subtitle: Translation.tr("Connected")
            trailingGlyph: (Network.active?.isSecure ?? false) ? GlassPanels.sf.lock : 0
            selected: true
            menu: true
            onMenuRequested: col.menuFor = (col.menuFor === "@active" ? "" : "@active")
        }
        GlassActions {
            open: col.menuFor === "@active" && !!Network.active
            actions: [
                { label: Translation.tr("Disconnect"), run: () => { Network.disconnectWifiNetwork(); col.menuFor = "" } },
                { label: Translation.tr("Forget"), danger: true, enabled: Network.savedSsids.includes(Network.active?.ssid ?? ""),
                  run: () => { Network.forgetWifiNetwork(Network.active.ssid); col.menuFor = "" } }
            ]
        }
        GlassText {
            visible: !Network.wifiEnabled
            width: col.width
            height: 34
            leftPadding: 8
            verticalAlignment: Text.AlignVCenter
            color: Qt.rgba(1, 1, 1, 0.7)
            font.weight: Font.Normal
            text: Translation.tr("Wi-Fi is off")
        }

        Item { // section line with its refresh button
            visible: Network.wifiEnabled
            width: col.width
            height: wifiCaption.implicitHeight
            GlassCaption {
                id: wifiCaption
                text: Network.wifiScanning ? Translation.tr("Looking for networks…") : Translation.tr("Other networks")
            }
            GlassRefresh {
                anchors.right: parent.right
                anchors.rightMargin: 6
                y: 3
                busy: Network.wifiScanning
                onClicked: if (!Network.wifiScanning) Network.rescanWifi()
            }
        }
        GlassText {
            visible: Network.wifiEnabled && !Network.wifiScanning && col.others.length === 0
            width: col.width
            height: 30
            leftPadding: 8
            verticalAlignment: Text.AlignVCenter
            color: Qt.rgba(1, 1, 1, 0.7)
            font.weight: Font.Normal
            text: Translation.tr("No other networks in range")
        }
        Repeater {
            model: ScriptModel { values: Network.wifiEnabled ? col.others : [] }

            Column {
                id: entry
                required property WifiAccessPoint modelData
                readonly property bool connecting: Network.wifiConnecting && Network.wifiConnectTarget === modelData
                readonly property bool saved: Network.savedSsids.includes(modelData.ssid)
                readonly property bool asking: modelData.isSecure && modelData.askingPassword && !connecting
                width: col.width

                function submit() {
                    if (pass.text.length >= 8) Network.connectWithPassword(entry.modelData, pass.text)
                }
                function cancel() {
                    pass.text = ""
                    entry.modelData.askingPassword = false
                    entry.modelData.error = ""
                }

                GlassRow {
                    glyph: GlassPanels.sf.wifi
                    glyphOpacity: entry.modelData.strength < 35 ? 0.45 : 1 // weak signal
                    title: entry.modelData.ssid
                    subtitle: entry.connecting ? Translation.tr("Connecting…")
                            : entry.modelData.error.length > 0 ? Translation.tr(entry.modelData.error)
                            : entry.asking ? Translation.tr("Enter the password")
                            : entry.saved ? Translation.tr("Saved") : ""
                    subtitleColor: (!entry.connecting && entry.modelData.error.length > 0) ? "#ff7a70" : Qt.rgba(1, 1, 1, 0.7)
                    trailingGlyph: entry.modelData.isSecure ? GlassPanels.sf.lock : 0
                    menu: true
                    onMenuRequested: col.menuFor = (col.menuFor === entry.modelData.ssid ? "" : entry.modelData.ssid)
                    onChosen: {
                        col.menuFor = ""
                        if (entry.connecting) return
                        if (entry.asking) pass.forceActiveFocus()
                        else Network.connectToWifiNetwork(entry.modelData)
                    }
                }

                GlassActions {
                    open: col.menuFor === entry.modelData.ssid
                    actions: [
                        { label: Translation.tr("Connect"), run: () => { col.menuFor = ""; Network.connectToWifiNetwork(entry.modelData) } },
                        { label: Translation.tr("Forget"), danger: true, enabled: entry.saved,
                          run: () => { Network.forgetWifiNetwork(entry.modelData.ssid); col.menuFor = "" } }
                    ]
                }

                Item { // password: field, show/hide, connect, cancel
                    visible: entry.asking
                    width: parent.width
                    height: visible ? 38 : 0

                    Rectangle {
                        id: field
                        x: 46
                        y: 2
                        width: parent.width - 46 - 44
                        height: 30
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        border.color: pass.activeFocus ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.25)

                        TextInput {
                            id: pass
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 46
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: reveal.shown ? TextInput.Normal : TextInput.Password
                            color: "white"
                            font.family: Appearance.font.family.main
                            font.pixelSize: 13
                            clip: true
                            onAccepted: entry.submit()
                            onTextChanged: {
                                if (text.length > 0) col.typingFor = entry.modelData.ssid
                                else if (col.typingFor === entry.modelData.ssid) col.typingFor = ""
                            }
                            Keys.onEscapePressed: entry.cancel()
                            onVisibleChanged: if (visible) forceActiveFocus()
                        }
                        GlassText {
                            visible: pass.text.length === 0
                            anchors.fill: pass
                            verticalAlignment: Text.AlignVCenter
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.weight: Font.Normal
                            text: Translation.tr("Password")
                        }
                        MouseArea { // show or hide what was typed
                            id: reveal
                            property bool shown: false
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: revealText.implicitWidth + 12
                            height: 22
                            onClicked: { shown = !shown; pass.forceActiveFocus() }
                            GlassText {
                                id: revealText
                                anchors.centerIn: parent
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font.pixelSize: 11
                                text: reveal.shown ? Translation.tr("Hide") : Translation.tr("Show")
                            }
                        }
                    }
                    MouseArea { // connect
                        id: go
                        anchors.left: field.right
                        anchors.leftMargin: 6
                        y: 2
                        width: 30
                        height: 30
                        hoverEnabled: true
                        enabled: pass.text.length >= 8
                        onClicked: entry.submit()
                        Rectangle {
                            anchors.fill: parent
                            radius: 15
                            color: go.enabled ? "white" : Qt.rgba(1, 1, 1, 0.14)
                            scale: go.pressed ? 0.9 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(GlassPanels.sf.arrow)
                            color: go.enabled ? GlassBackdrop.tint : Qt.rgba(1, 1, 1, 0.5)
                            font.family: GlassPanels.symbols
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        Rectangle { width: col.width - 12; x: 6; height: 1; color: Qt.rgba(1, 1, 1, 0.14) }
        Item { height: 4; width: 1 }

        // Cloudflare WARP, shown only when warp-cli is installed
        GlassRow {
            id: warp
            property bool installed: false
            property bool connected: false
            visible: installed
            glyph: GlassPanels.sf.shield
            title: "Cloudflare WARP"
            subtitle: connected ? Translation.tr("On") : Translation.tr("Off")
            function flip() {
                Quickshell.execDetached(["warp-cli", connected ? "disconnect" : "connect"])
                connected = !connected
            }
            onChosen: flip()
            GlassSwitch { checked: warp.connected; onToggled: warp.flip() }
            Process {
                running: true
                command: ["sh", "-c", "command -v warp-cli >/dev/null && warp-cli status 2>/dev/null"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        warp.installed = text.trim().length > 0
                        warp.connected = /Connected/.test(text) && !/Disconnected/.test(text)
                    }
                }
            }
        }

        GlassRow {
            height: 34
            glyph: GlassPanels.sf.gear
            title: Translation.tr("Network settings")
            trailingGlyph: GlassPanels.sf.chevron
            onChosen: {
                Quickshell.execDetached(["bash", "-c", Config.options.apps.network])
                GlassPanels.close()
            }
        }
    }
}
