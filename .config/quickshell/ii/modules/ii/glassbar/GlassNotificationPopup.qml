pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common

// New notifications, as one glass pane under the right end of the bar (same look as the
// notifications panel). Replaces modules/ii/notificationPopup.
Scope {
    id: root

    // newest first, at most four at a time; hidden while the notifications panel is open
    readonly property var live: GlassPanels.open === "notifications" ? [] : Notifications.popupList.slice().reverse().slice(0, 4)
    // What is drawn. It keeps the last notifications for a moment after they go, so the pane
    // can slide back out with its contents still on it.
    property var items: []
    readonly property bool present: live.length > 0 && !GlobalStates.screenLocked
    onLiveChanged: if (live.length > 0) items = live
    onPresentChanged: if (!present) leaveTimer.restart()
    Timer { id: leaveTimer; interval: 260; onTriggered: if (!root.present) root.items = [] }
    readonly property real barH: Appearance.sizes.baseBarHeight
    property int replies: 0 // cards with the reply field open

    PanelWindow {
        id: win
        visible: root.present || leaveTimer.running
        screen: Quickshell.screens.find(s => s.name === Niri.focusedMonitor?.name) ?? null

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:glass"
        WlrLayershell.layer: WlrLayer.Overlay
        // Keys only while a reply is being typed: niri focuses an on-demand surface as soon as it
        // maps, so a plain popup would take focus from the window being worked in.
        WlrLayershell.keyboardFocus: root.replies > 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            right: true
        }
        implicitWidth: 340 + 12 + 34
        implicitHeight: root.barH + pane.height + 46
        // The pane slides in from the right edge. Input and blur follow where it actually is.
        property real slide: root.present ? 0 : pane.width + 30
        Behavior on slide {
            NumberAnimation { duration: root.present ? 380 : 220; easing.type: root.present ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.9 }
        }
        Item {
            id: paneShape
            x: pane.x + win.slide
            y: pane.y
            width: Math.max(pane.width - Math.max(win.slide - 12, 0), 0)
            height: pane.height
        }
        mask: Region { item: root.present ? paneShape : null }
        BackgroundEffect.blurRegion: Region { item: paneShape.width > 30 ? paneShape : null; radius: 22 }

        GlassPiece {
            id: pane
            x: 34
            y: root.barH + 6
            width: 340
            height: list.height + 12
            radius: 22
            tintStrength: 0.66
            transform: Translate { x: win.slide }
            opacity: root.present ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.present ? 160 : 200 } }
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Column {
                id: list
                x: 6
                y: 6
                width: pane.width - 12
                spacing: 0

                Repeater {
                    model: ScriptModel { values: root.items }

                    MouseArea {
                        id: card
                        required property var modelData
                        required property int index
                        width: list.width
                        height: inner.height + 20
                        hoverEnabled: true
                        property real enter: 60
                        transform: Translate { x: card.enter }
                        opacity: 1 - card.enter / 60
                        Component.onCompleted: enter = 0
                        Behavior on enter { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        // click: put it away (it stays in the notifications panel); right-click: dismiss it
                        onClicked: (m) => {
                            if (m.button === Qt.RightButton) Notifications.discardNotification(modelData.notificationId)
                            else Notifications.timeoutNotification(modelData.notificationId)
                        }
                        // pointing at it keeps it on screen
                        onContainsMouseChanged: {
                            if (containsMouse) { leave.stop(); Notifications.cancelTimeout(modelData.notificationId) }
                            else leave.restart()
                        }
                        Timer { id: leave; interval: 2500; onTriggered: if (!card.replying) Notifications.timeoutNotification(card.modelData.notificationId) }
                        property bool replying: false
                        onReplyingChanged: root.replies += replying ? 1 : -1
                        Component.onDestruction: if (replying) root.replies -= 1
                        function send() {
                            const text = field.text.trim()
                            if (text.length === 0) return
                            Notifications.sendReply(modelData.notificationId, text)
                        }

                        Rectangle { // divider between notifications
                            visible: card.index > 0
                            x: 8
                            width: parent.width - 16
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.14)
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 16
                            color: Qt.rgba(1, 1, 1, card.containsMouse ? 0.10 : 0)
                            Behavior on color { ColorAnimation { duration: 110 } }
                        }
                        IconImage {
                            x: 10
                            y: 11
                            implicitSize: 30
                            source: Quickshell.iconPath(AppSearch.guessIcon(card.modelData.appIcon || card.modelData.appName), "dialog-information")
                        }
                        Column {
                            id: inner
                            x: 50
                            y: 10
                            width: parent.width - 62
                            spacing: 1

                            Item {
                                width: parent.width
                                height: 17
                                GlassText {
                                    width: parent.width - 30
                                    font.weight: Font.DemiBold
                                    text: card.modelData.summary || card.modelData.appName
                                }
                                GlassText {
                                    visible: !card.containsMouse
                                    anchors.right: parent.right
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.pixelSize: 11
                                    font.weight: Font.Normal
                                    text: Translation.tr("now")
                                }
                                MouseArea { // dismiss
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
                                maximumLineCount: 3
                                textFormat: Text.PlainText
                                color: Qt.rgba(1, 1, 1, 0.78)
                                font.pixelSize: 12
                                font.weight: Font.Normal
                                text: card.modelData.body
                            }
                            Row {
                                visible: card.modelData.actions.length > 0 || card.modelData.hasReply
                                topPadding: 5
                                spacing: 6
                                MouseArea { // opens the reply field
                                    id: replyBtn
                                    visible: card.modelData.hasReply && !card.replying
                                    width: replyText.implicitWidth + 20
                                    height: 22
                                    hoverEnabled: true
                                    onClicked: { card.replying = true; Notifications.cancelTimeout(card.modelData.notificationId); field.forceActiveFocus() }
                                    Rectangle { anchors.fill: parent; radius: 10; color: Qt.rgba(1, 1, 1, replyBtn.containsMouse ? 0.26 : 0.14) }
                                    GlassText { id: replyText; anchors.centerIn: parent; font.pixelSize: 11; text: Translation.tr("Reply") }
                                }
                                Repeater {
                                    model: card.modelData.actions.slice(0, 3)
                                    MouseArea {
                                        id: act
                                        required property var modelData
                                        width: actText.implicitWidth + 20
                                        height: 22
                                        hoverEnabled: true
                                        onClicked: Notifications.attemptInvokeAction(card.modelData.notificationId, act.modelData.identifier)
                                        Rectangle { anchors.fill: parent; radius: 10; color: Qt.rgba(1, 1, 1, act.containsMouse ? 0.26 : 0.14) }
                                        GlassText { id: actText; anchors.centerIn: parent; font.pixelSize: 11; text: act.modelData.text }
                                    }
                                }
                            }
                            Flow { // suggested replies
                                visible: card.replying && card.modelData.choices.length > 0
                                width: parent.width
                                topPadding: 6
                                spacing: 6
                                Repeater {
                                    model: card.replying ? card.modelData.choices : []
                                    MouseArea {
                                        id: chip
                                        required property var modelData
                                        width: chipText.implicitWidth + 22
                                        height: 26
                                        hoverEnabled: true
                                        onClicked: Notifications.sendReply(card.modelData.notificationId, chip.modelData)
                                        Rectangle { anchors.fill: parent; radius: 13; color: Qt.rgba(1, 1, 1, chip.containsMouse ? 0.24 : 0.13) }
                                        GlassText { id: chipText; anchors.centerIn: parent; font.pixelSize: 11; text: chip.modelData }
                                    }
                                }
                            }
                            Item { // reply field: Enter sends, Esc closes
                                visible: card.replying
                                width: parent.width
                                height: visible ? 42 : 0
                                Rectangle {
                                    y: 6
                                    width: parent.width
                                    height: 34
                                    radius: 17
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, field.activeFocus ? 0.4 : 0.18)
                                    TextInput {
                                        id: field
                                        x: 14
                                        width: parent.width - 52
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "white"
                                        selectionColor: Qt.rgba(1, 1, 1, 0.3)
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: 13
                                        clip: true
                                        Keys.onReturnPressed: card.send()
                                        Keys.onEnterPressed: card.send()
                                        Keys.onEscapePressed: { card.replying = false; text = "" }
                                        GlassText {
                                            visible: field.text.length === 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Qt.rgba(1, 1, 1, 0.45)
                                            font.weight: Font.Normal
                                            text: card.modelData.replyPlaceholder || Translation.tr("Reply…")
                                        }
                                    }
                                    MouseArea {
                                        id: sendBtn
                                        anchors.right: parent.right
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 26; height: 26
                                        onClicked: card.send()
                                        Rectangle { anchors.fill: parent; radius: 13; color: "white"; opacity: field.text.length > 0 ? 1 : 0.4 }
                                        Text { anchors.centerIn: parent; text: "↑"; color: "#1e1a14"; font.pixelSize: 14; font.weight: Font.Bold }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
