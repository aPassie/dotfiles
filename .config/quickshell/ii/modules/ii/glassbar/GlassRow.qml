import QtQuick
import qs.services
import qs.modules.common

// One line in a glass panel: round icon, title, optional second line, something on the right.
MouseArea {
    id: root

    property int glyph: 0               // SF Symbol code point
    property string drawn: ""           // or the name of a hand-drawn icon in assets/icons/glassbar
    property string title: ""
    property string subtitle: ""
    property string trailing: ""        // short text on the right
    property int trailingGlyph: 0       // or a symbol on the right
    property bool selected: false
    property real glyphOpacity: 1       // e.g. dimmed for a weak signal
    property color subtitleColor: Qt.rgba(1, 1, 1, 0.7)
    default property alias extra: slot.data // or any item (a switch, say)

    // Use onChosen for the normal click. With `menu: true`, a right-click or a double-tap asks for
    // the row's menu instead; the normal click then waits a moment so a double-tap isn't also a click.
    property bool menu: false
    signal chosen()
    signal menuRequested()
    property double menuAt: 0
    acceptedButtons: menu ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
    Timer { id: singleClick; interval: 230; onTriggered: root.chosen() }
    function askMenu() {
        singleClick.stop()
        menuAt = Date.now()
        menuRequested()
    }
    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) { askMenu(); return }
        if (Date.now() - menuAt < 350) return
        if (menu) singleClick.restart()
        else chosen()
    }
    onDoubleClicked: (mouse) => { if (menu && mouse.button === Qt.LeftButton) askMenu() }

    width: parent ? parent.width : 280
    height: 42
    hoverEnabled: true

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(1, 1, 1, root.selected ? 0.14 : (root.containsMouse ? 0.08 : 0))
        Behavior on color { ColorAnimation { duration: 110 } }
    }
    Rectangle {
        id: disc
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 14
        color: root.selected ? "white" : Qt.rgba(1, 1, 1, 0.12)
        Text {
            visible: root.glyph > 0
            anchors.centerIn: parent
            text: root.glyph > 0 ? String.fromCodePoint(root.glyph) : ""
            opacity: root.glyphOpacity
            color: root.selected ? GlassBackdrop.tint : "white"
            font.family: GlassPanels.symbols
            font.pixelSize: 13
        }
        Image {
            visible: root.drawn.length > 0
            anchors.centerIn: parent
            width: 17
            height: 17
            sourceSize: Qt.size(34, 34)
            source: root.drawn.length > 0 ? Qt.resolvedUrl(`../../../assets/icons/glassbar/${root.drawn}${root.selected ? "-dark" : ""}.svg`) : ""
        }
    }
    Column {
        anchors.left: disc.right
        anchors.leftMargin: 10
        anchors.right: tail.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        GlassText { width: parent.width; text: root.title }
        GlassText {
            visible: text.length > 0
            width: parent.width
            text: root.subtitle
            color: root.subtitleColor
            font.pixelSize: 11
            font.weight: Font.Normal
        }
    }
    Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        GlassText {
            visible: text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.trailing
            color: Qt.rgba(1, 1, 1, 0.75)
            font.pixelSize: 11
            font.weight: Font.Normal
        }
        Text {
            visible: root.trailingGlyph > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.trailingGlyph > 0 ? String.fromCodePoint(root.trailingGlyph) : ""
            color: Qt.rgba(1, 1, 1, 0.75)
            font.family: GlassPanels.symbols
            font.pixelSize: 11
        }
        Item {
            id: slot
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
