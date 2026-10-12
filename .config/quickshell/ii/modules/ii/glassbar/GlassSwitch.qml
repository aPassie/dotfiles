import QtQuick

// macOS-style switch
MouseArea {
    id: root
    property bool checked: false
    signal toggled()
    width: 34
    height: 20
    onClicked: toggled()

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.checked ? "#30d158" : Qt.rgba(1, 1, 1, 0.2)
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    Rectangle {
        y: 2
        x: root.checked ? 16 : 2
        width: 16
        height: 16
        radius: 8
        color: "white"
        Behavior on x { SpringAnimation { spring: 6; damping: 0.5; mass: 0.4 } }
    }
}
