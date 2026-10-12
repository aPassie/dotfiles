pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.services

// Every open app, in workspace order, with Dock-style magnification. Apps that are running
// without a window (they only have a tray icon) follow as a last group.
// Item positions are derived from `cursor` (pointer x in un-magnified strip
// coordinates) so the magnified layout never feeds back into itself.
Item {
    id: root

    required property string output
    property real cursor: -1                 // < 0 when the pointer is elsewhere
    readonly property bool active: cursor >= 0
    property color ink: "white"
    property color ink2: Qt.rgba(1, 1, 1, 0.74)
    property color hair: Qt.rgba(1, 1, 1, 0.22)

    readonly property string macIcons: "/usr/share/icons/WhiteSur-dark/apps/scalable"
    readonly property real slot: tight ? 27 : 31
    readonly property real sepW: tight ? 9 : 13
    readonly property real pad: 5
    readonly property real iconSize: 20
    readonly property real reach: 72       // how far the magnification spreads
    readonly property real boost: 0.27     // extra scale at the pointer
    readonly property bool tight: appCount > 14

    // Does this tray icon belong to the app with this window app-id? Names rarely agree exactly
    // ("TelegramDesktop" / "org.telegram.desktop"), so compare their meaningful words.
    readonly property var filler: ["org", "com", "net", "www", "desktop", "app", "client", "status", "icon", "chrome", "tray", "github", "gnome", "kde", "the"]
    function words(s) {
        return String(s || "").toLowerCase().split(/[^a-z0-9]+/).filter(p => p.length > 2 && !root.filler.includes(p))
    }
    function sameApp(item, appId) {
        const a = words(item.id + " " + item.title + " " + item.tooltipTitle), b = words(appId)
        return a.some(x => b.some(y => x === y || (y.length > 3 && x.includes(y)) || (x.length > 3 && y.includes(x))))
    }

    // The installed app a tray icon belongs to. Tray ids are often useless ("discord_status_icon_1",
    // empty title), and the fuzzy desktop-entry lookup then returns an unrelated app, so match on
    // whole words only: first an app whose id or name is one of the icon's words, then any shared word.
    function entryFor(item) {
        const w = words(item.id + " " + item.title + " " + item.tooltipTitle)
        if (w.length === 0) return null
        const apps = DesktopEntries.applications.values
        return apps.find(e => w.includes(String(e.id).toLowerCase()) || w.includes(String(e.name).toLowerCase()))
            ?? apps.find(e => words(e.id + " " + e.name).some(x => w.includes(x)))
            ?? null
    }

    // [{ sep: true } | { appId, name, ids: [windowId], titles, focused: index or -1, urgent, tray: item or null }]
    readonly property var model: {
        const wss = Niri.workspacesForOutput(root.output)
        const out = []
        for (let i = 0; i < wss.length; i++) {
            const wins = Niri.windows.filter(w => w.workspace_id === wss[i].id).sort((a, b) => {
                const pa = a.layout?.pos_in_scrolling_layout, pb = b.layout?.pos_in_scrolling_layout
                if (!pa && !pb) return a.id - b.id
                if (!pa) return 1
                if (!pb) return -1
                return (pa[0] - pb[0]) || (pa[1] - pb[1])
            })
            if (wins.length === 0) continue
            if (out.length > 0) out.push({ sep: true })
            const byApp = {}
            for (let j = 0; j < wins.length; j++) {
                const w = wins[j], key = w.app_id || "unknown"
                if (!byApp[key]) { byApp[key] = { sep: false, appId: key, ids: [], titles: [], focused: -1, urgent: false }; out.push(byApp[key]) }
                if (w.is_focused) byApp[key].focused = byApp[key].ids.length
                if (w.is_urgent) byApp[key].urgent = true
                byApp[key].ids.push(w.id)
                byApp[key].titles.push(w.title || "")
            }
        }

        // Tray icons: one that belongs to an app shown above gives that app its menu; the rest are
        // apps running in the background and go last.
        const background = []
        const items = SystemTray.items.values
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            const host = out.find(m => !m.sep && root.sameApp(it, m.appId))
            if (host) {
                if (!host.tray) host.tray = it
                if (it.status === Status.NeedsAttention) host.urgent = true
            } else if (!Niri.windows.some(w => root.sameApp(it, w.app_id || ""))) { // not just on another screen
                const entry = root.entryFor(it)
                background.push({
                    appId: entry?.id ?? it.id, name: entry?.name ?? (it.tooltipTitle || it.title || it.id),
                    ids: [], titles: [], focused: -1, urgent: it.status === Status.NeedsAttention, tray: it,
                    unknown: !entry // no installed app found for it: show the icon the app itself sends
                })
            }
        }
        if (background.length > 0 && out.length > 0) out.push({ sep: true })
        return out.concat(background)
    }
    readonly property int appCount: model.filter(m => !m.sep).length
    readonly property bool empty: appCount === 0

    // Un-magnified geometry
    readonly property var baseCenters: {
        const c = []
        let x = pad
        for (let i = 0; i < model.length; i++) {
            const w = model[i].sep ? sepW : slot
            c.push(x + w / 2)
            x += w
        }
        return c
    }
    readonly property real baseWidth: pad * 2 + model.reduce((a, m) => a + (m.sep ? sepW : slot), 0)

    function scaleAt(i) {
        if (!active || model[i].sep) return 1
        const d = Math.abs(cursor - baseCenters[i])
        return d < reach ? 1 + boost * (Math.cos(d / reach * Math.PI) + 1) / 2 : 1
    }
    readonly property var extras: model.map((m, i) => m.sep ? 0 : slot * (scaleAt(i) - 1) * 0.82)
    readonly property real totalExtra: extras.reduce((a, b) => a + b, 0)
    readonly property real anchorT: active ? Math.min(Math.max(cursor / baseWidth, 0), 1) : 0.5

    // Label for the icon under the pointer
    readonly property int hoveredIndex: {
        if (!active) return -1
        let best = -1, bd = slot * 0.75
        for (let i = 0; i < model.length; i++) {
            if (model[i].sep) continue
            const d = Math.abs(cursor - baseCenters[i])
            if (d < bd) { bd = d; best = i }
        }
        return best
    }
    readonly property string hoveredLabel: {
        if (hoveredIndex < 0) return ""
        const m = model[hoveredIndex]
        const name = nameOf(m)
        if (m.ids.length === 0) return `${name} · in background`
        return m.ids.length > 1 ? `${name} · ${m.ids.length} windows` : name
    }
    function nameOf(m) {
        return m.name ?? (DesktopEntries.byId(m.appId) ?? DesktopEntries.heuristicLookup(m.appId))?.name ?? m.appId
    }
    readonly property real hoveredCenter: hoveredIndex < 0 ? 0 : itemX(hoveredIndex) + (model[hoveredIndex].sep ? sepW : slot) / 2 + extras[hoveredIndex] / 2

    function itemX(i) {
        let x = pad
        for (let k = 0; k < i; k++) x += (model[k].sep ? sepW : slot) + extras[k]
        return x
    }

    function activate(m) {
        if (m.ids.length === 0) { // in the background: ask the app for its window
            if (m.tray) m.tray.activate()
            return
        }
        // Already in this app: step to its next window. Otherwise jump to it.
        const next = m.focused >= 0 ? (m.focused + 1) % m.ids.length : 0
        Niri.focusWindow(m.ids[next])
    }

    // Right-click menu for the app at this position in the model (GlassAppMenu draws it).
    property var iconSources: ({})
    function openMenu(i) {
        const m = model[i]
        if (!m || m.sep) return
        GlassPanels.showAppMenu({
            appId: m.appId, name: nameOf(m), ids: m.ids, titles: m.titles, focused: m.focused,
            tray: m.tray ?? null, icon: iconSources[i] ?? ""
        }, root.mapToItem(null, itemX(i) + (slot + (extras[i] ?? 0)) / 2, 0).x)
    }
    IpcHandler { // for testing without a pointer: qs -c ii ipc call appStrip menu <part of the app's name>
        target: "appStrip"
        function menu(app: string): void {
            const k = app.toLowerCase()
            const i = root.model.findIndex(m => !m.sep && (m.appId.toLowerCase().includes(k) || root.nameOf(m).toLowerCase().includes(k)))
            if (i >= 0) root.openMenu(i)
        }
    }

    implicitWidth: baseWidth + totalExtra
    implicitHeight: 32

    Repeater {
        model: root.model

        Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool sep: modelData.sep === true
            readonly property real grow: root.extras[index] ?? 0

            x: root.itemX(index)
            width: (sep ? root.sepW : root.slot) + grow
            height: root.height

            Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            Rectangle { // hairline between workspaces
                visible: cell.sep
                anchors.centerIn: parent
                width: 1
                height: 12
                color: root.hair
            }

            Image { // prefer the macOS-style WhiteSur icon, fall back to the shell's icon theme
                id: icon
                readonly property string name: cell.sep ? "" : AppSearch.guessIcon(cell.modelData.appId)
                // File managers get the macOS set's plain blue folder (his pick): its app icon for them
                // is the Finder face.
                readonly property bool fileManager: /dolphin|nautilus|thunar|nemo|pcmanfm|file-?manager|org\.gnome\.files/i.test((cell.sep ? "" : cell.modelData.appId) + " " + name)
                property bool themed: !fileManager
                readonly property string themePath: cell.sep ? "" : Quickshell.iconPath(name, true)
                onSourceChanged: root.iconSources[cell.index] = source
                visible: !cell.sep
                anchors.centerIn: parent
                width: root.iconSize
                height: root.iconSize
                sourceSize: Qt.size(64, 64)
                mipmap: true
                source: cell.sep ? ""
                    : cell.modelData.unknown === true ? cell.modelData.tray.icon
                    : name.startsWith("/") ? `file://${name}`
                    : fileManager ? "file:///usr/share/icons/WhiteSur-dark/places/scalable/folder.svg"
                    : themed ? `file://${root.macIcons}/${name}.svg`
                    : themePath.length > 0 ? themePath
                    : cell.modelData.tray ? cell.modelData.tray.icon // the icon the app itself sends
                    : Quickshell.iconPath("image-missing")
                onStatusChanged: if (status === Image.Error && themed) themed = false
                scale: root.scaleAt(cell.index)
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            }

            Rectangle { // wants attention
                visible: !cell.sep && cell.modelData.urgent
                anchors.right: icon.right
                anchors.top: icon.top
                anchors.rightMargin: -3
                anchors.topMargin: -3
                width: 7
                height: 7
                radius: 3.5
                color: "#ffb224"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
            }

            TapHandler {
                enabled: !cell.sep
                acceptedButtons: Qt.LeftButton
                onTapped: root.activate(cell.modelData)
            }
            TapHandler {
                enabled: !cell.sep
                acceptedButtons: Qt.RightButton
                onTapped: root.openMenu(cell.index)
            }
        }
    }
}
