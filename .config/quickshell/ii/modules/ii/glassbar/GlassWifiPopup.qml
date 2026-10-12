pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.ii.bar

// Wi-Fi hover pop-up: the network, its signal, link speed and this machine's address.
StyledPopup {
    id: root
    peekName: "wifi"

    readonly property var ap: Network.active
    readonly property bool wired: Network.ethernet
    readonly property bool online: wired || (Network.wifiEnabled && Network.wifiStatus === "connected")
    property string address: ""
    property string speed: ""
    property int polledStrength: 0   // asked from NetworkManager when the pop-up opens; the scan
    property int polledFrequency: 0  // list in Network is empty until the Wi-Fi panel has been opened
    readonly property int strength: ap?.strength || polledStrength || Network.networkStrength
    readonly property int frequency: ap?.frequency || polledFrequency

    onActiveChanged: if (active) details.running = true
    Column {
        id: col
        anchors.centerIn: parent
        width: 250
        spacing: 6

        Process { // "<ip>|<link speed>" of the connected Wi-Fi (or wired) device
            id: details
            command: ["bash", "-c", `
                dev=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '($2=="wifi"||$2=="ethernet")&&$3=="connected"{print $1":"$2}' | sort -t: -k2 | head -1)
                name=\${dev%%:*}; kind=\${dev##*:}
                ip=$(nmcli -g IP4.ADDRESS device show "$name" 2>/dev/null | head -1 | cut -d/ -f1)
                if [ "$kind" = wifi ]; then rate=$(iw dev "$name" link 2>/dev/null | awk '/tx bitrate/{printf "%d Mbps", $3}')
                else s=$(cat /sys/class/net/"$name"/speed 2>/dev/null); [ -n "$s" ] && [ "$s" -gt 0 ] && rate="$s Mbps"; fi
                air=$(nmcli -t -f IN-USE,SIGNAL,FREQ device wifi list --rescan no 2>/dev/null | awk -F: '$1=="*"{print $2"|"$3+0; exit}')
                echo "$ip|$rate|$air"`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const parts = text.trim().split("|")
                    root.address = parts[0] ?? ""
                    root.speed = parts[1] ?? ""
                    root.polledStrength = parseInt(parts[2]) || 0
                    root.polledFrequency = parseInt(parts[3]) || 0
                }
            }
        }

        Item {
            width: col.width
            height: 40
            GlassText {
                anchors.left: parent.left
                anchors.right: state.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 21
                font.weight: Font.DemiBold
                text: root.wired ? Translation.tr("Ethernet")
                    : !Network.wifiEnabled ? Translation.tr("Wi-Fi off")
                    : root.online ? (root.ap?.ssid || Network.networkName || Translation.tr("Wi-Fi"))
                    : Translation.tr("Not connected")
            }
            Column {
                id: state
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Network.wifiEnabled || root.wired
                GlassText {
                    anchors.right: parent.right
                    visible: root.online
                    font.weight: Font.DemiBold
                    text: Translation.tr("Connected")
                }
                GlassText {
                    anchors.right: parent.right
                    visible: text.length > 0
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    text: !root.online ? Translation.tr("Wi-Fi is on")
                        : root.wired || root.frequency <= 0 ? ""
                        : root.frequency >= 5925 ? "6 GHz" : root.frequency >= 4900 ? "5 GHz" : "2.4 GHz"
                }
            }
        }
        GlassMeter {
            visible: root.online && !root.wired
            value: root.strength / 100
        }
        Item { width: 1; height: 2; visible: root.online }
        GlassStatLine {
            visible: root.online && !root.wired
            label: Translation.tr("Signal")
            value: root.strength + "%"
        }
        GlassStatLine {
            visible: root.online && root.speed.length > 0
            label: Translation.tr("Link speed")
            value: root.speed
        }
        GlassStatLine {
            visible: root.online && root.address.length > 0
            label: Translation.tr("IP address")
            value: root.address
        }
        GlassText {
            visible: !root.online
            width: col.width
            horizontalAlignment: Text.AlignHCenter
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 11
            font.weight: Font.Normal
            text: Network.wifiEnabled ? Translation.tr("Click to choose a network") : Translation.tr("Click to open Wi-Fi")
        }
    }
}
