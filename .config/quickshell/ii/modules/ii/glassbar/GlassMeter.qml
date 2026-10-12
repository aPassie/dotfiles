import QtQuick

// Thin level bar used inside the hover pop-ups
Item {
    id: root
    property real value: 0 // 0..1
    property color fill: "white"
    width: parent ? parent.width : 240
    height: 6
    Rectangle { anchors.fill: parent; radius: 3; color: Qt.rgba(1, 1, 1, 0.16) }
    Rectangle {
        width: Math.max(parent.width * Math.min(Math.max(root.value, 0), 1), root.value > 0 ? 6 : 0)
        height: parent.height
        radius: 3
        color: root.fill
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }
}
