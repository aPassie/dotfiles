import QtQuick
import qs.services

// One capsule of clear glass. It draws its own refraction of the wallpaper
// strip behind the bar, so it needs to know where it sits inside the band.
Item {
    id: root

    required property Item backdrop      // texture of the wallpaper strip
    required property real bandWidth
    required property real bandHeight
    property real offsetX: x + (parent ? parent.x : 0)
    property real offsetY: y + (parent ? parent.y : 0)
    property real radius: height / 2
    default property alias content: inner.data

    implicitHeight: 32

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/island.v3.frag.qsb")
        property var source: root.backdrop
        property vector4d tint: Qt.vector4d(GlassBackdrop.tint.r, GlassBackdrop.tint.g, GlassBackdrop.tint.b, GlassBackdrop.tintStrength)
        property vector2d size: Qt.vector2d(width, height)
        property vector2d pos: Qt.vector2d(root.offsetX, root.offsetY)
        property vector2d bandSize: Qt.vector2d(root.bandWidth, root.bandHeight)
        property real radius: root.radius
        property real bezel: 12
        property real strength: 16
        property real fill: 0.055
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
