import QtQuick
import qs.services

// One free-floating piece of glass (macOS 27 style): tinted, thin bright rim, soft shadow.
// Children are laid out inside it.
Item {
    id: root
    property real radius: 24
    property real tintStrength: 0.7
    property color fill: GlassBackdrop.tint
    default property alias content: inner.data

    ShaderEffect {
        readonly property real m: 16
        x: -m
        y: -m
        width: root.width + m * 2
        height: root.height + m * 2
        fragmentShader: Qt.resolvedUrl("shaders/pane.v3.frag.qsb")
        property vector4d tint: Qt.vector4d(root.fill.r, root.fill.g, root.fill.b, root.tintStrength)
        property vector2d size: Qt.vector2d(width, height)
        property real margin: m
        property real radius: Math.min(root.radius, root.height / 2)
    }
    Item {
        id: inner
        anchors.fill: parent
    }
}
