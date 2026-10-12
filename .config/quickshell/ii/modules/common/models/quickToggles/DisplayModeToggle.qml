import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles

// Display arrangement toggle.
//
//   icon click : flip the external panel in/out (Extend <-> Laptop only)
//   body click : open the dialog for modes + arrangement
//
// "toggled" tracks whether the external output is actually being driven, so it
// stays honest when the cable is pulled or the dGPU display toggle intervenes.
QuickToggleModel {
    id: root

    name: Translation.tr("Display")
    icon: Displays.externalOn ? "devices" : "laptop"
    toggled: Displays.externalOn
    available: Displays.externalPresent || Displays.dgpuUnit
    statusText: Displays.busy ? Translation.tr("Switching…") : Displays.modeName(Displays.mode)
    tooltipText: Translation.tr("Display arrangement | Click the icon to toggle the external screen, the label to configure")

    hasMenu: true
    mainAction: () => {
        if (Displays.busy) return;
        Displays.toggleExternal();
    }

    Component.onCompleted: Displays.refresh()
}
