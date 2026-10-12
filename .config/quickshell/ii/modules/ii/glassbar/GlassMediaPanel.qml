pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

// Now-playing panel that drops out of the bar's media island. One row per
// player. Replaces modules/ii/mediaControls and answers the same IPC target name.
Scope {
    id: root

    readonly property var players: GlassMedia.players // most recently un-paused first

    readonly property bool wanted: GlobalStates.mediaControlsOpen
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
            WlrLayershell.namespace: "quickshell:mediaControls"
            WlrLayershell.layer: WlrLayer.Overlay
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

            readonly property color ink: "white"
            readonly property color ink2: Qt.rgba(1, 1, 1, 0.72)
            property bool shown: false
            Component.onCompleted: shown = Qt.binding(() => root.wanted)

            FontLoader {
                id: sfFont
                source: Qt.resolvedUrl("../../../assets/fonts/SF-Pro-Text-Medium.otf")
            }

            // Close when the pointer is on neither the island nor the panel.
            readonly property bool held: cardHover.hovered || GlassBackdrop.mediaIslandHovered
            onHeldChanged: if (held) closeTimer.stop(); else closeTimer.restart()
            Timer {
                id: closeTimer
                interval: 380
                onTriggered: if (!win.held) GlobalStates.mediaControlsOpen = false
            }
            Timer { // opened from the keyboard and never touched
                interval: 2500
                running: true
                onTriggered: if (!win.held) GlobalStates.mediaControlsOpen = false
            }
            Timer { // progress
                interval: 1000
                running: win.shown
                repeat: true
                onTriggered: root.players.forEach(p => { if (p.isPlaying) p.positionChanged() })
            }

            readonly property real glassMargin: 34
            // niri blurs what is behind the card (ext-background-effect). The region follows the
            // card while it scales open.
            Item {
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
                width: 384
                height: Math.max(list.height, 56) + pad * 2
                x: Math.min(Math.max(GlassBackdrop.mediaAnchorRight - width, 8), win.width - width - 8)
                y: root.barH + 6

                // Grows out of the island above it, with a little overshoot, like a macOS popover.
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

                ShaderEffect { // plain see-through tinted glass with a thin bright rim
                    readonly property real m: win.glassMargin
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

                Column {
                    id: list
                    x: card.pad
                    y: card.pad
                    width: card.width - card.pad * 2
                    spacing: 0

                    Repeater {
                        model: ScriptModel { values: root.players }

                        Item {
                            id: row
                            required property MprisPlayer modelData
                            required property int index
                            readonly property MprisPlayer player: modelData
                            // Live streams report nonsense lengths; treat anything over a day as endless.
                            readonly property bool timed: player.length > 0 && player.length < 86400
                            readonly property bool live: !timed && player.isPlaying
                            width: list.width
                            height: 98

                            Rectangle { // divider between players
                                visible: row.index > 0
                                width: parent.width - 12
                                x: 6
                                height: 1
                                color: Qt.rgba(1, 1, 1, 0.14)
                            }

                            Rectangle { // soft shadow under the artwork
                                x: art.x + 2
                                y: art.y + 5
                                width: art.width - 4
                                height: art.height - 2
                                radius: 14
                                color: Qt.rgba(0, 0, 0, 0.28)
                            }
                            ClippingRectangle {
                                id: art
                                x: 6
                                y: 10
                                width: 54
                                height: 54
                                radius: 13
                                color: Qt.rgba(1, 1, 1, 0.10)
                                Image {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    visible: cover.status !== Image.Ready
                                    source: Qt.resolvedUrl("../../../assets/icons/glassbar/music.svg")
                                    sourceSize: Qt.size(44, 44)
                                }
                                Image {
                                    id: cover
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize: Qt.size(160, 160)
                                    source: row.player.trackArtUrl ?? ""
                                }
                            }
                            Rectangle { // hairline of light around the artwork
                                anchors.fill: art
                                radius: art.radius
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.18)
                            }

                            Column {
                                anchors.left: art.right
                                anchors.leftMargin: 13
                                anchors.right: controls.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: art.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    color: win.ink
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    text: StringUtils.cleanMusicTitle(row.player.trackTitle) || Translation.tr("Unknown")
                                }
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    color: win.ink2
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 12
                                    text: row.player.trackArtist || row.player.identity || ""
                                }
                            }

                            Row {
                                id: controls
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: art.verticalCenter
                                spacing: 3

                                component Key: MouseArea {
                                    id: key
                                    property int code
                                    property bool usable: true
                                    property bool primary: false
                                    width: primary ? 38 : 30
                                    height: width
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    hoverEnabled: true
                                    enabled: usable
                                    opacity: usable ? 1 : 0.3
                                    scale: pressed ? 0.86 : (containsMouse ? 1.06 : 1)
                                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.4; mass: 0.4 } }
                                    Rectangle { // the main button sits in its own bead of glass
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: Qt.rgba(1, 1, 1, key.primary ? (key.containsMouse ? 0.26 : 0.16) : (key.containsMouse ? 0.14 : 0))
                                        border.width: key.primary ? 1 : 0
                                        border.color: Qt.rgba(1, 1, 1, 0.22)
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: key.primary && !row.player.isPlaying ? 1 : 0
                                        text: String.fromCodePoint(key.code)
                                        color: win.ink
                                        font.family: sfFont.name
                                        font.pixelSize: key.primary ? 16 : 13
                                    }
                                }
                                Key { code: 0x10028A; usable: row.player.canGoPrevious; onClicked: row.player.previous() }
                                Key { code: row.player.isPlaying ? 0x100286 : 0x100284; primary: true; usable: row.player.canTogglePlaying; onClicked: row.player.togglePlaying() }
                                Key { code: 0x10028C; usable: row.player.canGoNext; onClicked: row.player.next() }
                            }

                            // Scrubber: elapsed, bar, remaining. Streams get a LIVE badge instead.
                            Item {
                                x: 6
                                y: 74
                                width: parent.width - 12
                                height: 14

                                Text {
                                    color: win.ink2
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 11
                                    id: elapsed
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: row.timed
                                    text: StringUtils.friendlyTimeForSeconds(row.player.position)
                                }
                                Text {
                                    color: win.ink2
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 11
                                    id: remaining
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: row.timed
                                    anchors.right: parent.right
                                    text: "-" + StringUtils.friendlyTimeForSeconds(Math.max(row.player.length - row.player.position, 0))
                                }
                                Rectangle {
                                    visible: row.timed
                                    anchors.left: elapsed.right
                                    anchors.leftMargin: 9
                                    anchors.right: remaining.left
                                    anchors.rightMargin: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.20)
                                    Rectangle {
                                        width: Math.max(parent.width * Math.min(Math.max(row.player.position / row.player.length, 0), 1), height)
                                        height: parent.height
                                        radius: 2
                                        color: win.ink
                                    }
                                }
                                Row {
                                    visible: row.live
                                    spacing: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle { width: 7; height: 7; radius: 3.5; color: "#ff453a"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { font.family: Appearance.font.family.main; font.pixelSize: 11; color: "white"; font.weight: Font.DemiBold; font.letterSpacing: 0.8; text: Translation.tr("LIVE") }
                                }
                                Text {
                                    color: win.ink2
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !row.timed && !row.live
                                    text: Translation.tr("Paused")
                                }
                            }
                        }
                    }

                    Text { // nothing to show
                        visible: root.players.length === 0
                        width: list.width
                        height: 56
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: win.ink2
                        font.family: Appearance.font.family.main
                        font.pixelSize: 13
                        text: Translation.tr("Nothing is playing")
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "mediaControls"

        function toggle(): void {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
        }

        function close(): void {
            GlobalStates.mediaControlsOpen = false
        }

        function open(): void {
            GlobalStates.mediaControlsOpen = true
        }
    }
}
// 
