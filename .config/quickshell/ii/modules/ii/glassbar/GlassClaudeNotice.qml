pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// A Claude Code session started asking or finished: a glass notice drops from the Claude
// island for a few seconds. It sits on the overlay layer, so it also shows over a
// full-screen window (where the bar is hidden); there it comes down from the top edge.
Scope {
    id: root

    property var item: null          // what is drawn; kept while the notice slides away
    property bool present: false
    readonly property real barH: Appearance.sizes.baseBarHeight

    Connections {
        target: ClaudeStatus
        function onNoticeSerialChanged() {
            if (!ClaudeStatus.notice || GlobalStates.screenLocked) return
            root.item = ClaudeStatus.notice
            root.present = true
            stay.restart()
        }
    }
    Timer { id: stay; interval: 5000; onTriggered: if (hold.hovered) stay.restart(); else root.present = false }
    onPresentChanged: if (!present) leave.restart()
    Timer { id: leave; interval: 260 }

    PanelWindow {
        id: win
        visible: root.present || leave.running
        screen: Quickshell.screens.find(s => s.name === Niri.focusedMonitor?.name) ?? null

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:glass"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: root.barH + pane.height + 46

        // The focused window covers the whole screen: the bar is hidden, start from the top edge.
        readonly property bool covered: {
            const w = Niri.windows.find(w => w.is_focused)
            const size = w?.layout?.window_size
            return !!size && !!win.screen && size[0] >= win.screen.width && size[1] >= win.screen.height
        }
        property real drop: root.present ? 0 : -(pane.height + pane.y + 10)
        Behavior on drop {
            NumberAnimation { duration: root.present ? 360 : 220; easing.type: root.present ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.8 }
        }
        Item {
            id: shape
            x: pane.x
            y: Math.max(pane.y + win.drop, 0)
            width: pane.width
            height: Math.max(pane.height + Math.min(pane.y + win.drop, 0), 0)
        }
        mask: Region { item: root.present ? shape : null }
        BackgroundEffect.blurRegion: Region { item: shape.height > 30 ? shape : null; radius: 20 }

        GlassPiece {
            id: pane
            readonly property string kind: root.item?.state ?? "done"
            width: 330
            height: Math.max(text.height + 22, 52)
            x: Math.min(Math.max((GlassPanels.claudeRight > 0 ? GlassPanels.claudeRight : win.width - 16) - width, 8), win.width - width - 8)
            y: win.covered ? 8 : root.barH + 6
            radius: 20
            tintStrength: 0.66
            transform: Translate { y: win.drop }
            opacity: root.present ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.present ? 160 : 200 } }

            Image {
                id: mark
                x: 14
                y: 12
                width: 20
                height: 20
                sourceSize: Qt.size(60, 60)
                source: Qt.resolvedUrl("../../../assets/icons/glassbar/claude.svg")
            }
            Column {
                id: text
                anchors.left: mark.right
                anchors.leftMargin: 11
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 11
                spacing: 1
                Item {
                    width: parent.width
                    height: name.implicitHeight
                    GlassText {
                        id: name
                        anchors.left: parent.left
                        anchors.right: word.left
                        anchors.rightMargin: 10
                        text: root.item?.dir ?? ""
                    }
                    GlassText {
                        id: word
                        anchors.right: parent.right
                        text: pane.kind === "asking" ? "Asking" : "Done"
                        color: pane.kind === "asking" ? "#ffb224" : "#6ee7a0"
                    }
                }
                GlassText {
                    width: parent.width
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    text: root.item?.detail || (pane.kind === "asking" ? "Needs your answer" : "Finished")
                }
            }
            HoverHandler { id: hold }
            TapHandler {
                onTapped: {
                    ClaudeStatus.focus(root.item)
                    root.present = false
                }
            }
        }
    }
}
