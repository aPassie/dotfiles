pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// Clear-glass top bar. Replaces modules/ii/bar/Bar.qml; the popups from that
// module are still reused. To go back, swap GlassBar for Bar in
// panelFamilies/IllogicalImpulseFamily.qml.
Scope {
    id: bar

    Variants {
        model: {
            const screens = Quickshell.screens
            const list = Config.options.bar.screenList
            if (!list || list.length === 0) return screens
            return screens.filter(screen => list.includes(screen.name))
        }

        LazyLoader {
            id: barLoader
            required property ShellScreen modelData
            active: GlobalStates.barOpen && !GlobalStates.screenLocked

            component: PanelWindow {
                id: barRoot
                screen: barLoader.modelData

                readonly property real barH: Appearance.sizes.baseBarHeight

                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: barH
                WlrLayershell.namespace: "quickshell:bar"
                // Taller than the bar itself: room for the hug corners and the app label.
                implicitHeight: barH + 44
                color: "transparent"
                mask: Region { item: content.inputRegion }

                anchors {
                    top: true
                    left: true
                    right: true
                }

                Component.onCompleted: GlobalFocusGrab.addPersistent(barRoot)
                Component.onDestruction: GlobalFocusGrab.removePersistent(barRoot)

                GlassBarContent {
                    id: content
                    anchors.fill: parent
                    screen: barRoot.screen
                    barH: barRoot.barH
                }
            }
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }

        function close(): void {
            GlobalStates.barOpen = false
        }

        function open(): void {
            GlobalStates.barOpen = true
        }
    }
}
