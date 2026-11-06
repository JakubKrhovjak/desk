import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

// Kulaté tlačítko panelu s ikonou, barvy jako moduly lišty Caelestie
StyledRect {
    id: root

    property string icon
    property string label // text místo ikony, třeba rozložení klávesnice
    property string image // obrázek místo ikony, obarví se podle schématu
    property bool active
    property bool big // levá strana panelu má větší ikony
    property color colour: Colours.palette.m3secondary
    readonly property color contentColour: active ? Colours.palette.m3onSecondaryContainer : colour
    readonly property bool hovered: hover.hovered

    signal clicked

    HoverHandler {
        id: hover
    }

    anchors.verticalCenter: parent?.verticalCenter
    implicitWidth: big ? 38 : 34
    implicitHeight: big ? 38 : 34
    radius: Tokens.rounding.full
    color: active ? Colours.palette.m3secondaryContainer : "transparent"

    StateLayer {
        radius: root.radius
        color: Colours.palette.m3onSurface
        onClicked: root.clicked()
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.label !== ""
        text: root.label
        color: root.contentColour
        font: Tokens.font.mono.medium
    }

    Image {
        anchors.centerIn: parent
        visible: root.image !== ""
        source: root.image
        sourceSize.width: root.big ? 28 : 24
        sourceSize.height: root.big ? 28 : 24
        layer.enabled: visible
        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: root.contentColour
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: root.label === "" && root.image === ""
        text: root.icon
        color: root.contentColour
        fontStyle: root.big ? Tokens.font.icon.large : Tokens.font.icon.medium
    }
}
