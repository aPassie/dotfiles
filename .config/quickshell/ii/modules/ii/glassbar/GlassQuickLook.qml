pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common

// Quick Look, as in Finder: Dolphin's "Quick Look" action (bound to Space) hands over the selected
// file and this shows it in a glass frame. Hold Space to peek (closes on release); a quick tap
// keeps it open until Space or Escape. Nothing here runs unless the preview is open.
Scope {
    id: root

    property bool open: false
    property string path: ""
    property double openedAt: 0
    // filled in by `probe` for each file
    property string kind: ""        // image, pdf, video, audio, text, folder, other
    property string mime: ""
    property string detail: ""      // what `file` says about it
    property string sizeText: ""
    property string dateText: ""
    property string textBody: ""
    property int itemCount: -1

    readonly property string name: path.slice(path.lastIndexOf("/") + 1)
    readonly property string url: path.length > 0 ? "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F") : ""

    function show(p) {
        if (open && p === path) return // key repeat from Dolphin while Space is still down
        kind = ""; mime = ""; detail = ""; sizeText = ""; dateText = ""; textBody = ""; itemCount = -1
        path = p
        openedAt = Date.now()
        open = true
        probe.exec(["sh", "-c",
            'f="$1"; echo "mime=$(file --mime-type -b -- "$f")"; echo "detail=$(file -b -- "$f" | cut -c1-90)"; ' +
            'echo "size=$(stat -c %s -- "$f")"; echo "date=$(date -d "@$(stat -c %Y -- "$f")" "+%-d %b %Y, %H:%M")"; ' +
            'if [ -d "$f" ]; then echo "count=$(find "$f" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)"; fi',
            "sh", p])
    }
    function hide() { open = false }

    function human(bytes) {
        const u = ["bytes", "KB", "MB", "GB", "TB"]
        let n = Number(bytes), i = 0
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
        return (i === 0 ? n : n.toFixed(n < 10 ? 1 : 0)) + " " + u[i]
    }
    function kindOf(m) {
        if (m === "inode/directory") return "folder"
        if (m.startsWith("image/")) return "image"
        if (m === "application/pdf") return "pdf"
        if (m.startsWith("video/")) return "video"
        if (m.startsWith("audio/")) return "audio"
        if (m.startsWith("text/") || /json|xml|javascript|x-sh|x-shellscript|x-python|x-desktop|toml|yaml|x-qml|sql|x-php|x-ruby|x-perl|x-lua|x-wine-extension-ini/.test(m)) return "text"
        return "other"
    }
    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                const info = {}
                text.split("\n").forEach(l => { const i = l.indexOf("="); if (i > 0) info[l.slice(0, i)] = l.slice(i + 1) })
                root.mime = info.mime ?? ""
                root.detail = info.detail ?? ""
                root.dateText = info.date ?? ""
                root.itemCount = info.count !== undefined ? Number(info.count) : -1
                root.kind = root.kindOf(root.mime)
                root.sizeText = root.kind === "folder" ? "" : root.human(info.size ?? 0)
                if (root.kind === "text") reader.exec(["head", "-c", "60000", "--", root.path])
            }
        }
    }
    Process {
        id: reader
        stdout: StdioCollector { onStreamFinished: root.textBody = text }
    }

    LazyLoader {
        active: root.open // closes at once: no fade, so no blurred patch is left behind for a moment

        component: PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === Niri.focusedMonitor?.name) ?? null

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:glass"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }
            BackgroundEffect.blurRegion: Region { item: root.open ? frame : null; radius: 22 }

            readonly property real maxW: win.width * 0.72
            readonly property real maxH: win.height * 0.74
            property int page: 0 // pdf

            MouseArea { // click anywhere to close
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.hide()
            }

            Item {
                id: keys
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: (event) => {
                    if (event.isAutoRepeat) { event.accepted = true; return }
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Escape) root.hide()
                    else if (root.kind === "pdf" && (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_PageDown)) win.page++
                    else if (root.kind === "pdf" && (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_PageUp)) win.page = Math.max(win.page - 1, 0)
                    event.accepted = true
                }
                Keys.onReleased: (event) => {
                    if (event.isAutoRepeat) return
                    // Space let go: a hold closes the preview, a quick tap leaves it open
                    if (event.key === Qt.Key_Space && Date.now() - root.openedAt > 350) root.hide()
                    event.accepted = true
                }
            }

            GlassPiece {
                id: frame
                readonly property real pad: 10
                readonly property real wantW: body.item ? body.item.wantW : 420
                readonly property real wantH: body.item ? body.item.wantH : 160
                width: Math.round(wantW) + pad * 2
                height: Math.round(wantH) + pad * 2 + 34
                anchors.centerIn: parent
                radius: 22
                tintStrength: 0.66
                // quick pop-in on open only
                opacity: 0
                scale: 0.96
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons } // clicks on the preview don't close it

                ClippingRectangle {
                    x: frame.pad
                    y: frame.pad
                    width: parent.width - frame.pad * 2
                    height: parent.height - frame.pad * 2 - 34
                    radius: 14
                    color: Qt.rgba(0, 0, 0, 0.25)
                    Loader {
                        id: body
                        anchors.fill: parent
                        sourceComponent: root.kind === "image" ? imageView : root.kind === "pdf" ? pdfView
                                       : root.kind === "video" ? videoView : root.kind === "audio" ? audioView
                                       : root.kind === "text" ? textView : root.kind.length > 0 ? infoView : null
                    }
                }
                Item { // name on the left, facts on the right
                    x: frame.pad + 6
                    y: parent.height - 34 - frame.pad + 6
                    width: parent.width - (frame.pad + 6) * 2
                    height: 28
                    GlassText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - facts.implicitWidth - 12
                        font.family: "Outfit"
                        font.weight: Font.DemiBold
                        text: root.name
                    }
                    GlassText {
                        id: facts
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.family: "Outfit"
                        font.pixelSize: 12
                        font.weight: Font.Normal
                        text: [body.item?.fact ?? "", root.sizeText, root.dateText].filter(s => s.length > 0).join("  ·  ")
                    }
                }
            }

            // ── Pictures ───────────────────────────────────────────────────
            Component {
                id: imageView
                Item {
                    readonly property real natW: Math.max(pic.implicitWidth, 1)
                    readonly property real natH: Math.max(pic.implicitHeight, 1)
                    readonly property real fit: Math.min(win.maxW / natW, win.maxH / natH, 1)
                    readonly property real wantW: Math.max(natW * fit, 240)
                    readonly property real wantH: Math.max(natH * fit, 120)
                    readonly property string fact: pic.status === Image.Ready ? `${pic.implicitWidth} × ${pic.implicitHeight}` : ""
                    Image {
                        id: pic
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        autoTransform: true
                        mipmap: true
                        source: root.url
                    }
                }
            }

            // ── PDF: one page at a time, arrow keys or scroll to turn ──────
            Component {
                id: pdfView
                Item {
                    readonly property real natW: Math.max(page.implicitWidth, 1)
                    readonly property real natH: Math.max(page.implicitHeight, 1)
                    readonly property real fit: Math.min(win.maxW / natW, win.height * 0.8 / natH)
                    readonly property real wantW: page.status === Image.Ready ? natW * fit : 520
                    readonly property real wantH: page.status === Image.Ready ? natH * fit : 680
                    readonly property string fact: page.frameCount > 0 ? `Page ${page.currentFrame + 1} of ${page.frameCount}` : "PDF"
                    Rectangle { anchors.fill: parent; color: "white" }
                    Image {
                        id: page
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        sourceSize.height: Math.round(win.height * 1.6)
                        source: root.url
                        currentFrame: Math.min(win.page, Math.max(frameCount - 1, 0))
                    }
                    Connections {
                        target: win
                        function onPageChanged() { if (page.frameCount > 0 && win.page > page.frameCount - 1) win.page = page.frameCount - 1 }
                    }
                    WheelHandler { onWheel: (e) => { if (e.angleDelta.y < 0) win.page++; else win.page = Math.max(win.page - 1, 0) } }
                }
            }

            // ── Video: plays as soon as it opens; click to pause ───────────
            Component {
                id: videoView
                Item {
                    readonly property size res: player.metaData.value(MediaMetaData.Resolution) ?? Qt.size(0, 0)
                    readonly property real natW: res.width > 0 ? res.width : 1280
                    readonly property real natH: res.height > 0 ? res.height : 720
                    readonly property real fit: Math.min(win.maxW / natW, win.maxH / natH, 1)
                    readonly property real wantW: Math.max(natW * fit, 320)
                    readonly property real wantH: Math.max(natH * fit, 180)
                    readonly property string fact: {
                        const s = Math.round(player.duration / 1000)
                        return (res.width > 0 ? `${res.width} × ${res.height}  ·  ` : "") + (s > 0 ? Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") : "Video")
                    }
                    MediaPlayer {
                        id: player
                        source: root.url
                        videoOutput: screen
                        audioOutput: AudioOutput {}
                        Component.onCompleted: play()
                    }
                    VideoOutput { id: screen; anchors.fill: parent }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                    }
                    Rectangle { // progress
                        anchors.bottom: parent.bottom
                        width: parent.width * (player.duration > 0 ? player.position / player.duration : 0)
                        height: 3
                        color: "white"
                    }
                }
            }

            // ── Audio ──────────────────────────────────────────────────────
            Component {
                id: audioView
                Item {
                    readonly property real wantW: 440
                    readonly property real wantH: 120
                    readonly property string fact: {
                        const s = Math.round(tune.duration / 1000)
                        return s > 0 ? Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") : "Audio"
                    }
                    MediaPlayer {
                        id: tune
                        source: root.url
                        audioOutput: AudioOutput {}
                        Component.onCompleted: play()
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: tune.playbackState === MediaPlayer.PlayingState ? tune.pause() : tune.play()
                    }
                    Image {
                        x: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        sourceSize: Qt.size(96, 96)
                        source: Qt.resolvedUrl("../../../assets/icons/glassbar/music.svg")
                    }
                    Column {
                        x: 88
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 112
                        spacing: 10
                        GlassText {
                            width: parent.width
                            font.family: "Outfit"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: tune.metaData.stringValue(MediaMetaData.Title) || root.name
                        }
                        GlassMeter { width: parent.width; value: tune.duration > 0 ? tune.position / tune.duration : 0 }
                        GlassText {
                            width: parent.width
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font.family: "Outfit"
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            text: tune.playbackState === MediaPlayer.PlayingState ? Translation.tr("Playing · click to pause") : Translation.tr("Paused · click to play")
                        }
                    }
                }
            }

            // ── Text and code: the start of the file, scrollable ───────────
            Component {
                id: textView
                Item {
                    readonly property real wantW: Math.min(win.maxW, 820)
                    readonly property real wantH: Math.min(win.maxH, Math.max(words.implicitHeight + 28, 140))
                    readonly property string fact: root.detail.split(",")[0]
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 14
                        contentHeight: words.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Text {
                            id: words
                            width: parent.width
                            color: Qt.rgba(1, 1, 1, 0.92)
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: 13
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere
                            text: root.textBody
                        }
                    }
                }
            }

            // ── Folders and everything else: icon and facts ────────────────
            Component {
                id: infoView
                Item {
                    readonly property real wantW: 440
                    readonly property real wantH: 150
                    readonly property string fact: ""
                    IconImage {
                        id: bigIcon
                        x: 26
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 84
                        source: Quickshell.iconPath(root.kind === "folder" ? "folder" : root.mime.replace("/", "-"), "text-x-generic")
                    }
                    Column {
                        anchors.left: bigIcon.right
                        anchors.leftMargin: 22
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        GlassText { width: parent.width; font.family: "Outfit"; font.pixelSize: 17; font.weight: Font.DemiBold; text: root.name }
                        GlassText {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                            maximumLineCount: 2
                            color: Qt.rgba(1, 1, 1, 0.7)
                            font.family: "Outfit"
                            font.weight: Font.Normal
                            text: root.kind === "folder"
                                ? (root.itemCount === 1 ? Translation.tr("Folder · 1 item") : Translation.tr("Folder · %1 items").arg(Math.max(root.itemCount, 0)))
                                : root.detail
                        }
                        GlassText {
                            visible: root.kind !== "folder"
                            width: parent.width
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.family: "Outfit"
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            text: Translation.tr("No preview for this kind of file")
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "quicklook"
        function open(path: string): void { root.show(path) } // not "show": the qs command line reserves that word
        function close(): void { root.hide() }
    }
}
