pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// niri stub: empty data so consumers in shared common/ widgets keep working.
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    function toplevelsForWorkspace(workspace) { return [] }
    function hyprlandClientsForWorkspace(workspace) { return [] }
    function clientForToplevel(toplevel) { return null }
    function biggestWindowForWorkspace(id) { return null }
    function updateWindowList() {}
    function updateLayers() {}
    function updateMonitors() {}
}
