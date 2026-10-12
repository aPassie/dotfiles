pragma Singleton
import QtQuick
import Quickshell

// niri stub: keyboard layouts come from niri config, not hyprctl.
Singleton {
    id: root
    property var layoutCodes: []
    property string currentLayoutCode: ""
    function refresh() {}
    function setLayout(code) {}
}
