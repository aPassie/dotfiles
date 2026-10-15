import QtQuick
import qs.services
import qs.modules.common
import qs.modules.ii.bar

// Phone hover pop-up: name, battery, how it is linked.
StyledPopup {
    id: root
    peekName: "phone"

    Column {
        id: col
        anchors.centerIn: parent
        width: 250
        spacing: 7

        GlassText {
            height: 34
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 21
            font.weight: Font.DemiBold
            text: PhoneLink.name
        }
        GlassMeter { visible: PhoneLink.battery >= 0; value: PhoneLink.battery / 100 }
        GlassStatLine {
            visible: PhoneLink.battery >= 0
            label: Translation.tr("Battery")
            value: PhoneLink.battery + "%" + (PhoneLink.charging ? " · " + Translation.tr("charging") : "")
        }
        GlassStatLine { label: Translation.tr("Connected"); value: PhoneLink.link }
    }
}
