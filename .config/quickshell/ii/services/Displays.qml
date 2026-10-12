pragma Singleton

import qs
import QtQuick
import Quickshell
import Quickshell.Io

// Display mode / arrangement state for niri.
//
// All the real work lives in ~/.local/bin/niri-display-mode, which owns the
// generated ~/.config/niri/config.d/95-monitors.kdl. Going through the config
// file (rather than `niri msg output ...` alone) is what makes a chosen mode
// survive config reloads — niri treats direct output commands as temporary.
//
// There is deliberately no "duplicate" mode: niri cannot mirror outputs.
Singleton {
    id: root

    property string mode: "extend"          // extend | internal | external | none
    property string arrangement: "right"    // left | right | above | below
    property string internalName: "eDP-1"
    property string externalName: ""
    property bool internalOn: true
    property bool externalOn: false
    property bool externalPresent: false
    property bool dgpuUnit: false
    property string dgpuMode: "off"   // off | compute | display | present
    property bool busy: false

    readonly property var modeOptions: [
        { value: "extend",   displayName: Translation.tr("Extend"),        icon: "devices" },
        { value: "internal", displayName: Translation.tr("Laptop only"),   icon: "laptop" },
        { value: "external", displayName: Translation.tr("External only"), icon: "monitor" },
    ]
    readonly property var arrangementOptions: [
        { value: "left",  displayName: Translation.tr("Left"),  icon: "west" },
        { value: "right", displayName: Translation.tr("Right"), icon: "east" },
        { value: "above", displayName: Translation.tr("Above"), icon: "north" },
        { value: "below", displayName: Translation.tr("Below"), icon: "south" },
    ]

    function modeName(m) {
        switch (m) {
        case "extend": return Translation.tr("Extended");
        case "internal": return Translation.tr("Laptop only");
        case "external": return Translation.tr("External only");
        default: return Translation.tr("No display");
        }
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true;
    }

    function setMode(newMode, newArrangement) {
        if (root.busy) return;
        root.busy = true;
        const args = ["niri-display-mode", "set", newMode];
        if (newArrangement) args.push(newArrangement);
        applyProc.command = args;
        applyProc.running = true;
    }

    // Put niri back on the panel and power the dGPU down. May legitimately fail
    // while niri holds the card — the helper reports that as an error, which
    // surfaces as a notification rather than being swallowed.
    function releaseDgpu() {
        if (root.busy) return;
        root.busy = true;
        applyProc.command = ["niri-display-mode", "release-dgpu"];
        applyProc.running = true;
    }

    function setArrangement(direction) {
        root.setMode("extend", direction);
    }

    // Icon-click action on the quick toggle: flip the external panel in/out.
    function toggleExternal() {
        root.setMode(root.externalOn ? "internal" : "extend", root.arrangement);
    }

    Process {
        id: applyProc
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Displays",
                    Translation.tr("Display mode change failed"),
                    applyErr.text.trim() || ("exit " + code)]);
            }
            root.refresh();
        }
    }

    Process {
        id: statusProc
        running: true
        command: ["niri-display-mode", "status"]
        stdout: StdioCollector {
            id: statusOut
            onStreamFinished: {
                const t = statusOut.text.trim();
                if (!t) return;
                try {
                    const s = JSON.parse(t);
                    root.mode = s.mode ?? "none";
                    root.arrangement = s.arrangement ?? "right";
                    root.internalName = s.internal ?? "";
                    root.externalName = s.external ?? "";
                    root.internalOn = s.internalOn ?? false;
                    root.externalOn = s.externalOn ?? false;
                    root.externalPresent = s.externalPresent ?? false;
                    root.dgpuUnit = s.dgpuUnit ?? false;
                    root.dgpuMode = s.dgpuMode ?? "off";
                } catch (e) {}
            }
        }
    }

    // Polling policy — this runs all day on battery, so it is scoped to when
    // the state is actually being looked at.
    //
    // The Display toggle and its dialog live inside the right sidebar, so
    // nothing observes this state while the sidebar is closed. Poll at a UI
    // cadence only while it is open; the rest of the time run just the cheap
    // safety net, and rarely.
    Timer {
        id: uiPoll
        interval: 5000
        running: GlobalStates.sidebarRightOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.busy) root.refresh()
    }

    // Backstop for "external vanished while external-only was active". Costs
    // one short-lived process a minute and only acts when no output is on.
    Timer {
        interval: 60000
        running: !GlobalStates.sidebarRightOpen
        repeat: true
        onTriggered: {
            if (root.busy) return;
            guardProc.running = true;
        }
    }

    Process {
        id: guardProc
        command: ["niri-display-mode", "guard"]
    }
}
