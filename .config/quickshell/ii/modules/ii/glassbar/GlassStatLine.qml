import QtQuick

// "Label ........ value" line used inside the hover pop-ups
Item {
    id: root
    property string label: ""
    property string value: ""
    property color valueColor: "white"
    width: parent ? parent.width : 240
    height: 22
    GlassText { anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.7); font.weight: Font.Normal; text: root.label }
    GlassText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; color: root.valueColor; font.weight: Font.DemiBold; text: root.value }
}
