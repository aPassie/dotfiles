pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Segmented choice: options = [{ label, value }]
Item {
    id: root
    property var options: []
    property var current
    property bool usable: true
    signal picked(var value)

    width: parent ? parent.width : 280
    height: 34
    opacity: usable ? 1 : 0.5

    Rectangle {
        x: 4
        y: 2
        width: parent.width - 8
        height: 30
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.1)
        Row {
            anchors.fill: parent
            anchors.margins: 2
            Repeater {
                model: root.options
                MouseArea {
                    id: seg
                    required property var modelData
                    readonly property bool on: modelData.value === root.current
                    width: parent.width / root.options.length
                    height: parent.height
                    enabled: root.usable
                    hoverEnabled: true
                    onClicked: root.picked(modelData.value)
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: seg.on ? "white" : Qt.rgba(1, 1, 1, seg.containsMouse ? 0.12 : 0)
                        Behavior on color { ColorAnimation { duration: 110 } }
                    }
                    GlassText {
                        anchors.centerIn: parent
                        font.pixelSize: 12
                        font.weight: seg.on ? Font.DemiBold : Font.Medium
                        color: seg.on ? GlassBackdrop.tint : "white"
                        text: seg.modelData.label
                    }
                }
            }
        }
    }
}
