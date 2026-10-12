pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.modules.common

// The "inside" of a Control Centre control: sound, mic, night, displays, awake or dgpu.
// Shown in place of the controls column, with a back arrow.
GlassPiece {
    id: root

    property string kind: ""
    property var dgpu           // the Control Centre's dGPU switch models
    signal back()

    readonly property var sf: ({
        back: 0x100189, chevron: 0x10018A, check: 0x100185, speaker: 0x1002A9, mic: 0x1002B1,
        laptop: 0x1007DB, headphones: 0x100448, display: 0x1008B9, moon: 0x1001BA, sun: 0x1001AE,
        clock: 0x1001A7, cpu: 0x100AE5, layout: 0x100685, minus: 0x10017D, plus: 0x10017C
    })
    readonly property var titles: ({
        sound: Translation.tr("Sound"), mic: Translation.tr("Microphone"), night: Translation.tr("Night Light"),
        displays: Translation.tr("Displays"), awake: Translation.tr("Keep Awake"), dgpu: "NVIDIA dGPU", power: Translation.tr("Power")
    })
    function deviceGlyph(node) {
        const s = ((node?.description ?? "") + " " + (node?.name ?? "")).toLowerCase()
        if (/head|buds|bluez|airpod|ear/.test(s)) return sf.headphones
        if (/hdmi|displayport|monitor/.test(s)) return sf.display
        return node?.isSink ? sf.laptop : sf.mic
    }
    function openMixer() {
        Quickshell.execDetached(["pavucontrol"])
        GlassPanels.close()
    }

    radius: 24
    tintStrength: 0.7
    height: body.height + 20

    Column {
        id: body
        x: 10
        y: 10
        width: root.width - 20
        spacing: 0

        Item { // header: back arrow, title, and the main switch where there is one
            width: body.width
            height: 34
            MouseArea {
                id: backBtn
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                hoverEnabled: true
                onClicked: root.back()
                Rectangle { anchors.fill: parent; radius: 13; color: Qt.rgba(1, 1, 1, backBtn.containsMouse ? 0.26 : 0.14) }
                Text { anchors.centerIn: parent; text: String.fromCodePoint(root.sf.back); color: "white"; font.family: GlassPanels.symbols; font.pixelSize: 11 }
            }
            GlassText { x: 40; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 14; font.weight: Font.DemiBold; text: root.titles[root.kind] ?? "" }
            GlassSwitch {
                visible: root.kind === "mic" || root.kind === "night" || root.kind === "awake"
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                checked: root.kind === "mic" ? !(Audio.source?.audio?.muted ?? true)
                       : root.kind === "night" ? GlassControls.nightOn
                       : Idle.inhibit
                onToggled: {
                    if (root.kind === "mic") Audio.toggleMicMute()
                    else if (root.kind === "night") GlassControls.toggleNight()
                    else if (Idle.inhibit) GlassControls.stopAwake()
                    else GlassControls.keepAwake(GlassControls.awakeChoice)
                }
            }
        }

        Loader {
            width: body.width
            sourceComponent: root.kind === "sound" ? soundBody : root.kind === "mic" ? micBody
                           : root.kind === "night" ? nightBody : root.kind === "displays" ? displaysBody
                           : root.kind === "awake" ? awakeBody : root.kind === "dgpu" ? dgpuBody
                           : root.kind === "power" ? powerBody : null
        }
    }

    // ── Sound ───────────────────────────────────────────────────────────────
    Component {
        id: soundBody
        Column {
            GlassBarSlider {
                glyph: root.sf.speaker
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: (v) => { if (Audio.sink?.audio) Audio.sink.audio.volume = v }
            }
            GlassCaption { text: Translation.tr("Output") }
            Repeater {
                model: ScriptModel { values: Audio.outputDevices }
                GlassRow {
                    required property var modelData
                    readonly property bool current: modelData.id === Pipewire.defaultAudioSink?.id
                    glyph: root.deviceGlyph(modelData)
                    title: Audio.friendlyDeviceName(modelData)
                    selected: current
                    trailingGlyph: current ? root.sf.check : 0
                    onChosen: Audio.setDefaultSink(modelData)
                }
            }
            GlassCaption { text: Translation.tr("Apps") }
            GlassText {
                visible: Audio.outputAppNodes.length === 0
                width: parent.width
                height: 28
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
                color: Qt.rgba(1, 1, 1, 0.7)
                font.weight: Font.Normal
                text: Translation.tr("Nothing is playing")
            }
            Repeater {
                model: ScriptModel { values: Audio.outputAppNodes }
                GlassAppSlider { required property var modelData; node: modelData }
            }
            Rectangle { width: parent.width - 12; x: 6; height: 1; color: Qt.rgba(1, 1, 1, 0.14) }
            GlassRow { height: 34; glyph: root.sf.speaker; title: Translation.tr("Open full mixer"); trailingGlyph: root.sf.chevron; onChosen: root.openMixer() }
        }
    }

    // ── Microphone ──────────────────────────────────────────────────────────
    Component {
        id: micBody
        Column {
            GlassBarSlider {
                glyph: root.sf.mic
                value: Audio.source?.audio?.volume ?? 0
                onMoved: (v) => { if (Audio.source?.audio) Audio.source.audio.volume = v }
            }
            GlassCaption { text: Translation.tr("Input") }
            Repeater {
                model: ScriptModel { values: Audio.inputDevices }
                GlassRow {
                    required property var modelData
                    readonly property bool current: modelData.id === Pipewire.defaultAudioSource?.id
                    glyph: root.deviceGlyph(modelData)
                    title: Audio.friendlyDeviceName(modelData)
                    selected: current
                    trailingGlyph: current ? root.sf.check : 0
                    onChosen: Audio.setDefaultSource(modelData)
                }
            }
            GlassCaption { text: Translation.tr("Apps listening") }
            GlassText {
                visible: Audio.inputAppNodes.length === 0
                width: parent.width
                height: 28
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
                color: Qt.rgba(1, 1, 1, 0.7)
                font.weight: Font.Normal
                text: Translation.tr("No app is using the microphone")
            }
            Repeater {
                model: ScriptModel { values: Audio.inputAppNodes }
                GlassAppSlider { required property var modelData; node: modelData }
            }
            Rectangle { width: parent.width - 12; x: 6; height: 1; color: Qt.rgba(1, 1, 1, 0.14) }
            GlassRow { height: 34; glyph: root.sf.mic; title: Translation.tr("Open full mixer"); trailingGlyph: root.sf.chevron; onChosen: root.openMixer() }
        }
    }

    // ── Night Light ─────────────────────────────────────────────────────────
    Component {
        id: nightBody
        Column {
            id: night
            readonly property real span: GlassControls.maxKelvin - GlassControls.minKelvin
            GlassCaption { text: Translation.tr("Warmth · %1 K").arg(GlassControls.temperature) }
            GlassBarSlider {
                glyph: root.sf.sun
                value: (GlassControls.maxKelvin - GlassControls.temperature) / night.span
                onMoved: (v) => GlassControls.setTemperature(GlassControls.maxKelvin - v * night.span)
            }
            GlassCaption { text: Translation.tr("Gamma · %1%").arg(Math.round(GlassControls.gamma * 100)) }
            GlassBarSlider {
                glyph: root.sf.moon
                value: (GlassControls.gamma - 0.5) / 0.5
                onMoved: (v) => GlassControls.setGamma(0.5 + v * 0.5)
            }
            Rectangle { width: parent.width - 12; x: 6; height: 1; color: Qt.rgba(1, 1, 1, 0.14) }
            GlassRow {
                glyph: root.sf.clock
                title: Translation.tr("Automatic")
                subtitle: Translation.tr("%1 to %2").arg(GlassControls.from).arg(GlassControls.to)
                onChosen: GlassControls.setAutomatic(!GlassControls.automatic)
                GlassSwitch { checked: GlassControls.automatic; onToggled: GlassControls.setAutomatic(!GlassControls.automatic) }
            }
            Repeater {
                model: [{ key: "from", label: Translation.tr("Turns on") }, { key: "to", label: Translation.tr("Turns off") }]
                Item {
                    id: timeRow
                    required property var modelData
                    width: night.width
                    height: 30
                    GlassText { x: 8; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.Normal; text: timeRow.modelData.label }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: [{ g: root.sf.minus, d: -30 }, { g: 0, d: 0 }, { g: root.sf.plus, d: 30 }]
                            Item {
                                id: part
                                required property var modelData
                                width: modelData.g === 0 ? 44 : 22
                                height: 22
                                GlassText {
                                    visible: part.modelData.g === 0
                                    anchors.centerIn: parent
                                    font.weight: Font.DemiBold
                                    text: timeRow.modelData.key === "from" ? GlassControls.from : GlassControls.to
                                }
                                MouseArea {
                                    id: step
                                    visible: part.modelData.g !== 0
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: GlassControls.shiftTime(timeRow.modelData.key, part.modelData.d)
                                    Rectangle { anchors.fill: parent; radius: 11; color: Qt.rgba(1, 1, 1, step.containsMouse ? 0.28 : 0.14) }
                                    Text { anchors.centerIn: parent; text: part.modelData.g ? String.fromCodePoint(part.modelData.g) : ""; color: "white"; font.family: GlassPanels.symbols; font.pixelSize: 9 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Displays ────────────────────────────────────────────────────────────
    Component {
        id: displaysBody
        Column {
            Component.onCompleted: Displays.refresh()
            GlassCaption { text: Displays.busy ? Translation.tr("Switching…") : Translation.tr("Mode") }
            GlassSegments {
                usable: !Displays.busy
                current: Displays.mode
                options: [{ label: Translation.tr("Extend"), value: "extend" }, { label: Translation.tr("Laptop only"), value: "internal" }, { label: Translation.tr("External only"), value: "external" }]
                onPicked: (v) => Displays.setMode(v, Displays.arrangement)
            }
            GlassCaption { text: Translation.tr("External screen sits") }
            GlassSegments {
                usable: !Displays.busy
                current: Displays.arrangement
                options: [{ label: Translation.tr("Left"), value: "left" }, { label: Translation.tr("Right"), value: "right" }, { label: Translation.tr("Above"), value: "above" }, { label: Translation.tr("Below"), value: "below" }]
                onPicked: (v) => Displays.setArrangement(v)
            }
            Item { width: 1; height: 4 }
            GlassRow {
                glyph: root.sf.laptop
                title: Translation.tr("Laptop")
                subtitle: Displays.internalOn ? Translation.tr("On · %1").arg(Displays.internalName) : Translation.tr("Off")
                selected: Displays.internalOn
            }
            GlassRow {
                glyph: root.sf.display
                title: Translation.tr("External")
                subtitle: (!Displays.externalPresent ? Translation.tr("Not connected")
                        : Displays.externalOn ? Translation.tr("On · %1").arg(Displays.externalName) : Translation.tr("Connected, off"))
                        + (Displays.dgpuMode === "display" ? " · " + Translation.tr("driven by the dGPU") : "")
                selected: Displays.externalOn
            }
            GlassText {
                width: parent.width
                leftPadding: 8
                rightPadding: 8
                topPadding: 4
                bottomPadding: 6
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                color: Qt.rgba(1, 1, 1, 0.66)
                font.pixelSize: 11
                font.weight: Font.Normal
                text: Translation.tr("niri cannot mirror screens, so there is no duplicate mode. External only lasts until you log out.")
            }
            Rectangle { width: parent.width - 12; x: 6; height: 1; color: Qt.rgba(1, 1, 1, 0.14) }
            GlassRow {
                height: 34
                glyph: root.sf.display
                title: Translation.tr("Placement, resolution, refresh rate")
                trailingGlyph: root.sf.chevron
                onChosen: { Quickshell.execDetached(["nwg-displays"]); GlassPanels.close() }
            }
        }
    }

    // ── Keep Awake ──────────────────────────────────────────────────────────
    Component {
        id: awakeBody
        Column {
            GlassCaption { text: Translation.tr("Stay awake for") }
            GlassSegments {
                current: GlassControls.awakeChoice
                options: [{ label: "30 min", value: 30 }, { label: "1 h", value: 60 }, { label: "2 h", value: 120 }, { label: Translation.tr("Until off"), value: 0 }]
                onPicked: (v) => GlassControls.keepAwake(v)
            }
            GlassText {
                width: parent.width
                leftPadding: 8
                rightPadding: 8
                topPadding: 6
                bottomPadding: 4
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                color: Qt.rgba(1, 1, 1, 0.66)
                font.pixelSize: 11
                font.weight: Font.Normal
                text: !Idle.inhibit ? Translation.tr("Off. Choosing a time switches it on.")
                    : GlassControls.awakeUntil > 0 ? Translation.tr("On. Switches itself off in %1 min.").arg(GlassControls.awakeMinutesLeft)
                    : Translation.tr("On until you switch it off. The screen will not dim or lock and the laptop will not sleep.")
            }
        }
    }

    // ── Power menu ──────────────────────────────────────────────────────────
    Component {
        id: powerBody
        Column {
            id: power
            property string armed: "" // the action waiting for its "are you sure"
            Repeater {
                model: [
                    { key: "lock", label: Translation.tr("Lock"), glyph: 0x1003A1, ask: false },
                    { key: "sleep", label: Translation.tr("Sleep"), glyph: 0x1001BA, ask: false },
                    { key: "hibernate", label: Translation.tr("Hibernate"), glyph: 0x1001BA, ask: true },
                    { key: "logout", label: Translation.tr("Log out"), glyph: 0x100189, ask: true },
                    { key: "restart", label: Translation.tr("Restart"), glyph: 0x100148, ask: true },
                    { key: "shutdown", label: Translation.tr("Shut down"), glyph: 0x1001A8, ask: true },
                    { key: "firmware", label: Translation.tr("Restart to firmware settings"), glyph: 0x1008CB, ask: true },
                    { key: "-" },
                    { key: "reload", label: Translation.tr("Reload shell and niri"), glyph: 0x100148, ask: false },
                    { key: "tasks", label: Translation.tr("Task manager"), glyph: 0x100AE5, ask: false }
                ]
                Column {
                    id: entry
                    required property var modelData
                    width: power.width
                    function run() {
                        power.armed = ""
                        if (entry.modelData.key !== "reload") GlassPanels.close()
                        GlassControls.session(entry.modelData.key)
                    }
                    Rectangle { visible: entry.modelData.key === "-"; x: 6; width: parent.width - 12; height: 1; color: Qt.rgba(1, 1, 1, 0.14) }
                    GlassRow {
                        visible: entry.modelData.key !== "-"
                        height: visible ? 38 : 0
                        glyph: entry.modelData.glyph ?? 0
                        title: entry.modelData.label ?? ""
                        selected: power.armed === entry.modelData.key
                        onChosen: {
                            if (!entry.modelData.ask) entry.run()
                            else power.armed = (power.armed === entry.modelData.key ? "" : entry.modelData.key)
                        }
                    }
                    GlassActions {
                        open: entry.modelData.key !== "-" && power.armed === entry.modelData.key
                        actions: [
                            { label: Translation.tr("Cancel"), run: () => { power.armed = "" } },
                            { label: entry.modelData.label ?? "", danger: true, run: () => entry.run() }
                        ]
                    }
                }
            }
        }
    }

    // ── dGPU ────────────────────────────────────────────────────────────────
    Component {
        id: dgpuBody
        Column {
            Component.onCompleted: { Displays.refresh(); GlassControls.refreshGpu() }
            Timer { interval: 4000; repeat: true; running: true; onTriggered: GlassControls.refreshGpu() }
            readonly property var modeNames: ({ off: Translation.tr("Powered off"), compute: Translation.tr("On · compute"), display: Translation.tr("On · driving a display"), present: Translation.tr("On · idle") })
            GlassRow {
                glyph: root.sf.cpu
                title: Translation.tr("Compute (CUDA)")
                subtitle: root.dgpu?.statusText ?? ""
                opacity: (root.dgpu?.available ?? false) ? 1 : 0.45
                onChosen: root.dgpu?.mainAction()
                GlassSwitch { checked: root.dgpu?.toggled ?? false; onToggled: root.dgpu?.mainAction() }
            }
            GlassRow { // only while the card is driving the external screen
                visible: Displays.dgpuMode === "display"
                glyph: root.sf.display
                title: Translation.tr("Driving the external screen")
                subtitle: Displays.busy ? Translation.tr("Switching…") : Translation.tr("Release to power the card down")
                MouseArea {
                    id: release
                    width: releaseText.implicitWidth + 20
                    height: 24
                    hoverEnabled: true
                    enabled: !Displays.busy
                    onClicked: Displays.releaseDgpu()
                    Rectangle { anchors.fill: parent; radius: 12; color: Qt.rgba(1, 1, 1, release.containsMouse ? 0.3 : 0.18) }
                    GlassText { id: releaseText; anchors.centerIn: parent; font.pixelSize: 11; text: Translation.tr("Release") }
                }
            }
            Repeater {
                model: [
                    { label: Translation.tr("Card"), value: parent.modeNames[Displays.dgpuMode] ?? Displays.dgpuMode },
                    { label: Translation.tr("Drawing now"), value: Displays.dgpuMode === "off" ? "0 W" : (GlassControls.gpuPower || "…") }
                ]
                Item {
                    id: kv
                    required property var modelData
                    width: parent.width
                    height: 28
                    GlassText { x: 8; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.Normal; text: kv.modelData.label }
                    GlassText { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.DemiBold; text: kv.modelData.value }
                }
            }
            GlassCaption { text: Translation.tr("Using the card") }
            GlassText {
                visible: GlassControls.gpuUsers.length === 0
                width: parent.width
                height: 26
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
                color: Qt.rgba(1, 1, 1, 0.7)
                font.weight: Font.Normal
                text: Displays.dgpuMode === "off" ? Translation.tr("Nothing. The card is off.") : Translation.tr("Nothing right now")
            }
            Repeater {
                model: ScriptModel { values: GlassControls.gpuUsers }
                GlassRow { required property var modelData; height: 32; glyph: root.sf.cpu; title: modelData.name; trailing: modelData.memory }
            }
            GlassText {
                width: parent.width
                leftPadding: 8
                rightPadding: 8
                topPadding: 4
                bottomPadding: 4
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                color: Qt.rgba(1, 1, 1, 0.66)
                font.pixelSize: 11
                font.weight: Font.Normal
                text: Translation.tr("Plugging in an external screen switches the card on by itself, and CUDA then works too. A card that something is using cannot be switched off.")
            }
        }
    }
}
