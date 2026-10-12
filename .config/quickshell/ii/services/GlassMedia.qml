pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.services

// Media players for the glass bar: duplicates merged, and ordered so the one
// that was un-paused most recently comes first.
Singleton {
    id: root

    property var startedAt: ({})   // dbusName -> when it last started playing
    property int stamp: 0          // bumps whenever startedAt changes

    readonly property var players: {
        root.stamp
        // A player with no title has nothing to show (e.g. a browser with no media loaded)
        const list = dedupe(MprisController.players.filter(p => (p.trackTitle ?? "").length > 0))
        return list.slice().sort((a, b) => (root.startedAt[b.dbusName] ?? 0) - (root.startedAt[a.dbusName] ?? 0))
    }
    readonly property MprisPlayer current: players.length > 0 ? players[0] : null

    function mark(player) {
        const m = root.startedAt
        m[player.dbusName] = Date.now()
        root.startedAt = m
        root.stamp++
    }

    // Browsers often expose the same video twice; keep one entry per track.
    function dedupe(list) {
        const out = []
        const used = new Set()
        for (let i = 0; i < list.length; i++) {
            if (used.has(i)) continue
            const a = list[i]
            const group = [i]
            for (let j = i + 1; j < list.length; j++) {
                const b = list[j]
                if (a.trackTitle && b.trackTitle && (a.trackTitle.includes(b.trackTitle) || b.trackTitle.includes(a.trackTitle)))
                    group.push(j)
            }
            const pick = group.find(k => list[k].trackArtUrl && list[k].trackArtUrl.length > 0) ?? group[0]
            out.push(list[pick])
            group.forEach(k => used.add(k))
        }
        return out
    }

    Instantiator {
        model: MprisController.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying) root.mark(modelData)
            }
            Component.onCompleted: if (modelData.isPlaying && !(modelData.dbusName in root.startedAt)) root.mark(modelData)
        }
    }
}
