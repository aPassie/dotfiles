import QtQuick

// The Claude mark. While `working`, its twelve rays slowly grow and shrink independently at
// random and the whole mark swells and settles, like a breathing spark; otherwise it is the
// plain logo. Each ray is the real logo
// clipped to that ray's wedge at a changing radius, so the shape itself is never redrawn.
Item {
    id: root

    property bool working: false
    property real size: 16
    width: size
    height: size

    // Gaps between neighbouring rays, in degrees (measured from the logo): ray i lives
    // between gaps[i - 1] and gaps[i].
    readonly property var gaps: [27.5, 48.0, 73.5, 100.0, 127.5, 157.5, 187.0, 229.5, 272.0, 298.0, 341.5, 364.5]
    property var len: gaps.map(() => 1)      // current length of each ray, 0..1
    property var want: gaps.map(() => 1)     // where each is heading

    Image {
        id: logo
        visible: false
        sourceSize: Qt.size(96, 96)
        source: Qt.resolvedUrl("../../../assets/icons/glassbar/claude-mark.svg")
        onStatusChanged: canvas.requestPaint()
    }

    Canvas {
        id: canvas
        readonly property int k: 3 // drawn at three times the size, then scaled down, to stay sharp
        width: root.size * k
        height: root.size * k
        anchors.centerIn: parent
        scale: root.swell / k
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (logo.status !== Image.Ready) return
            const c = width / 2, reach = c * 1.15, rad = Math.PI / 180
            for (let i = 0; i < root.gaps.length; i++) {
                const from = (i === 0 ? root.gaps[root.gaps.length - 1] - 360 : root.gaps[i - 1]) * rad
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(c, c)
                ctx.arc(c, c, reach * root.len[i], from, root.gaps[i] * rad)
                ctx.closePath()
                ctx.clip()
                ctx.drawImage(logo, 0, 0, width, height)
                ctx.restore()
            }
        }
    }

    Timer {
        id: tick
        interval: 33
        repeat: true
        running: root.visible && (root.working || !root.settled)
        onTriggered: {
            const len = root.len.slice(), want = root.want.slice()
            let settled = true
            for (let i = 0; i < len.length; i++) {
                if (root.working) { if (Math.random() < 0.05) want[i] = 0.42 + Math.random() * 0.58 }
                else want[i] = 1
                len[i] += (want[i] - len[i]) * 0.15
                if (Math.abs(len[i] - 1) > 0.01) settled = false
            }
            root.len = len
            root.want = want
            root.settled = settled && !root.working
            canvas.requestPaint()
        }
    }
    property bool settled: true

    // the whole mark grows and settles while working
    property real swell: 1
    SequentialAnimation on swell {
        running: root.visible && root.working
        loops: Animation.Infinite
        NumberAnimation { to: 1.16; duration: 950; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.86; duration: 950; easing.type: Easing.InOutSine }
    }
    Behavior on swell { enabled: !root.working; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    onWorkingChanged: { if (working) settled = false; else swell = 1 }
}
