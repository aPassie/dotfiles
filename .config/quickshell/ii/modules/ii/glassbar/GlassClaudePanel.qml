pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// Every Claude Code session: folder, what it is doing, for how long. Opens when the pointer
// rests on the Claude island; a row jumps to that session's terminal.
GlassPanel {
    id: root
    name: "claude"
    panelWidth: 300
    anchorRight: GlassPanels.claudeRight

    body: Column {
        id: col
        spacing: 0
        property double now: Date.now() / 1000
        Timer { interval: 1000; repeat: true; running: true; onTriggered: col.now = Date.now() / 1000 }
        function ago(t) {
            const s = Math.max(0, Math.round(col.now - t))
            return s < 60 ? `${s} s` : s < 3600 ? `${Math.floor(s / 60)} min` : `${Math.floor(s / 3600)} h`
        }

        Repeater {
            model: ScriptModel { values: ClaudeStatus.sessions; objectProp: "session" }
            MouseArea {
                id: row
                required property var modelData
                readonly property string kind: ClaudeStatus.shown(modelData)
                width: col.width
                height: 44
                hoverEnabled: true
                onClicked: { ClaudeStatus.focus(modelData); GlassPanels.close() }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(1, 1, 1, row.containsMouse ? 0.1 : 0)
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Rectangle {
                    id: pip
                    x: 11
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: row.kind === "asking" ? "#ffb224" : row.kind === "done" ? "#6ee7a0" : Qt.rgba(1, 1, 1, row.kind === "working" ? 0.75 : 0.35)
                }
                Column {
                    anchors.left: pip.right
                    anchors.leftMargin: 11
                    anchors.right: when.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    GlassText { width: parent.width; text: row.modelData.dir }
                    GlassText {
                        width: parent.width
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        text: row.kind === "working" ? "Working"
                            : row.kind === "idle" ? (row.modelData.state === "done" ? row.modelData.detail : "Waiting for you")
                            : (row.modelData.detail || (row.kind === "asking" ? "Needs your answer" : "Finished"))
                    }
                }
                GlassText {
                    id: when
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    // counts up only while something is going on; a finished session shows when it finished
                    text: row.modelData.state === "working" || row.modelData.state === "asking"
                        ? col.ago(row.modelData.since)
                        : Qt.formatTime(new Date(row.modelData.since * 1000), "h:mm AP")
                }
            }
        }
    }
}
