pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.panels.lock
import QtQuick
import Quickshell

// niri uses ext-session-lock-v1 — the lock surface covers all outputs and
// hides every window natively, so we don't need the Hyprland workspace
// shuffle that the upstream version did. LockScreen + LockSurface alone
// gives a working lock.
LockScreen {
    id: root

    lockSurface: LockSurface {
        context: root.context
    }
}
