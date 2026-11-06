import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

// Night Shift ve zvukovém panelu: rychlé ovládání, klik na název otevře jeho stránku v Nexusu.
ColumnLayout {
    id: root

    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.medium

        Item {
            Layout.fillWidth: true
            implicitHeight: nameText.implicitHeight

            StyledText {
                id: nameText

                text: NightShiftState.active ? `Night Shift (${NightShiftState.temperature} K)` : "Night Shift"
                font.family: Tokens.font.body.medium.family
                font.pointSize: Tokens.font.body.medium.pointSize
                font.weight: Font.Medium
                font.underline: nameArea.containsMouse
            }

            MouseArea {
                id: nameArea

                anchors.fill: nameText
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: WindowFactory.openPage("nightshift")
            }
        }

        StyledSwitch {
            checked: NightShiftState.active
            onToggled: NightShiftState.setActive(checked)
        }
    }

    StyledSlider {
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 3
        opacity: NightShiftState.active ? 1 : 0.5
        enabled: NightShiftState.active

        // Vlevo teplejší barvy, vpravo chladnější
        value: (NightShiftState.temperature - NightShiftState.warmest) / (NightShiftState.coolest - NightShiftState.warmest)
        onInteraction: value => NightShiftState.setTemperature(NightShiftState.warmest + value * (NightShiftState.coolest - NightShiftState.warmest))
    }
}
