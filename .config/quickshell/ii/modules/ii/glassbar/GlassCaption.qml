import QtQuick
import qs.modules.common

// small upper-case section label
Text {
    leftPadding: 8
    topPadding: 8
    bottomPadding: 2
    color: Qt.rgba(1, 1, 1, 0.6)
    font.family: Appearance.font.family.monospace
    font.pixelSize: 10
    font.letterSpacing: 0.9
    font.capitalization: Font.AllUppercase
}
