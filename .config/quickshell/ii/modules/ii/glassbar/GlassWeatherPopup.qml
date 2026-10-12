pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.ii.bar

// Weather: place, temperature and feels-like, then eight readings in a grid.
StyledPopup {
    id: root
    peekName: "weather"

    Column {
        id: col
        anchors.centerIn: parent
        width: 280
        spacing: 8

        GlassText {
            width: col.width
            color: Qt.rgba(1, 1, 1, 0.7)
            font.pixelSize: 12
            font.weight: Font.Normal
            text: Weather.data.city || Translation.tr("Weather")
        }
        Item {
            width: col.width
            height: 38
            GlassText { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 30; font.weight: Font.DemiBold; text: Weather.data.temp }
            GlassText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.7)
                font.weight: Font.Normal
                text: Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
            }
        }
        Grid {
            columns: 2
            spacing: 6
            Repeater {
                model: [
                    { k: Translation.tr("UV index"), v: Weather.data.uv },
                    { k: Translation.tr("Wind"), v: `${Weather.data.wind} ${Weather.data.windDir}`.trim() },
                    { k: Translation.tr("Precipitation"), v: Weather.data.precip },
                    { k: Translation.tr("Humidity"), v: Weather.data.humidity },
                    { k: Translation.tr("Visibility"), v: Weather.data.visib },
                    { k: Translation.tr("Pressure"), v: Weather.data.press },
                    { k: Translation.tr("Sunrise"), v: Weather.data.sunrise },
                    { k: Translation.tr("Sunset"), v: Weather.data.sunset }
                ]
                Rectangle {
                    id: tile
                    required property var modelData
                    width: (col.width - 6) / 2
                    height: 46
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Column {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20
                        GlassText { width: parent.width; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.weight: Font.Normal; text: tile.modelData.k }
                        GlassText { width: parent.width; font.weight: Font.DemiBold; text: tile.modelData.v }
                    }
                }
            }
        }
        GlassText {
            width: col.width
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 11
            font.weight: Font.Normal
            text: Translation.tr("Updated %1 · right-click the weather to refresh").arg(Weather.data.lastRefresh)
        }
    }
}
