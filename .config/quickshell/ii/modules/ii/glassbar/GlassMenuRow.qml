import QtQuick
import qs.services

// One plain line in a glass menu: text, optional tick or sub-menu arrow on the right.
MouseArea {
    id: root

    property string text: ""
    property bool selected: false
    property bool danger: false     // red, for closing / quitting
    property bool ticked: false
    property bool more: false       // leads to a sub-menu
    signal chosen()

    width: parent ? parent.width : 220
    height: 30
    hoverEnabled: true
    onClicked: chosen()

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Qt.rgba(1, 1, 1, root.selected ? 0.14 : (root.containsMouse && root.enabled ? 0.1 : 0))
        Behavior on color { ColorAnimation { duration: 110 } }
    }
    GlassText {
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.right: mark.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.danger ? "#ff8a80" : "white"
        opacity: root.enabled ? 1 : 0.4
    }
    Text {
        id: mark
        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? implicitWidth : 0
        visible: root.ticked || root.more
        text: String.fromCodePoint(root.more ? GlassPanels.sf.chevron : GlassPanels.sf.check)
        color: Qt.rgba(1, 1, 1, 0.75)
        opacity: root.enabled ? 1 : 0.4
        font.family: GlassPanels.symbols
        font.pixelSize: 11
    }
}
