pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common

GlassPanel {
    id: root
    name: "notifications"
    panelWidth: 320

    onWantedChanged: if (wanted) Notifications.markAllRead()

    property int tick: 0 // bumps every half minute so the "2 min" labels stay current
    Timer { interval: 30000; repeat: true; running: root.wanted; onTriggered: root.tick++ }

    function age(ms) {
        root.tick
        const m = Math.max(0, Math.round((Date.now() - ms) / 60000))
        if (m < 1) return Translation.tr("now")
        if (m < 60) return m + " min"
        const h = Math.round(m / 60)
        return h < 24 ? h + " h" : Math.round(h / 24) + " d"
    }

    body: Column {
        id: col
        spacing: 0
        readonly property var items: Notifications.list.slice().reverse() // newest first
        property int menuFor: -1 // id of the notification whose menu is open

        Item { // header
            width: col.width
            height: 32
            GlassText { x: 6; anchors.verticalCenter: parent.verticalCenter; text: Translation.tr("Notifications"); font.pixelSize: 14; font.weight: Font.DemiBold }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                GlassText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translation.tr("Do not disturb")
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 11
                    font.weight: Font.Normal
                }
                GlassSwitch { checked: Notifications.silent; onToggled: Notifications.silent = !Notifications.silent }
            }
        }

        GlassText {
            visible: col.items.length === 0
            width: col.width
            height: 54
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.rgba(1, 1, 1, 0.7)
            font.weight: Font.Normal
            text: Translation.tr("No notifications")
        }

        Flickable { // scrolls once there are more than fit
            visible: col.items.length > 0
            width: col.width
            height: Math.min(cards.height, 380)
            contentHeight: cards.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: cards
                width: parent.width
                spacing: 6

                Repeater {
                    model: ScriptModel { values: col.items }

                    MouseArea {
                        id: card
                        required property var modelData
                        width: cards.width
                        height: inner.height + 18
                        hoverEnabled: true
                        // right-click or double-tap: dismiss this one, or everything from the same app
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        function askMenu() { col.menuFor = (col.menuFor === modelData.notificationId ? -1 : modelData.notificationId) }
                        onClicked: (mouse) => { if (mouse.button === Qt.RightButton) askMenu() }
                        onDoubleClicked: (mouse) => { if (mouse.button === Qt.LeftButton) askMenu() }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: Qt.rgba(1, 1, 1, card.containsMouse ? 0.14 : 0.10)
                        }
                        IconImage {
                            id: appIcon
                            x: 10
                            y: 10
                            implicitSize: 30
                            source: Quickshell.iconPath(AppSearch.guessIcon(card.modelData.appIcon || card.modelData.appName), "dialog-information")
                        }
                        Column {
                            id: inner
                            x: 50
                            y: 9
                            width: parent.width - 60
                            spacing: 1

                            Item {
                                width: parent.width
                                height: 17
                                GlassText {
                                    width: parent.width - when.width - 8
                                    font.weight: Font.DemiBold
                                    text: card.modelData.summary || card.modelData.appName
                                }
                                GlassText {
                                    id: when
                                    anchors.right: parent.right
                                    visible: !card.containsMouse
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.pixelSize: 11
                                    font.weight: Font.Normal
                                    text: root.age(card.modelData.time)
                                }
                                MouseArea { // dismiss this one
                                    visible: card.containsMouse
                                    anchors.right: parent.right
                                    width: 18
                                    height: 18
                                    onClicked: Notifications.discardNotification(card.modelData.notificationId)
                                    Text {
                                        anchors.centerIn: parent
                                        text: String.fromCodePoint(GlassPanels.sf.xmark)
                                        color: "white"
                                        font.family: GlassPanels.symbols
                                        font.pixelSize: 10
                                    }
                                }
                            }
                            GlassText {
                                visible: text.length > 0
                                width: parent.width
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                textFormat: Text.PlainText
                                color: Qt.rgba(1, 1, 1, 0.78)
                                font.pixelSize: 12
                                font.weight: Font.Normal
                                text: card.modelData.body
                            }
                            GlassActions {
                                inset: 0
                                open: col.menuFor === card.modelData.notificationId
                                actions: [
                                    { label: Translation.tr("Dismiss"), run: () => { col.menuFor = -1; Notifications.discardNotification(card.modelData.notificationId) } },
                                    { label: Translation.tr("Dismiss all from %1").arg(card.modelData.appName || Translation.tr("this app")), danger: true,
                                      run: () => {
                                          const app = card.modelData.appName
                                          col.menuFor = -1
                                          Notifications.list.filter(n => n.appName === app).map(n => n.notificationId).forEach(id => Notifications.discardNotification(id))
                                      } }
                                ]
                            }
                            Row {
                                visible: card.modelData.actions.length > 0
                                topPadding: 5
                                spacing: 6
                                Repeater {
                                    model: card.modelData.actions.slice(0, 2)
                                    MouseArea {
                                        id: act
                                        required property var modelData
                                        width: actText.implicitWidth + 20
                                        height: 22
                                        onClicked: Notifications.attemptInvokeAction(card.modelData.notificationId, act.modelData.identifier)
                                        Rectangle { anchors.fill: parent; radius: 10; color: Qt.rgba(1, 1, 1, 0.14) }
                                        GlassText { id: actText; anchors.centerIn: parent; font.pixelSize: 11; text: act.modelData.text }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { // footer
            visible: col.items.length > 0
            width: col.width
            height: 34
            GlassText {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.7)
                font.pixelSize: 12
                font.weight: Font.Normal
                text: col.items.length === 1 ? Translation.tr("1 notification") : Translation.tr("%1 notifications").arg(col.items.length)
            }
            MouseArea {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: clearText.implicitWidth + 22
                height: 22
                onClicked: Notifications.discardAllNotifications()
                Rectangle { anchors.fill: parent; radius: 10; color: Qt.rgba(1, 1, 1, 0.14) }
                GlassText { id: clearText; anchors.centerIn: parent; font.pixelSize: 11; text: Translation.tr("Clear all") }
            }
        }
    }
}
