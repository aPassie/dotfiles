pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.ii.bar

// Memory, swap and processor: percentage, a level bar, and used / free / total.
StyledPopup {
    id: root
    peekName: "monitor"

    function gb(kb) { return (kb / (1024 * 1024)).toFixed(1) + " GB" }

    Column {
        id: col
        anchors.centerIn: parent
        width: 260
        spacing: 12

        Repeater {
            model: [
                { title: Translation.tr("Memory"), show: true, frac: ResourceUsage.memoryUsedPercentage,
                  used: ResourceUsage.memoryUsed, free: ResourceUsage.memoryFree, total: ResourceUsage.memoryTotal },
                { title: Translation.tr("Swap"), show: ResourceUsage.swapTotal > 0, frac: ResourceUsage.swapUsedPercentage,
                  used: ResourceUsage.swapUsed, free: ResourceUsage.swapFree, total: ResourceUsage.swapTotal }
            ]
            Column {
                id: block
                required property var modelData
                visible: modelData.show
                width: col.width
                spacing: 5
                Item {
                    width: parent.width
                    height: 20
                    GlassText { anchors.verticalCenter: parent.verticalCenter; font.weight: Font.DemiBold; text: block.modelData.title }
                    GlassText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 15; font.weight: Font.DemiBold; text: Math.round(block.modelData.frac * 100) + "%" }
                }
                GlassMeter { value: block.modelData.frac; fill: block.modelData.frac > 0.9 ? "#ff453a" : "white" }
                Row {
                    width: parent.width
                    Repeater {
                        model: [
                            { k: Translation.tr("Used"), v: block.modelData.used },
                            { k: Translation.tr("Free"), v: block.modelData.free },
                            { k: Translation.tr("Total"), v: block.modelData.total }
                        ]
                        Column {
                            id: cell
                            required property var modelData
                            width: block.width / 3
                            GlassText { color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.weight: Font.Normal; text: cell.modelData.k }
                            GlassText { font.pixelSize: 12; text: root.gb(cell.modelData.v) }
                        }
                    }
                }
            }
        }

        Column {
            width: col.width
            spacing: 5
            Item {
                width: parent.width
                height: 20
                GlassText { anchors.verticalCenter: parent.verticalCenter; font.weight: Font.DemiBold; text: Translation.tr("Processor") }
                GlassText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 15; font.weight: Font.DemiBold; text: Math.round(ResourceUsage.cpuUsage * 100) + "%" }
            }
            GlassMeter { value: ResourceUsage.cpuUsage; fill: ResourceUsage.cpuUsage > 0.9 ? "#ff453a" : "white" }
            GlassText { color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.weight: Font.Normal; text: Translation.tr("Load across all cores") }
        }
    }
}
