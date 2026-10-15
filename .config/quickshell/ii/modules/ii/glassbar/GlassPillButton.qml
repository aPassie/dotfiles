import QtQuick

// A rounded button for the glass panels: white when primary, red / green for calls.
MouseArea {
    id: root
    property string label
    property bool primary: false
    property color tint: "transparent"   // a solid colour (call buttons); overrides primary
    height: 38
    hoverEnabled: true
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.tint.a > 0 ? Qt.lighter(root.tint, root.containsMouse ? 1.12 : 1)
             : root.primary ? "white" : Qt.rgba(1, 1, 1, root.containsMouse ? 0.2 : 0.12)
    }
    GlassText {
        anchors.centerIn: parent
        color: root.primary && root.tint.a === 0 ? "#1e1a14" : "white"
        text: root.label
    }
}
