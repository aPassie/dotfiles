pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// A see-through glass panel that drops out of the bar: tinted, thin bright rim, with niri
// blurring what is behind it. Used for Wi-Fi, Bluetooth and notifications.
Scope {
    id: root

    required property string name          // key in GlassPanels.open
    property real panelWidth: 300
    property real anchorRight: GlassPanels.statusRight
    required property Component body        // the panel's contents; gets `width` set

    readonly property bool wanted: GlassPanels.open === name
    readonly property real barH: Appearance.sizes.baseBarHeight

    Timer { // keep the window alive long enough to play the closing animation
        id: unloadDelay
        interval: 220
    }
    onWantedChanged: if (!wanted) unloadDelay.restart()

    LazyLoader {
        active: root.wanted || unloadDelay.running

        component: PanelWindow {
            id: win

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:glass"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: root.barH + card.height + 60
            // Input area. It must not be the card itself: the card is scaled while it animates open,
            // and the region would be measured at that small size and never grow back, leaving most
            // of the panel dead to the pointer. This plain item always has the card's full size.
            mask: Region { item: hitShape }
            Item {
                id: hitShape
                x: card.x
                y: card.y
                width: card.width
                height: card.height
            }

            property bool shown: false
            Component.onCompleted: shown = Qt.binding(() => root.wanted)

            // Close a moment after the pointer has left both the panel and the icons above it.
            readonly property bool held: cardHover.hovered || GlassPanels.anchorHovered || GlassPanels.pinned
            property bool entered: false
            onHeldChanged: {
                if (held) { entered = true; closeTimer.stop() }
                else if (entered) closeTimer.restart()
            }
            Timer {
                id: closeTimer
                interval: 650
                onTriggered: if (!win.held && root.wanted) GlassPanels.close()
            }
            Timer { // opened and never touched
                interval: 5000
                running: true
                onTriggered: if (!win.entered && !win.held && root.wanted) GlassPanels.close()
            }

            Item { // the area niri blurs; follows the card while it scales open
                id: blurShape
                x: card.x + card.width * (1 - card.scale)
                y: card.y
                width: card.width * card.scale
                height: card.height * card.scale
            }
            BackgroundEffect.blurRegion: Region {
                item: blurShape
                radius: 24 * card.scale
            }

            Item {
                id: card
                readonly property real pad: 10
                width: root.panelWidth
                height: content.height + pad * 2
                x: Math.min(Math.max(root.anchorRight - width, 8), win.width - width - 8)
                y: root.barH + 6
                focus: true
                Keys.onEscapePressed: GlassPanels.close()

                transformOrigin: Item.TopRight
                scale: 0.55
                opacity: 0
                states: State {
                    name: "shown"
                    when: win.shown
                    PropertyChanges { card.scale: 1; card.opacity: 1 }
                }
                transitions: [
                    Transition {
                        to: "shown"
                        SpringAnimation { property: "scale"; spring: 5.2; damping: 0.36; mass: 0.55; epsilon: 0.002 }
                        NumberAnimation { property: "opacity"; duration: 130; easing.type: Easing.OutCubic }
                    },
                    Transition {
                        from: "shown"
                        NumberAnimation { properties: "scale,opacity"; duration: 170; easing.type: Easing.InCubic }
                    }
                ]
                Behavior on height { SpringAnimation { spring: 5; damping: 0.5; mass: 0.6 } }

                // Pointer tracking for "is the pointer on this panel". It sits on top of everything in
                // the card, because rows and buttons underneath would otherwise swallow the hover and
                // the panel would think the pointer had left. It does not block clicks or row hover.
                Item {
                    anchors.fill: parent
                    z: 1000
                    HoverHandler { id: cardHover }
                }

                ShaderEffect {
                    readonly property real m: 34
                    x: -m
                    y: -m
                    width: card.width + m * 2
                    height: card.height + m * 2
                    fragmentShader: Qt.resolvedUrl("shaders/pane.v3.frag.qsb")
                    property vector4d tint: Qt.vector4d(GlassBackdrop.tint.r, GlassBackdrop.tint.g, GlassBackdrop.tint.b, 0.66)
                    property vector2d size: Qt.vector2d(width, height)
                    property real margin: m
                    property real radius: 24
                }

                Loader {
                    id: content
                    x: card.pad
                    y: card.pad
                    width: card.width - card.pad * 2
                    sourceComponent: root.body
                }
            }
        }
    }
}
