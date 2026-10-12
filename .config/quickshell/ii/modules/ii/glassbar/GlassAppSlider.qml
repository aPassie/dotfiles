import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.services

// One app's volume: its icon (click to mute just this app), a thin slider, and the percentage.
Item {
    id: root
    required property PwNode node
    width: parent ? parent.width : 280
    height: 30

    PwObjectTracker { objects: [root.node] }
    readonly property real volume: root.node?.audio?.volume ?? 0
    readonly property bool muted: root.node?.audio?.muted ?? false

    MouseArea {
        id: iconArea
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        onClicked: if (root.node?.audio) root.node.audio.muted = !root.node.audio.muted
        IconImage {
            anchors.fill: parent
            opacity: root.muted ? 0.35 : 1
            source: {
                let icon = AppSearch.guessIcon(root.node?.properties["application.icon-name"] ?? "")
                if (!AppSearch.iconExists(icon)) icon = AppSearch.guessIcon(root.node?.properties["application.name"] ?? "")
                if (!AppSearch.iconExists(icon)) icon = AppSearch.guessIcon(root.node?.properties["node.name"] ?? "")
                return Quickshell.iconPath(icon, "audio-x-generic")
            }
        }
    }
    Item {
        id: track
        anchors.left: iconArea.right
        anchors.leftMargin: 10
        anchors.right: pct.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 16
        readonly property real shown: drag.pressed ? drag.live : Math.min(root.volume, 1)
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.2) }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * track.shown; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, root.muted ? 0.4 : 1) }
        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -6
            property real live: 0
            function at(x) { return Math.min(Math.max((x - 6) / track.width, 0), 1) }
            function put(v) { if (root.node?.audio) root.node.audio.volume = v }
            onPressed: (e) => { live = at(e.x); put(live) }
            onPositionChanged: (e) => { if (pressed) { live = at(e.x); put(live) } }
            onWheel: (e) => put(Math.min(Math.max(root.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05), 0), 1))
        }
    }
    GlassText {
        id: pct
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        color: Qt.rgba(1, 1, 1, 0.75)
        font.pixelSize: 11
        font.weight: Font.Normal
        text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
    }
}
