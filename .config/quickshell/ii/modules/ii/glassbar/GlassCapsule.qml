import QtQuick
import qs.services

// A control drawn as a capsule: round disc with a symbol, name, and current state.
// Clicking the disc switches it on or off. Clicking anywhere else on the capsule (or
// right-clicking) opens its settings, when it has any; otherwise the whole capsule is the switch.
GlassPiece {
    id: root
    property int glyph: 0
    property string title: ""
    property string subtitle: ""
    property bool on: false
    property bool usable: true      // the switch itself can be used
    property bool detail: false     // has a settings panel
    signal activated()
    signal detailRequested()

    height: 56
    radius: 28
    tintStrength: (tile.containsMouse && !discArea.containsMouse) ? 0.6 : 0.7

    MouseArea { // the capsule body
        id: tile
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => {
            if (root.detail) root.detailRequested()
            else if (m.button === Qt.LeftButton && root.usable) root.activated()
        }
    }
    Rectangle {
        id: disc
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: 19
        opacity: root.usable ? 1 : 0.45
        color: root.on ? "white" : Qt.rgba(1, 1, 1, discArea.containsMouse ? 0.3 : 0.16)
        scale: discArea.pressed ? 0.9 : (discArea.containsMouse ? 1.06 : 1)
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.4; mass: 0.4 } }
        Text {
            anchors.centerIn: parent
            text: root.glyph > 0 ? String.fromCodePoint(root.glyph) : ""
            color: root.on ? "#0a84ff" : "white"
            font.family: GlassPanels.symbols
            font.pixelSize: 15
        }
        MouseArea { // the switch
            id: discArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                if (m.button === Qt.RightButton) { if (root.detail) root.detailRequested(); return }
                if (root.usable) root.activated()
            }
        }
    }
    Column {
        anchors.left: disc.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        GlassText { width: parent.width; text: root.title; font.weight: Font.DemiBold }
        GlassText {
            width: parent.width
            text: root.subtitle
            color: Qt.rgba(1, 1, 1, 0.72)
            font.pixelSize: 11
            font.weight: Font.Normal
        }
    }
}
