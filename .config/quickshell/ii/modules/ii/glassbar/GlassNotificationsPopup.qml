pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.ii.bar

// Notifications hover pop-up: how many are unread, the two latest, and Do Not Disturb.
StyledPopup {
    id: root
    peekName: "notifications"

    readonly property var latest: [...Notifications.list].sort((a, b) => b.time - a.time)
    readonly property int total: latest.length
    function age(ms) {
        const m = Math.max(0, Math.round((Date.now() - ms) / 60000))
        if (m < 1) return Translation.tr("now")
        if (m < 60) return m + " min"
        const h = Math.round(m / 60)
        return h < 24 ? h + " h" : Math.round(h / 24) + " d"
    }

    Column {
        id: col
        anchors.centerIn: parent
        width: 290
        spacing: 6

        Item {
            width: col.width
            height: 40
            GlassText {
                anchors.left: parent.left
                anchors.right: side.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 21
                font.weight: Font.DemiBold
                text: Notifications.unread > 0 ? Translation.tr("%1 unread").arg(Notifications.unread)
                    : root.total > 0 ? Translation.tr("%1 notifications").arg(root.total)
                    : Translation.tr("No notifications")
            }
            Column {
                id: side
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.total > 0 || Notifications.silent
                GlassText {
                    anchors.right: parent.right
                    color: Notifications.silent ? "white" : Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: Notifications.silent ? 13 : 12
                    font.weight: Notifications.silent ? Font.DemiBold : Font.Normal
                    text: Notifications.silent ? Translation.tr("Do Not Disturb on") : Translation.tr("Do Not Disturb off")
                }
                GlassText {
                    anchors.right: parent.right
                    visible: Notifications.silent
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    text: Translation.tr("pop-ups are silenced")
                }
            }
        }
        Rectangle {
            visible: root.total > 0
            width: col.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }
        Repeater {
            model: root.latest.slice(0, 2)
            Column {
                id: note
                required property var modelData
                width: col.width
                topPadding: 2
                Item {
                    width: note.width
                    height: 16
                    GlassText {
                        anchors.left: parent.left
                        anchors.right: when.left
                        anchors.rightMargin: 8
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 11
                        font.letterSpacing: 0.7
                        font.capitalization: Font.AllUppercase
                        text: note.modelData.appName
                    }
                    GlassText {
                        id: when
                        anchors.right: parent.right
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 11
                        font.letterSpacing: 0.7
                        font.capitalization: Font.AllUppercase
                        text: root.active ? root.age(note.modelData.time) : ""
                    }
                }
                GlassText {
                    width: note.width
                    textFormat: Text.PlainText
                    text: note.modelData.summary || note.modelData.body
                }
            }
        }
        GlassText {
            visible: root.total > 2
            width: col.width
            horizontalAlignment: Text.AlignHCenter
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 11
            font.weight: Font.Normal
            text: Translation.tr("and %1 more").arg(root.total - 2)
        }
    }
}
