import QtQuick
import qs.services

// Put inside a bar icon: after the pointer has rested on it for a moment, `containsMouse` turns
// true (what StyledPopup watches). Never while one of the drop panels is open.
Item {
    id: root
    anchors.fill: parent
    anchors.margins: -6
    property bool containsMouse: false
    readonly property alias hovered: hover.hovered
    readonly property bool wanted: hover.hovered && GlassPanels.open.length === 0
    onWantedChanged: {
        if (wanted) {
            rest.restart()
        } else {
            rest.stop()
            containsMouse = false
        }
    }
    Timer { id: rest; interval: 220; onTriggered: root.containsMouse = root.wanted }
    HoverHandler { id: hover }
}
