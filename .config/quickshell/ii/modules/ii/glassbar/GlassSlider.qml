import QtQuick
import qs.services

// A slider in its own long capsule of glass, with a small symbol at each end
GlassPiece {
    id: root
    property string title: ""
    property int lowGlyph: 0
    property int highGlyph: 0
    property real value: 0          // 0..1
    signal moved(real value)
    signal detailRequested() // click on the symbol at the right end

    height: 62
    radius: 24

    // Clicking anywhere on the capsule that is not the slider itself opens its settings.
    tintStrength: body.containsMouse ? 0.6 : 0.7
    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.detailRequested()
    }
    GlassText { x: 14; y: 9; text: root.title; font.weight: Font.DemiBold }
    Text { // hint that there is more behind it
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 11
        text: String.fromCodePoint(0x10018A)
        color: Qt.rgba(1, 1, 1, body.containsMouse ? 0.9 : 0.5)
        font.family: GlassPanels.symbols
        font.pixelSize: 9
    }
    Text {
        id: lo
        x: 14
        anchors.verticalCenter: track.verticalCenter
        text: root.lowGlyph > 0 ? String.fromCodePoint(root.lowGlyph) : ""
        color: "white"
        font.family: GlassPanels.symbols
        font.pixelSize: 11
    }
    Text {
        id: hi
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: track.verticalCenter
        text: root.highGlyph > 0 ? String.fromCodePoint(root.highGlyph) : ""
        color: "white"
        font.family: GlassPanels.symbols
        font.pixelSize: 13
        MouseArea {
            id: more
            anchors.centerIn: parent
            width: 28
            height: 28
            hoverEnabled: true
            onClicked: root.detailRequested()
            Rectangle { anchors.fill: parent; radius: 14; z: -1; color: Qt.rgba(1, 1, 1, more.containsMouse ? 0.2 : 0) }
        }
    }
    Item {
        id: track
        anchors.left: lo.right
        anchors.leftMargin: 10
        anchors.right: hi.left
        anchors.rightMargin: 10
        y: 34
        height: 18

        readonly property real shown: drag.pressed ? drag.live : Math.min(Math.max(root.value, 0), 1)
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 7; radius: 3.5; color: Qt.rgba(1, 1, 1, 0.22) }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * track.shown; height: 7; radius: 3.5; color: "white" }
        Rectangle {
            x: parent.width * track.shown - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 17
            height: 17
            radius: 8.5
            color: "white"
            scale: drag.pressed ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -6
            property real live: 0
            function at(x) { return Math.min(Math.max((x - 6) / track.width, 0), 1) }
            onPressed: (e) => { live = at(e.x); root.moved(live) }
            onPositionChanged: (e) => { if (pressed) { live = at(e.x); root.moved(live) } }
            onWheel: (e) => root.moved(Math.min(Math.max(root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05), 0), 1))
        }
    }
}
