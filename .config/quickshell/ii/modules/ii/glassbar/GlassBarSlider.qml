import QtQuick
import qs.services

// Thick pill slider used inside panels; the filled part carries a small symbol.
Item {
    id: root
    property real value: 0 // 0..1
    property int glyph: 0
    signal moved(real value)

    width: parent ? parent.width : 280
    height: 34

    readonly property real shown: drag.pressed ? drag.live : Math.min(Math.max(value, 0), 1)
    Rectangle {
        id: track
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 16
        height: 22
        radius: 11
        color: Qt.rgba(1, 1, 1, 0.16)
        clip: true
        Rectangle {
            width: Math.max(parent.width * root.shown, 26)
            height: parent.height
            radius: 11
            color: "white"
        }
        Text {
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph > 0 ? String.fromCodePoint(root.glyph) : ""
            color: GlassBackdrop.tint
            font.family: GlassPanels.symbols
            font.pixelSize: 11
        }
    }
    MouseArea {
        id: drag
        anchors.fill: track
        property real live: 0
        function at(x) { return Math.min(Math.max(x / track.width, 0), 1) }
        onPressed: (e) => { live = at(e.x); root.moved(live) }
        onPositionChanged: (e) => { if (pressed) { live = at(e.x); root.moved(live) } }
        onWheel: (e) => root.moved(Math.min(Math.max(root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05), 0), 1))
    }
}
