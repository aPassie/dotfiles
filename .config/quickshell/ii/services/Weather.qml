pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool enabled: Config.options?.bar?.weather?.enable ?? false
    readonly property string city: Config.options?.bar?.weather?.city ?? ""
    readonly property bool useUSCS: Config.options?.bar?.weather?.useUSCS ?? false
    readonly property int fetchIntervalMin: Config.options?.bar?.weather?.fetchInterval ?? 10

    property var data: ({
        city: "",
        temp: "--°",
        tempFeelsLike: "--°",
        wCode: "",
        uv: "--",
        windDir: "",
        wind: "--",
        precip: "--",
        humidity: "--",
        visib: "--",
        press: "--",
        sunrise: "--:--",
        sunset: "--:--",
        lastRefresh: "—"
    })

    function getData() {
        if (!root.enabled) return;
        const loc = root.city.length > 0 ? encodeURIComponent(root.city) : "";
        const url = `https://wttr.in/${loc}?format=j1`;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) {
                console.log("[Weather] request failed: " + xhr.status);
                return;
            }
            try {
                root.data = root.mapResponse(JSON.parse(xhr.responseText));
            } catch (e) {
                console.log("[Weather] parse error: " + e);
            }
        };
        try {
            xhr.send();
        } catch (e) {
            console.log("[Weather] send error: " + e);
        }
    }

    function refresh() { root.getData(); }

    function mapResponse(j) {
        const cur = j.current_condition?.[0] ?? {};
        const area = j.nearest_area?.[0] ?? {};
        const today = j.weather?.[0] ?? {};
        const astro = today.astronomy?.[0] ?? {};

        const uscs = root.useUSCS;
        const cityName = root.city.length > 0 ? root.city : (area.areaName?.[0]?.value ?? "");
        const tempUnit = uscs ? "°F" : "°C";
        const tempVal = uscs ? cur.temp_F : cur.temp_C;
        const feelsVal = uscs ? cur.FeelsLikeF : cur.FeelsLikeC;
        const windVal = uscs ? `${cur.windspeedMiles} mph` : `${cur.windspeedKmph} km/h`;
        const precipVal = uscs ? `${cur.precipInches} in` : `${cur.precipMM} mm`;
        const visibVal = uscs ? `${cur.visibilityMiles} mi` : `${cur.visibility} km`;
        const pressVal = uscs ? `${cur.pressureInches} in` : `${cur.pressure} hPa`;

        return {
            city: cityName,
            temp: `${tempVal}${tempUnit}`,
            tempFeelsLike: `${feelsVal}${tempUnit}`,
            wCode: cur.weatherCode ?? "",
            uv: String(cur.uvIndex ?? "--"),
            windDir: cur.winddir16Point ?? "",
            wind: windVal,
            precip: precipVal,
            humidity: `${cur.humidity ?? "--"}%`,
            visib: visibVal,
            press: pressVal,
            sunrise: astro.sunrise ?? "--:--",
            sunset: astro.sunset ?? "--:--",
            lastRefresh: Qt.formatTime(new Date(), "hh:mm")
        };
    }

    Timer {
        interval: Math.max(1, root.fetchIntervalMin) * 60 * 1000
        running: Config.ready && root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.getData()
    }
}
