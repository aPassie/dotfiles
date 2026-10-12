import QtQuick
import qs.services

// A round one-tap button in its own bead of glass
GlassPiece {
    id: root
    property int glyph: 0
    property int glyphSize: 16
    property bool dots: false // draw "more" as three dots instead of a symbol
    signal activated()

    width: 48
    height: 48
    radius: 24
    tintStrength: mouse.containsMouse ? 0.5 : 0.7
    scale: mouse.pressed ? 0.9 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.4; mass: 0.4 } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
    }
    Row {
        visible: root.dots
        anchors.centerIn: parent
        spacing: 3
        Repeater { model: 3; Rectangle { width: 4; height: 4; radius: 2; color: "white" } }
    }
    Text {
        visible: !root.dots
        anchors.centerIn: parent
        text: root.glyph > 0 ? String.fromCodePoint(root.glyph) : ""
        color: "white"
        font.family: GlassPanels.symbols
        font.pixelSize: root.glyphSize
    }
}
