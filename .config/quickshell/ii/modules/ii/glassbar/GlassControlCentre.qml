pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles

// Control Centre, macOS 27 style: no backing panel, every control is its own piece of glass.
// Opens from the date and time. The day (calendar, to-do, timer) sits directly under the clock,
// the controls sit to its left.
Scope {
    id: root

    readonly property bool wanted: GlassPanels.open === "control"
    // Kept in GlassPanels so they can also be set over IPC
    readonly property string detail: GlassPanels.controlDetail   // which control's settings are showing
    readonly property string confirm: GlassPanels.controlConfirm // "restart" or "shutdown" while asking
    readonly property real barH: Appearance.sizes.baseBarHeight
    readonly property var sf: ({
        moon: 0x1001BA, cup: 0x100E19, mic: 0x1002B1, micSlash: 0x1002B3, display: 0x1008B9, cpu: 0x100AE5,
        layout: 0x100685, reload: 0x100148, gear: 0x1008CB, lock: 0x1003A1, power: 0x1001A8,
        sunMin: 0x1001AC, sunMax: 0x1001AE, speaker: 0x1002A1, speakerWave: 0x1002A9,
        left: 0x100189, right: 0x10018A, play: 0x100284, pause: 0x100286, plus: 0x10017C, check: 0x100185
    })

    // The same switch logic the sidebar used
    IdleInhibitorToggle { id: keepAwake }
    MicToggle { id: micToggle }
    DisplayModeToggle { id: displayMode }
    DgpuToggle { id: dgpu }

    function state(t) {
        return (t.statusText && t.statusText.length > 0) ? t.statusText : (t.toggled ? Translation.tr("On") : Translation.tr("Off"))
    }

    Timer {
        id: unloadDelay
        interval: 200
    }
    Connections { target: root; function onWantedChanged() { if (!root.wanted) unloadDelay.restart() } }

    LazyLoader {
        active: root.wanted || unloadDelay.running

        component: PanelWindow {
            id: win

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:glass"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: root.barH + Math.max(controls.height, day.height, detailPane.height) + 60
            mask: Region { item: area }
            BackgroundEffect.blurRegion: Region {
                Region { item: root.detail.length === 0 ? cap1 : null; radius: 28 }
                Region { item: root.detail.length === 0 ? cap2 : null; radius: 28 }
                Region { item: root.detail.length === 0 ? cap3 : null; radius: 28 }
                Region { item: root.detail.length === 0 ? cap4 : null; radius: 28 }
                Region { item: root.detail.length === 0 ? cap5 : null; radius: 28 }
                Region { item: root.detail.length === 0 ? bead1 : null; radius: 24 }
                Region { item: root.detail.length === 0 ? bead2 : null; radius: 24 }
                Region { item: root.detail.length === 0 ? bead3 : null; radius: 24 }
                Region { item: root.detail.length === 0 ? bead4 : null; radius: 24 }
                Region { item: root.detail.length === 0 ? upPill : null; radius: 15 }
                Region { item: root.detail.length === 0 ? brightness : null; radius: 24 }
                Region { item: root.detail.length === 0 ? volume : null; radius: 24 }
                Region { item: cal; radius: 24 }
                Region { item: todo; radius: 24 }
                Region { item: timerPiece; radius: 24 }
                Region { item: root.detail.length > 0 ? detailPane : null; radius: 24 }
                Region { item: (root.detail.length === 0 && root.confirm.length > 0) ? confirmPiece : null; radius: 23 }
            }

            property bool shown: false
            Component.onCompleted: shown = Qt.binding(() => root.wanted)

            // "On the Control Centre" means on either column, in the gap between them, or on the clock.
            // The columns need their own handlers: they sit above `area`, so its handler alone goes
            // quiet whenever the pointer is over one of their buttons.
            readonly property bool held: areaHover.hovered || dayHover.hovered || controlsHover.hovered || detailHover.hovered || GlassPanels.anchorHovered
            property bool entered: false
            onHeldChanged: {
                if (held) { entered = true; closeTimer.stop() }
                else if (entered) closeTimer.restart()
            }
            Timer {
                id: closeTimer
                interval: 700
                onTriggered: if (!win.held && root.wanted) GlassPanels.close()
            }
            Timer {
                interval: 6000
                running: true
                onTriggered: if (!win.entered && !win.held && root.wanted) GlassPanels.close()
            }

            Item {
                id: area
                x: controls.x
                y: root.barH
                width: win.width - controls.x
                height: Math.max(controls.height, day.height, detailPane.height) + 16
                opacity: win.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                focus: true
                Keys.onEscapePressed: GlassPanels.close()
                HoverHandler { id: areaHover }
            }

            // ── Day: directly under the date and time ──────────────────────
            Column {
                id: day
                HoverHandler { id: dayHover }
                x: win.width - width - 12
                y: root.barH + 8
                width: 300
                spacing: 10
                opacity: area.opacity
                scale: win.shown ? 1 : 0.94
                transformOrigin: Item.TopRight
                Behavior on scale { SpringAnimation { spring: 5.2; damping: 0.4; mass: 0.5 } }

                GlassPiece { // calendar
                    id: cal
                    width: day.width
                    height: calCol.height + 24
                    property date shownMonth: new Date(DateTime.clock.date.getFullYear(), DateTime.clock.date.getMonth(), 1)
                    readonly property var cells: {
                        const first = new Date(shownMonth.getFullYear(), shownMonth.getMonth(), 1)
                        const lead = (first.getDay() + 6) % 7 // Monday first
                        const out = []
                        for (let i = 0; i < 42; i++) {
                            const d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i)
                            out.push({ day: d.getDate(), inMonth: d.getMonth() === first.getMonth(), today: d.toDateString() === DateTime.clock.date.toDateString() })
                        }
                        return out.slice(0, out[35].inMonth ? 42 : 35)
                    }
                    function step(n) { shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + n, 1) }

                    Column {
                        id: calCol
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 4

                        Item {
                            width: parent.width
                            height: 22
                            GlassText { anchors.verticalCenter: parent.verticalCenter; x: 4; text: Qt.locale().toString(cal.shownMonth, "MMMM yyyy"); font.weight: Font.DemiBold }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Repeater {
                                    model: [{ g: root.sf.left, n: -1 }, { g: root.sf.right, n: 1 }]
                                    MouseArea {
                                        id: nav
                                        required property var modelData
                                        width: 22
                                        height: 22
                                        hoverEnabled: true
                                        onClicked: cal.step(nav.modelData.n)
                                        Rectangle { anchors.fill: parent; radius: 11; color: Qt.rgba(1, 1, 1, nav.containsMouse ? 0.16 : 0) }
                                        Text { anchors.centerIn: parent; text: String.fromCodePoint(nav.modelData.g); color: "white"; font.family: GlassPanels.symbols; font.pixelSize: 10 }
                                    }
                                }
                            }
                        }
                        Grid {
                            columns: 7
                            Repeater {
                                model: ["M", "T", "W", "T", "F", "S", "S"]
                                GlassText {
                                    required property string modelData
                                    width: calCol.width / 7
                                    height: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                    font.pixelSize: 10
                                    text: modelData
                                }
                            }
                            Repeater {
                                model: cal.cells
                                Item {
                                    id: cell
                                    required property var modelData
                                    width: calCol.width / 7
                                    height: 27
                                    Rectangle {
                                        visible: cell.modelData.today
                                        anchors.centerIn: parent
                                        width: 25
                                        height: 25
                                        radius: 12.5
                                        color: "white"
                                    }
                                    GlassText {
                                        anchors.centerIn: parent
                                        font.pixelSize: 12
                                        font.weight: cell.modelData.today ? Font.Bold : Font.Medium
                                        color: cell.modelData.today ? GlassBackdrop.tint : Qt.rgba(1, 1, 1, cell.modelData.inMonth ? 1 : 0.35)
                                        text: cell.modelData.day
                                    }
                                }
                            }
                        }
                    }
                }

                GlassPiece { // to-do
                    id: todo
                    width: day.width
                    height: todoCol.height + 22
                    readonly property var open: Todo.list.map((t, i) => ({ text: t.content, done: t.done, index: i })).filter(t => !t.done)

                    Column {
                        id: todoCol
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 2

                        GlassCaption { leftPadding: 4; topPadding: 0; text: todo.open.length > 0 ? Translation.tr("To do · %1 left").arg(todo.open.length) : Translation.tr("To do") }
                        Repeater {
                            model: ScriptModel { values: todo.open.slice(0, 5) }
                            MouseArea {
                                id: task
                                required property var modelData
                                width: todoCol.width
                                height: 26
                                hoverEnabled: true
                                onClicked: Todo.markDone(task.modelData.index)
                                Rectangle {
                                    x: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15
                                    height: 15
                                    radius: 7.5
                                    color: Qt.rgba(1, 1, 1, task.containsMouse ? 0.5 : 0)
                                    border.width: 1.5
                                    border.color: Qt.rgba(1, 1, 1, 0.6)
                                }
                                GlassText {
                                    x: 28
                                    width: parent.width - 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.weight: Font.Normal
                                    text: task.modelData.text
                                }
                            }
                        }
                        Rectangle { // add a task
                            width: todoCol.width
                            height: 28
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.10)
                            Text { x: 9; anchors.verticalCenter: parent.verticalCenter; text: String.fromCodePoint(root.sf.plus); color: Qt.rgba(1, 1, 1, 0.7); font.family: GlassPanels.symbols; font.pixelSize: 10 }
                            TextInput {
                                id: newTask
                                anchors.fill: parent
                                anchors.leftMargin: 28
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: "white"
                                font.family: Appearance.font.family.main
                                font.pixelSize: 13
                                clip: true
                                onAccepted: { if (text.trim().length > 0) Todo.addTask(text.trim()); text = "" }
                            }
                            GlassText {
                                visible: newTask.text.length === 0
                                anchors.fill: newTask
                                verticalAlignment: Text.AlignVCenter
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.weight: Font.Normal
                                text: Translation.tr("New task, then Enter")
                            }
                        }
                    }
                }

                GlassPiece { // focus timer
                    id: timerPiece
                    width: day.width
                    height: 76
                    readonly property real secsLeft: TimerService.pomodoroSecondsLeft
                    readonly property real lapSecs: Math.max(TimerService.pomodoroLapDuration, 1)

                    Canvas {
                        id: dial
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 52
                        height: 52
                        property real frac: 1 - timerPiece.secsLeft / timerPiece.lapSecs
                        onFracChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.lineWidth = 5
                            ctx.lineCap = "round"
                            ctx.strokeStyle = "rgba(255,255,255,0.18)"
                            ctx.beginPath(); ctx.arc(26, 26, 22, 0, 2 * Math.PI); ctx.stroke()
                            ctx.strokeStyle = "#ffffff"
                            ctx.beginPath(); ctx.arc(26, 26, 22, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(frac, 0.001)); ctx.stroke()
                        }
                    }
                    Column {
                        anchors.left: dial.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        GlassText {
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            text: {
                                const s = Math.max(0, Math.round(timerPiece.secsLeft))
                                return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
                            }
                        }
                        GlassText {
                            color: Qt.rgba(1, 1, 1, 0.72)
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            text: TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: [
                                { g: TimerService.pomodoroRunning ? root.sf.pause : root.sf.play, run: () => TimerService.togglePomodoro() },
                                { g: root.sf.reload, run: () => TimerService.resetPomodoro() }
                            ]
                            MouseArea {
                                id: tb
                                required property var modelData
                                width: 34
                                height: 34
                                hoverEnabled: true
                                onClicked: tb.modelData.run()
                                Rectangle { anchors.fill: parent; radius: 17; color: Qt.rgba(1, 1, 1, tb.containsMouse ? 0.26 : 0.16) }
                                Text { anchors.centerIn: parent; text: String.fromCodePoint(tb.modelData.g); color: "white"; font.family: GlassPanels.symbols; font.pixelSize: 13 }
                            }
                        }
                    }
                }
            }

            // ── Detail panel: takes the place of the controls ──────────────
            GlassControlDetails {
                id: detailPane
                visible: root.detail.length > 0
                x: controls.x
                y: root.barH + 8
                width: controls.width
                opacity: area.opacity
                kind: root.detail
                dgpu: dgpu
                onBack: GlassPanels.controlDetail = ""
                HoverHandler { id: detailHover }
            }

            // ── Controls: to the left of the day ───────────────────────────
            Column {
                id: controls
                visible: root.detail.length === 0
                HoverHandler { id: controlsHover }
                x: day.x - width - 12
                y: root.barH + 8
                width: 372
                spacing: 10
                opacity: area.opacity
                scale: win.shown ? 1 : 0.94
                transformOrigin: Item.TopRight
                Behavior on scale { SpringAnimation { spring: 5.2; damping: 0.4; mass: 0.5 } }

                // Two rows of switches, then Displays across the full width. The external screen and
                // the dGPU that drives it are one thing, so they share the Displays control.
                Grid {
                    columns: 2
                    spacing: 10
                    readonly property real cw: (controls.width - spacing) / 2

                    GlassCapsule { id: cap1; width: parent.cw; glyph: root.sf.moon; title: Translation.tr("Night Light"); subtitle: GlassControls.nightOn ? (GlassControls.automatic ? Translation.tr("On until %1").arg(GlassControls.to) : Translation.tr("On")) : (GlassControls.automatic ? Translation.tr("Off until %1").arg(GlassControls.from) : Translation.tr("Off")); on: GlassControls.nightOn; detail: true; onActivated: GlassControls.toggleNight(); onDetailRequested: GlassPanels.controlDetail = "night" }
                    GlassCapsule { id: cap2; width: parent.cw; glyph: root.sf.cup; title: Translation.tr("Keep Awake"); subtitle: !keepAwake.toggled ? Translation.tr("Off") : GlassControls.awakeUntil > 0 ? Translation.tr("%1 min left").arg(GlassControls.awakeMinutesLeft) : Translation.tr("On"); on: keepAwake.toggled; detail: true; onActivated: keepAwake.toggled ? GlassControls.stopAwake() : GlassControls.keepAwake(GlassControls.awakeChoice); onDetailRequested: GlassPanels.controlDetail = "awake" }
                    GlassCapsule { id: cap3; width: parent.cw; glyph: micToggle.toggled ? root.sf.mic : root.sf.micSlash; title: Translation.tr("Microphone"); subtitle: micToggle.toggled ? Translation.tr("On") : Translation.tr("Muted"); on: micToggle.toggled; detail: true; onActivated: micToggle.mainAction(); onDetailRequested: GlassPanels.controlDetail = "mic" }
                    GlassCapsule { id: cap4; width: parent.cw; glyph: root.sf.cpu; title: "dGPU"; subtitle: root.state(dgpu); on: dgpu.toggled; usable: dgpu.available; detail: true; onActivated: dgpu.mainAction(); onDetailRequested: GlassPanels.controlDetail = "dgpu" }
                }
                GlassCapsule {
                    id: cap5
                    width: controls.width
                    glyph: root.sf.display
                    title: Translation.tr("Displays")
                    subtitle: Displays.busy ? Translation.tr("Switching…")
                            : Displays.modeName(Displays.mode) + (Displays.externalPresent ? "" : " · " + Translation.tr("no external screen connected"))
                              + (Displays.dgpuMode === "display" ? " · " + Translation.tr("dGPU on") : "")
                    on: displayMode.toggled
                    usable: displayMode.available
                    detail: true
                    onActivated: displayMode.mainAction()
                    onDetailRequested: GlassPanels.controlDetail = "displays"
                }

                Item { // lock, restart, shut down, more; and uptime
                    width: controls.width
                    height: 48
                    Row {
                        spacing: 10
                        GlassBead {
                            id: bead1
                            glyph: root.sf.lock
                            onActivated: { GlassPanels.close(); GlassControls.session("lock") }
                        }
                        GlassBead { // restart: asks first
                            id: bead2
                            glyph: root.sf.reload
                            onActivated: GlassPanels.controlConfirm = (root.confirm === "restart" ? "" : "restart")
                        }
                        GlassBead { // shut down: asks first
                            id: bead3
                            glyph: root.sf.power
                            onActivated: GlassPanels.controlConfirm = (root.confirm === "shutdown" ? "" : "shutdown")
                        }
                        GlassBead { // everything else
                            id: bead4
                            dots: true
                            onActivated: { GlassPanels.controlConfirm = ""; GlassPanels.controlDetail = "power" }
                        }
                    }
                    GlassPiece {
                        id: upPill
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: upText.implicitWidth + 28
                        height: 30
                        radius: 15
                        GlassText { id: upText; anchors.centerIn: parent; font.pixelSize: 12; text: Translation.tr("Up %1").arg(DateTime.uptime) }
                    }
                }

                GlassPiece { // "are you sure" for restart and shut down
                    id: confirmPiece
                    visible: root.confirm.length > 0
                    width: controls.width
                    height: 46
                    radius: 23
                    GlassText {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        font.weight: Font.DemiBold
                        text: root.confirm === "restart" ? Translation.tr("Restart this laptop?") : Translation.tr("Shut down this laptop?")
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        MouseArea {
                            id: no
                            width: noText.implicitWidth + 24
                            height: 30
                            hoverEnabled: true
                            onClicked: GlassPanels.controlConfirm = ""
                            Rectangle { anchors.fill: parent; radius: 15; color: Qt.rgba(1, 1, 1, no.containsMouse ? 0.28 : 0.16) }
                            GlassText { id: noText; anchors.centerIn: parent; font.pixelSize: 12; text: Translation.tr("Cancel") }
                        }
                        MouseArea {
                            id: yes
                            width: yesText.implicitWidth + 24
                            height: 30
                            hoverEnabled: true
                            onClicked: { const what = root.confirm; GlassPanels.close(); GlassControls.session(what) }
                            Rectangle { anchors.fill: parent; radius: 15; color: Qt.rgba(1, 0.27, 0.23, yes.containsMouse ? 0.95 : 0.75) }
                            GlassText { id: yesText; anchors.centerIn: parent; font.pixelSize: 12; font.weight: Font.DemiBold; text: root.confirm === "restart" ? Translation.tr("Restart") : Translation.tr("Shut down") }
                        }
                    }
                }

                GlassSlider {
                    id: brightness
                    readonly property var monitor: Brightness.getMonitorForScreen(win.screen)
                    width: controls.width
                    title: Translation.tr("Display")
                    lowGlyph: root.sf.sunMin
                    highGlyph: root.sf.sunMax
                    value: monitor?.brightness ?? 0
                    onMoved: (v) => monitor?.setBrightness(Math.max(v, 0.02))
                    onDetailRequested: GlassPanels.controlDetail = "displays"
                }
                GlassSlider {
                    id: volume
                    width: controls.width
                    title: Translation.tr("Sound")
                    lowGlyph: root.sf.speaker
                    highGlyph: root.sf.speakerWave
                    value: Audio.sink?.audio?.volume ?? 0
                    onMoved: (v) => { if (Audio.sink?.audio) Audio.sink.audio.volume = v }
                    onDetailRequested: GlassPanels.controlDetail = "sound"
                }
            }
        }
    }
}
