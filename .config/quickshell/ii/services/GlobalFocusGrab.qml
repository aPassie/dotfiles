pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// niri stub: HyprlandFocusGrab is unavailable. Sidebars dismiss themselves
// via their own click-outside handling.
Singleton {
    id: root
    signal dismissed()
    property list<var> persistent: []
    property list<var> dismissable: []
    function dismiss() { root.dismissable = []; root.dismissed() }
    function addPersistent(window) {}
    function removePersistent(window) {}
    function addDismissable(window) {}
    function removeDismissable(window) {}
    function hasActive(element) { return !!element?.activeFocus }
}
