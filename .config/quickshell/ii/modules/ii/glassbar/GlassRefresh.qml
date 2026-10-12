import QtQuick
import qs.services

// Small refresh button for a section line; the arrow spins while `busy`.
MouseArea {
    id: root
    property bool busy: false
    width: 22
    height: 22
    hoverEnabled: true

    Rectangle {
        anchors.fill: parent
        radius: 11
        color: Qt.rgba(1, 1, 1, root.containsMouse ? 0.16 : 0)
        Behavior on color { ColorAnimation { duration: 110 } }
    }
    Image { // two arrows chasing each other
        id: arrow
        anchors.centerIn: parent
        width: 13
        height: 13
        sourceSize: Qt.size(40, 40)
        source: Qt.resolvedUrl("../../../assets/icons/glassbar/refresh.svg")
        opacity: root.containsMouse || root.busy ? 1 : 0.7
        scale: root.pressed ? 0.85 : 1
        RotationAnimation on rotation {
            running: root.busy
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            onRunningChanged: if (!running) arrow.rotation = 0
        }
    }
}
