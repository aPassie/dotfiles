pragma ComponentBehavior: Bound

import QtQuick

// A strip of small action buttons that slides open under a row (right-click / double-tap menu).
// actions: [{ label, run, enabled (default true), danger (default false) }]
Item {
    id: root
    property var actions: []
    property bool open: false
    property real inset: 46

    width: parent ? parent.width : 0
    height: open ? 34 : 0
    visible: height > 0
    clip: true
    Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    Row {
        x: root.inset
        y: 2
        spacing: 6
        Repeater {
            model: root.actions
            MouseArea {
                id: btn
                required property var modelData
                readonly property bool usable: modelData.enabled !== false
                width: label.implicitWidth + 22
                height: 26
                hoverEnabled: true
                enabled: usable
                opacity: usable ? 1 : 0.38
                onClicked: modelData.run()
                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    color: btn.modelData.danger ? Qt.rgba(1, 0.27, 0.23, btn.containsMouse ? 0.55 : 0.34)
                                                : Qt.rgba(1, 1, 1, btn.containsMouse ? 0.28 : 0.16)
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                GlassText { id: label; anchors.centerIn: parent; font.pixelSize: 12; text: btn.modelData.label }
            }
        }
    }
}
