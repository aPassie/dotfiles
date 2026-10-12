import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.ii.bar
import qs.modules.ii.glassbar
import qs.modules.ii.lock

Scope {
    PanelLoader { extraCondition: !Config.options.bar.vertical; component: GlassBar {} }
    PanelLoader { component: Lock {} }
    PanelLoader { component: GlassMediaPanel {} }
    PanelLoader { component: GlassWifiPanel {} }
    PanelLoader { component: GlassBluetoothPanel {} }
    PanelLoader { component: GlassNotificationsPanel {} }
    PanelLoader { component: GlassControlCentre {} }
    PanelLoader { component: GlassNotificationPopup {} }
    PanelLoader { component: GlassOsd {} }
    PanelLoader { component: GlassLauncherPanel {} }
    PanelLoader { component: GlassQuickLook {} }
    PanelLoader { component: GlassAppMenu {} }
    PanelLoader { component: GlassClaudePanel {} }
    PanelLoader { component: GlassClaudeNotice {} }
}
