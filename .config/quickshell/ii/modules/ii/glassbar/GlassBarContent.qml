pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.ii.bar

Item {
    id: root

    required property var screen
    required property real barH
    readonly property real hug: Appearance.rounding.screenRounding
    readonly property real bandH: barH + hug
    readonly property real islandH: 26
    readonly property real islandY: (barH - islandH) / 2
    readonly property Item inputRegion: inputArea
    // Touching this loads the service at start-up, so the night-light schedule and its IPC work
    // before the Control Centre has ever been opened.
    readonly property bool nightLightOn: GlassControls.nightOn

    readonly property color ink: "white"
    readonly property color ink2: Qt.rgba(1, 1, 1, 0.74)
    readonly property color hair: Qt.rgba(1, 1, 1, 0.22)
    readonly property color warn: "#ff7a70"
    readonly property string textFont: "Outfit" // his pick for the bar (installed in ~/.local/share/fonts/outfit)

    FontLoader {
        id: sfFont
        source: Qt.resolvedUrl("../../../assets/fonts/SF-Pro-Text-Medium.otf")
    }

    // SF Symbols, by code point (verified against the font)
    readonly property var sf: ({
        wifi: 0x100647, wifiSlash: 0x100648, bell: 0x1002DA, bellSlash: 0x1002DE,
        speakerSlash: 0x1002A3, micSlash: 0x1002B3, memory: 0x100AE6, bolt: 0x1002E6,
        sun: 0x1001AE, cloud: 0x1001C3, cloudSun: 0x1001D5, rain: 0x1001C7,
        fog: 0x1001CB, snow: 0x1001CF, storm: 0x1001DF
    })
    readonly property var weatherGlyph: ({
        clear_day: "sun", partly_cloudy_day: "cloudSun", cloud: "cloud", foggy: "fog", rainy: "rain",
        snowing: "snow", cloudy_snowing: "snow", snowing_heavy: "snow", weather_hail: "snow", thunderstorm: "storm"
    })

    component Label: Text {
        color: root.ink
        font.family: root.textFont
        font.pixelSize: 14
        font.letterSpacing: 0.4
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
    }
    component Glyph: Text { // an SF Symbol
        property int code: 0
        text: String.fromCodePoint(code)
        color: root.ink
        font.family: sfFont.name
        font.pixelSize: 15
        verticalAlignment: Text.AlignVCenter
    }
    component Drawn: Image { // one of the hand-drawn glyphs
        property string name
        source: Qt.resolvedUrl(`../../../assets/icons/glassbar/${name}.svg`)
        sourceSize: Qt.size(36, 36)
        width: 16
        height: 16
    }
    component Hair: Rectangle {
        width: 1
        height: 14
        color: root.hair
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
    component Island: GlassIsland {
        backdrop: stripImage
        bandWidth: root.width
        bandHeight: root.bandH
        height: root.islandH
    }

    // ── Backdrop: the strip of wallpaper that sits behind the bar ──────────
    property int stripRev: 0
    readonly property real dpr: screen?.devicePixelRatio ?? 1
    readonly property string stripBase: `${GlassBackdrop.cacheDir}/strip-${screen?.name ?? "x"}`

    function buildStrip() {
        if (GlassBackdrop.wallpaper.length === 0 || !screen) return
        stripProc.rev = stripRev + 1
        stripProc.running = true
    }
    Process {
        id: stripProc
        property int rev: 0
        command: ["sh", "-c",
            "mkdir -p \"$1\" && rm -f \"$7\"-*.png && magick \"$2\" -resize \"$3x$4^\" -gravity center -extent \"$3x$4\" " +
            "-gravity North -crop \"$3x$5+0+0\" +repage \"$7-$6.png\"",
            "sh", GlassBackdrop.cacheDir, GlassBackdrop.wallpaper,
            Math.round((root.screen?.width ?? 0) * root.dpr), Math.round((root.screen?.height ?? 0) * root.dpr),
            Math.round(root.bandH * root.dpr), rev, root.stripBase]
        onExited: (code) => { if (code === 0) root.stripRev = rev }
    }
    Connections {
        target: GlassBackdrop
        function onRevisionChanged() { root.buildStrip() }
    }
    Component.onCompleted: buildStrip()

    Image {
        id: stripImage
        visible: false
        width: root.width
        height: root.bandH
        cache: false
        asynchronous: true
        source: root.stripRev > 0 ? `file://${root.stripBase}-${root.stripRev}.png` : ""
    }

    ShaderEffect { // tinted band plus the two hug corners
        width: root.width
        height: root.bandH
        fragmentShader: Qt.resolvedUrl("shaders/band.frag.qsb")
        property var source: stripImage
        property vector4d tint: Qt.vector4d(GlassBackdrop.tint.r, GlassBackdrop.tint.g, GlassBackdrop.tint.b, GlassBackdrop.tintStrength)
        property vector2d size: Qt.vector2d(width, height)
        property real barH: root.barH
        property real radius: root.hug
    }

    Item {
        id: inputArea
        width: root.width
        height: root.barH
    }

    // Scroll on the left half for brightness, on the right half for volume
    Item {
        width: root.width / 2
        height: root.barH
        WheelHandler {
            onWheel: (e) => { if (e.angleDelta.y > 0) Brightness.increaseBrightness(); else Brightness.decreaseBrightness() }
        }
    }
    Item {
        x: root.width / 2
        width: root.width / 2
        height: root.barH
        WheelHandler {
            onWheel: (e) => { if (e.angleDelta.y > 0) Audio.incrementVolume(); else Audio.decrementVolume() }
        }
    }

    // ── Far left: workspace ring, focused app and window title ─────────────
    readonly property var outputWorkspaces: Niri.workspacesForOutput(screen?.name ?? "")
    readonly property string activeAppId: Niri.activeWindow?.appId ?? ""
    readonly property string activeTitle: Niri.activeWindow?.title ?? ""

    Row {
        id: leftRow
        x: 18
        height: root.barH
        spacing: 10

        Canvas {
            id: ring
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            property int count: Math.max(root.outputWorkspaces.length, 1)
            property int current: Math.max(root.outputWorkspaces.findIndex(w => w.is_active), 0)
            onCountChanged: requestPaint()
            onCurrentChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const r = 7, c = 2 * Math.PI * r
                const gap = count > 1 ? Math.min(3.4, c / count * 0.32) : 0
                for (let i = 0; i < count; i++) {
                    const a0 = -Math.PI / 2 + i * 2 * Math.PI / count + (gap / 2) / r
                    const a1 = a0 + (c / count - gap) / r
                    ctx.beginPath()
                    ctx.arc(10, 10, r, a0, a1)
                    ctx.lineWidth = i === current ? 3 : 2.2
                    ctx.strokeStyle = i === current ? "#ffffff" : "rgba(255,255,255,0.34)"
                    ctx.stroke()
                }
            }
        }
        Label {
            id: appName
            anchors.verticalCenter: parent.verticalCenter
            font.weight: Font.DemiBold
            text: {
                DesktopEntries.applications.values.length // re-evaluate once desktop entries have loaded
                if (root.activeAppId.length === 0) return Translation.tr("Desktop")
                return (DesktopEntries.byId(root.activeAppId) ?? DesktopEntries.heuristicLookup(root.activeAppId))?.name ?? root.activeAppId
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, 300, root.baseGroupLeft - 24 - x - parent.x))
            elide: Text.ElideRight
            color: root.ink2
            font.weight: Font.Normal
            text: root.activeTitle
        }
    }

    // ── Centre: monitoring + app strip, centred together ───────────────────
    readonly property real centerGap: strip.empty ? 0 : 8
    // Centred while there is room. When the right-hand islands (media player, Claude…) need the
    // space, the group slides left instead of the media player being dropped; it only goes as far
    // as the focused app's name, and the media player hides if even that is not enough.
    readonly property real groupWidth: monIsland.width + centerGap + (strip.empty ? 0 : strip.baseWidth)
    readonly property real rightFixed: 18 + clockMouse.width + wbIsland.width + statusIsland.width + rightRow.spacing * 2
        + (claudeIsland.visible ? claudeIsland.width + rightRow.spacing : 0)
    readonly property real mediaWant: mediaIsland.present ? mediaIsland.width + rightRow.spacing : 0
    readonly property real groupMinLeft: leftRow.x + appName.x + appName.width + 16
    readonly property bool mediaFits: groupMinLeft + groupWidth + 16 + mediaWant + rightFixed <= width
    readonly property real groupTarget: Math.max(groupMinLeft,
        Math.min((width - groupWidth) / 2, width - rightFixed - (mediaFits ? mediaWant : 0) - 16 - groupWidth))
    property real baseGroupLeft: groupTarget
    Behavior on baseGroupLeft { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property real baseAppsLeft: baseGroupLeft + monIsland.width + centerGap

    HoverHandler {
        id: pointer
        onPointChanged: root.updateCursor()
        onHoveredChanged: root.updateCursor()
    }
    function updateCursor() {
        const px = pointer.point.position.x, py = pointer.point.position.y
        const l = appsIsland.offsetX, r = l + appsIsland.width
        strip.cursor = (pointer.hovered && !strip.empty && py <= barH && px >= l && px <= r) ? px - baseAppsLeft : -1
    }

    Row {
        id: centerGroup
        // Keep the point under the pointer still while the strip stretches.
        x: root.baseGroupLeft - (appsIsland.width - strip.baseWidth) * strip.anchorT * (strip.empty ? 0 : 1)
        y: root.islandY
        spacing: root.centerGap

        Island {
            id: monIsland
            width: monRow.implicitWidth + 24

            MouseArea {
                id: monMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                GlassMonitorPopup { hoverTarget: monMouse }
            }
            Row {
                id: monRow
                anchors.centerIn: parent
                height: parent.height
                spacing: 13

                component Stat: Row {
                    property alias value: num.text
                    property color tone: root.ink
                    default property alias icon: slot.data
                    height: parent.height
                    spacing: 6
                    Item { id: slot; width: childrenRect.width; height: parent.height }
                    Label {
                        id: num
                        anchors.verticalCenter: parent.verticalCenter
                        width: numMetrics.width
                        color: parent.tone
                        TextMetrics { id: numMetrics; font: num.font; text: "100%" }
                    }
                }
                Stat {
                    value: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
                    Glyph { code: root.sf.memory; height: parent.height }
                }
                Stat {
                    tone: root.ink2
                    value: Math.round(ResourceUsage.swapUsedPercentage * 100) + "%"
                    Drawn { name: "swap"; opacity: 0.74; anchors.verticalCenter: parent.verticalCenter }
                }
                Stat {
                    value: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                    Drawn { name: "cpu"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        Island {
            id: appsIsland
            visible: !strip.empty
            width: strip.implicitWidth
            Behavior on width { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            AppStrip {
                id: strip
                height: parent.height
                output: root.screen?.name ?? ""
                ink: root.ink
                ink2: root.ink2
                hair: root.hair
            }
        }
    }

    Rectangle { // name of the app under the pointer
        visible: strip.hoveredIndex >= 0
        x: appsIsland.offsetX + strip.hoveredCenter - width / 2
        y: root.barH + 4
        width: appLabel.implicitWidth + 20
        height: 24
        radius: 9
        color: Qt.rgba(GlassBackdrop.tint.r, GlassBackdrop.tint.g, GlassBackdrop.tint.b, 0.86)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        Label {
            id: appLabel
            anchors.centerIn: parent
            font.pixelSize: 12
            text: strip.hoveredLabel
        }
    }

    // ── Right: media, status, weather + battery, then bare date and time ───
    Binding { target: GlassBackdrop; property: "mediaIslandHovered"; value: mediaMouse.containsMouse && mediaIsland.visible }
    Binding { target: GlassBackdrop; property: "mediaAnchorRight"; value: mediaIsland.offsetX + mediaIsland.width } // the media island's own right edge, whatever sits beside it
    Binding { target: GlassPanels; property: "statusRight"; value: statusIsland.offsetX + statusIsland.width }
    Binding { target: GlassPanels; property: "anchorHovered"; value: statusMouse.containsMouse || clockMouse.containsMouse || claudeSense.hovered }
    Binding { target: GlassPanels; property: "claudeRight"; value: claudeIsland.offsetX + claudeIsland.width }
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 18
        height: root.barH
        spacing: 8

        Island { // shown for as long as a player exists (tab open), playing or paused
            id: mediaIsland
            readonly property MprisPlayer player: GlassMedia.current
            readonly property bool present: !!player && (player.trackTitle ?? "").length > 0
            visible: present && root.mediaFits
            anchors.verticalCenter: parent.verticalCenter
            width: mediaRow.implicitWidth + 24

            MouseArea {
                id: mediaMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onEntered: GlobalStates.mediaControlsOpen = true
                onPressed: (event) => {
                    if (event.button === Qt.MiddleButton) mediaIsland.player.togglePlaying()
                    else if (event.button === Qt.RightButton) mediaIsland.player.next()
                    else GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
                }
            }
            Row {
                id: mediaRow
                anchors.centerIn: parent
                height: parent.height
                spacing: 6
                Drawn { name: "music"; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 170)
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(mediaIsland.player?.trackTitle) || ""
                }
                Label {
                    visible: text.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 120)
                    elide: Text.ElideRight
                    color: root.ink2
                    font.weight: Font.Normal
                    text: mediaIsland.player?.trackArtist ?? ""
                }
            }
        }

        Island { // Claude Code: folder and state of the session that most needs him
            id: claudeIsland
            readonly property var session: ClaudeStatus.top
            readonly property string kind: session ? ClaudeStatus.shown(session) : "idle"
            visible: session !== null
            anchors.verticalCenter: parent.verticalCenter
            width: claudeRow.implicitWidth + 22

            Row {
                id: claudeRow
                anchors.centerIn: parent
                height: parent.height
                spacing: 7
                Image { // the Claude mark; deliberately still (animating it cost about 2.4 W)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    sourceSize: Qt.size(48, 48)
                    source: Qt.resolvedUrl("../../../assets/icons/glassbar/claude-mark.svg")
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 150)
                    elide: Text.ElideRight
                    text: claudeIsland.session?.dir ?? ""
                }
                Label {
                    visible: claudeIsland.kind !== "idle"
                    anchors.verticalCenter: parent.verticalCenter
                    text: claudeIsland.kind === "asking" ? "Asking" : claudeIsland.kind === "done" ? "Done" : "Working…"
                    color: claudeIsland.kind === "asking" ? "#ffb224" : claudeIsland.kind === "done" ? "#6ee7a0" : root.ink2
                    font.weight: claudeIsland.kind === "working" ? Font.Normal : Font.Medium
                }
                Label {
                    visible: ClaudeStatus.sessions.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+" + (ClaudeStatus.sessions.length - 1)
                    font.pixelSize: 12
                    opacity: 0.8
                }
            }
            TapHandler { onTapped: { GlassPanels.close(); ClaudeStatus.focus(claudeIsland.session) } }
            GlassHoverSense { // resting on it lists every session
                id: claudeSense
                onContainsMouseChanged: if (containsMouse) GlassPanels.open = "claude"
            }
        }

        Island { // Wi-Fi, Bluetooth, mute indicators, notifications
            id: statusIsland
            anchors.verticalCenter: parent.verticalCenter
            width: statusRow.implicitWidth + 24

            MouseArea { // hover only: keeps an open panel alive while the pointer is on its icon
                id: statusMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
            Row {
                id: statusRow
                anchors.centerIn: parent
                height: parent.height
                spacing: 13

                readonly property bool online: Network.ethernet || (Network.wifiEnabled && Network.wifiStatus === "connected")
                Glyph {
                    height: parent.height
                    font.pixelSize: 15
                    code: statusRow.online ? root.sf.wifi : root.sf.wifiSlash
                    opacity: statusRow.online ? 1 : 0.6
                    scale: wifiSense.hovered ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    TapHandler { margin: 6; onTapped: GlassPanels.toggle("wifi") }
                    GlassHoverSense { id: wifiSense }
                    GlassWifiPopup { hoverTarget: wifiSense }
                }
                Item { // Bluetooth; while a sound device is connected, a headphone or a speaker instead
                    id: btIcon
                    // BlueZ names headsets and headphones "audio-headset" / "audio-headphones"; speakers and
                    // other sound devices come through as "audio-card" (or "audio-speakers")
                    readonly property var icons: BluetoothStatus.connectedDevices.map(d => String(d.icon ?? ""))
                    readonly property bool phonesOn: icons.some(i => /headset|headphone/i.test(i))
                    readonly property bool speakerOn: !phonesOn && icons.some(i => /^audio|speaker/i.test(i))
                    readonly property bool audio: phonesOn || speakerOn
                    width: audio ? phones.implicitWidth : 17.5
                    height: parent.height
                    visible: BluetoothStatus.available
                    opacity: BluetoothStatus.enabled ? 1 : 0.4
                    scale: btSense.hovered ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Drawn {
                        name: "bluetooth"
                        visible: !btIcon.audio
                        width: 17.5
                        height: 17.5
                        anchors.centerIn: parent
                    }
                    Glyph {
                        id: phones
                        visible: btIcon.audio
                        anchors.centerIn: parent
                        height: parent.height
                        font.pixelSize: 14
                        code: btIcon.phonesOn ? 0x100448 : GlassPanels.sf.speaker // SF "headphones" / speaker
                    }
                    TapHandler { margin: 6; onTapped: GlassPanels.toggle("bluetooth") }
                    GlassHoverSense { id: btSense }
                    GlassBluetoothPopup { hoverTarget: btSense }
                }
                Item { // the phone (PhoneLink, ~/phonelink): white when connected, dim when it can be reached over Wi-Fi
                    id: phoneIcon
                    visible: PhoneLink.connected || PhoneLink.wifiReady
                    opacity: PhoneLink.connected ? 1 : 0.4
                    width: phoneRow.implicitWidth
                    height: parent.height
                    scale: phoneSense.hovered ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Row {
                        id: phoneRow
                        height: parent.height
                        spacing: 3
                        Glyph {
                            height: parent.height
                            font.pixelSize: 14
                            code: 0x1007DC // SF "iphone"-style handset
                            color: PhoneLink.call === "ringing" ? "#ffb224" : root.ink
                        }
                        Label {
                            visible: PhoneLink.battery >= 0 && PhoneLink.battery < 20
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0
                            text: PhoneLink.battery + "%"
                        }
                    }
                    TapHandler { margin: 6; onTapped: GlassPanels.toggle("phone") }
                    GlassHoverSense { id: phoneSense }
                    GlassPhonePopup { hoverTarget: phoneSense }
                }
                Glyph {
                    height: parent.height
                    visible: Audio.sink?.audio?.muted ?? false
                    code: root.sf.speakerSlash
                    font.pixelSize: 13
                    color: root.warn
                }
                Glyph {
                    height: parent.height
                    visible: Audio.source?.audio?.muted ?? false
                    code: root.sf.micSlash
                    font.pixelSize: 12
                    color: root.warn
                }
                Item {
                    width: bell.implicitWidth
                    height: parent.height
                    scale: bellSense.hovered ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    TapHandler { margin: 6; onTapped: GlassPanels.toggle("notifications") }
                    GlassHoverSense { id: bellSense }
                    GlassNotificationsPopup { hoverTarget: bellSense }
                    Glyph {
                        id: bell
                        height: parent.height
                        font.pixelSize: 12
                        code: Notifications.silent ? root.sf.bellSlash : root.sf.bell
                    }
                    Rectangle { // unread
                        visible: Notifications.unread > 0
                        x: bell.width - 4
                        y: 5
                        width: 6
                        height: 6
                        radius: 3
                        color: "#ffb224"
                    }
                }
            }
        }

        Island { // weather and battery
            id: wbIsland
            anchors.verticalCenter: parent.verticalCenter
            width: wbRow.implicitWidth + 24
            visible: Config.options.bar.weather.enable || Battery.available

            Row {
                id: wbRow
                anchors.centerIn: parent
                height: parent.height
                spacing: 13

                MouseArea {
                    id: weatherMouse
                    visible: Config.options.bar.weather.enable
                    width: weatherRow.implicitWidth
                    height: parent.height
                    hoverEnabled: true
                    acceptedButtons: Qt.RightButton
                    onPressed: Weather.getData()
                    Row {
                        id: weatherRow
                        height: parent.height
                        spacing: 6
                        Glyph {
                            height: parent.height
                            code: root.sf[root.weatherGlyph[Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"] ?? "cloud"]
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (Weather.data?.temp ?? "--°").replace(/°[CF]$/, "°")
                        }
                    }
                    GlassWeatherPopup { hoverTarget: weatherMouse }
                }

                MouseArea {
                    id: battMouse
                    visible: Battery.available
                    width: 34
                    height: parent.height
                    hoverEnabled: true
                    property bool expanded: false
                    onClicked: expanded = !expanded

                    readonly property int pct: Math.round(Battery.percentage * 100)
                    readonly property bool low: Battery.isLow && !Battery.isCharging
                    readonly property color level: low ? "#ff453a" : Battery.isCharging ? "#30d158" : root.ink
                    readonly property color onLevel: low ? "#ffffff" : Battery.isCharging ? "#06260f" : GlassBackdrop.tint

                    Item {
                        id: batt
                        anchors.verticalCenter: parent.verticalCenter
                        width: 31
                        height: 15.5

                        Rectangle { id: battTrack; anchors.fill: parent; radius: 5.5; color: Qt.rgba(1, 1, 1, 0.36) }
                        Label {
                            id: battNum
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 0.6 // letter spacing adds a gap after the last digit too
                            font.pixelSize: 11
                            font.letterSpacing: 1.2
                            font.weight: Font.Bold
                            text: battMouse.pct
                        }
                        Item { // the charged part, with the number recoloured where it overlaps
                            clip: true
                            width: batt.width * Math.min(Math.max(Battery.percentage, 0), 1)
                            height: batt.height
                            Rectangle { width: batt.width; height: batt.height; radius: 5.5; color: battMouse.level }
                            Label {
                                x: battNum.x
                                y: battNum.y
                                font: battNum.font
                                color: battMouse.onLevel
                                text: battNum.text
                            }
                        }
                        Rectangle {
                            x: batt.width + 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 5.5
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }
                    }
                    GlassBatteryPopup { hoverTarget: battMouse; expanded: battMouse.expanded }
                }
            }
        }

        MouseArea { // bare date and time
            id: clockMouse
            anchors.verticalCenter: parent.verticalCenter
            width: clockRow.implicitWidth + 6
            height: parent.height
            hoverEnabled: true
            onClicked: GlassPanels.toggle("control") // Control Centre, with the day right under the clock
            Row {
                id: clockRow
                anchors.right: parent.right
                height: parent.height
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.ink2
                    font.weight: Font.Normal
                    text: Qt.locale().toString(DateTime.clock.date, "ddd d MMM")
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    font.weight: Font.DemiBold
                    text: DateTime.time
                }
            }
        }
    }
}
