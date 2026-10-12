pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.ii.bar

// Battery pop-up: level, state and time, power draw, health; click the battery for what is
// using the most power.
StyledPopup {
    id: root
    property bool expanded: false   // set by the bar when the battery is clicked
    property var consumers: []      // [{ name, watts }] from ii-battery-power
    pinned: expanded
    peekName: "battery"
    onExpandedChanged: if (!expanded) consumers = []

    readonly property bool full: Battery.chargeState == 4
    readonly property bool charging: Battery.isCharging
    readonly property real timeLeft: charging ? Battery.timeToFull : Battery.timeToEmpty
    readonly property bool hasTime: !(full || timeLeft <= 0 || Battery.energyRate <= 0.01)
    function span(seconds) {
        const h = Math.floor(seconds / 3600), m = Math.floor((seconds % 3600) / 60)
        return h > 0 ? `${h} h ${m} min` : `${m} min`
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
                id: big
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 30
                font.weight: Font.DemiBold
                text: Math.round(Battery.percentage * 100) + "%"
            }
            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                GlassText {
                    anchors.right: parent.right
                    font.weight: Font.DemiBold
                    text: root.full ? Translation.tr("Fully charged") : root.charging ? Translation.tr("Charging")
                        : Battery.isPluggedIn ? Translation.tr("Plugged in") : Translation.tr("On battery")
                }
                GlassText {
                    visible: root.hasTime
                    anchors.right: parent.right
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    text: root.charging ? Translation.tr("%1 until full").arg(root.span(root.timeLeft)) : Translation.tr("%1 left").arg(root.span(root.timeLeft))
                }
            }
        }
        GlassMeter {
            value: Battery.percentage
            fill: (Battery.isLow && !root.charging) ? "#ff453a" : root.charging ? "#30d158" : "white"
        }
        Item { width: 1; height: 2 }
        GlassStatLine {
            visible: !(Battery.chargeState != 4 && Battery.energyRate == 0) && !root.full
            label: Battery.chargeState == 1 ? Translation.tr("Charging at") : Translation.tr("Using")
            value: `${Battery.energyRate.toFixed(2)} W`
        }
        GlassStatLine { label: Translation.tr("Battery health"); value: `${Battery.health.toFixed(1)}%` }

        GlassText {
            visible: !root.expanded
            width: col.width
            topPadding: 2
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 11
            font.weight: Font.Normal
            text: Translation.tr("Click the battery to see what is using power")
        }

        // ── What is using the most power (after a click) ───────────────────
        Rectangle { visible: root.expanded; width: col.width; height: 1; color: Qt.rgba(1, 1, 1, 0.14) }
        GlassCaption { visible: root.expanded; leftPadding: 0; topPadding: 2; text: Translation.tr("Using the most power · estimated") }
        GlassText {
            visible: root.expanded && root.consumers.length === 0
            color: Qt.rgba(1, 1, 1, 0.7)
            font.weight: Font.Normal
            text: Translation.tr("Measuring…")
        }
        Repeater {
            model: ScriptModel { values: root.expanded ? root.consumers : [] }
            Column {
                id: user
                required property var modelData
                width: col.width
                spacing: 3
                GlassStatLine { label: user.modelData.name; value: `${user.modelData.watts.toFixed(2)} W` }
                GlassMeter {
                    height: 3
                    value: root.consumers.length > 0 ? user.modelData.watts / Math.max(root.consumers[0].watts, 0.01) : 0
                    fill: Qt.rgba(1, 1, 1, 0.7)
                }
            }
        }

        Process {
            id: powerProc
            command: ["/home/shanks/.local/bin/ii-battery-power"]
            stdout: StdioCollector {
                id: powerOut
                onStreamFinished: {
                    try { root.consumers = (JSON.parse(powerOut.text).top) || [] } catch (e) { root.consumers = [] }
                }
            }
        }
        Timer {
            running: root.expanded
            interval: 2000
            repeat: true
            triggeredOnStart: true
            onTriggered: if (!powerProc.running) powerProc.running = true
        }
    }
}
