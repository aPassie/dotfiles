pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tracks the wallpaper swaybg is showing and derives the glass bar's dark tint
// from the strip of wallpaper that sits behind the bar. Bars watch `revision`
// to know when to regenerate their backdrop strip.
Singleton {
    id: root

    property string wallpaper: ""
    property color tint: Qt.rgba(0.11, 0.09, 0.06, 1)
    property real tintStrength: 0.55
    property int revision: 0
    // Shared with the now-playing panel so it can drop out of the media island
    property real mediaAnchorRight: 0
    property bool mediaIslandHovered: false
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/glassbar"

    function refresh() {
        findProc.running = true
    }

    Process {
        id: findProc
        command: ["sh", "-c", "p=$(pgrep -x swaybg | head -n1); [ -n \"$p\" ] && tr '\\0' '\\n' < /proc/$p/cmdline"]
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.split("\n")
                let p = ""
                for (let i = 0; i < a.length; i++)
                    if ((a[i] === "-i" || a[i] === "--image") && a[i + 1]) p = a[i + 1]
                if (p.length > 0 && p !== root.wallpaper) {
                    root.wallpaper = p
                    tintProc.running = true
                }
            }
        }
    }

    Process {
        id: tintProc
        command: ["magick", root.wallpaper, "-gravity", "North", "-crop", "100%x3%+0+0", "+repage",
                  "-resize", "1x1!", "-format", "%[fx:r] %[fx:g] %[fx:b]", "info:"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split(/\s+/).map(Number)
                if (v.length === 3 && v.every(x => !isNaN(x))) {
                    const avg = Qt.rgba(v[0], v[1], v[2], 1)
                    root.tint = Qt.hsla(Math.max(avg.hslHue, 0), Math.min(avg.hslSaturation * 1.3, 0.55), 0.085, 1)
                }
                root.revision++
            }
        }
    }

    // swaybg is restarted when the wallpaper changes, so a slow poll is enough.
    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    IpcHandler {
        target: "glassbar"
        function refresh(): void {
            root.wallpaper = ""
            root.refresh()
        }
    }
}
