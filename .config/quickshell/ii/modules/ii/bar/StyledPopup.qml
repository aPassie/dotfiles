import qs.modules.common
import qs.services
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property bool pinned: false // keep open regardless of hover (e.g. click-to-expand)

    property string peekName: "" // lets `glassPanels peek <name>` hold this pop-up open
    active: (hoverTarget && hoverTarget.containsMouse) || pinned || (peekName.length > 0 && GlassPanels.peek === peekName)

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        // Glass popup: see-through tinted pane with a thin bright rim; niri blurs what is behind it.
        readonly property real gm: 26       // room around the pane for its shadow
        readonly property real pad: 12
        readonly property real corner: 20

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + gm * 2
        implicitHeight: popupBackground.implicitHeight + gm * 2

        mask: Region {
            item: popupBackground
        }
        BackgroundEffect.blurRegion: Region {
            item: popupBackground
            radius: popupWindow.corner
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (!Config.options.bar.vertical) return Math.max(8 - gm, root.QsWindow?.mapFromItem(
                    root.hoverTarget,
                    (root.hoverTarget.width - popupBackground.implicitWidth) / 2, 0
                ).x - gm);
                return Appearance.sizes.verticalBarWidth
            }
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight + 6 - gm;
                return root.QsWindow?.mapFromItem(
                    root.hoverTarget,
                    (root.hoverTarget.height - popupBackground.implicitHeight) / 2, 0
                ).y;
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        ShaderEffect {
            anchors.fill: parent
            fragmentShader: Qt.resolvedUrl("../glassbar/shaders/pane.v3.frag.qsb")
            property vector4d tint: Qt.vector4d(GlassBackdrop.tint.r, GlassBackdrop.tint.g, GlassBackdrop.tint.b, 0.66)
            property vector2d size: Qt.vector2d(width, height)
            property real margin: popupWindow.gm
            property real radius: popupWindow.corner
        }

        Item {
            id: popupBackground
            x: popupWindow.gm
            y: popupWindow.gm
            implicitWidth: root.contentItem.implicitWidth + popupWindow.pad * 2
            implicitHeight: root.contentItem.implicitHeight + popupWindow.pad * 2
            width: implicitWidth
            height: implicitHeight
            children: [root.contentItem]
        }
    }
}
