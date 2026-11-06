import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Řádek kontextové nabídky panelu, s ikonou nebo bez ní.
StyledRect {
    id: root

    required property string label
    property string icon
    property bool iconFilled

    signal activated

    implicitHeight: 34
    radius: Tokens.rounding.small
    color: "transparent"

    StateLayer {
        radius: root.radius
        color: Colours.palette.m3onSurface
        onClicked: root.activated()
    }

    MaterialIcon {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: root.icon !== ""
        text: root.icon
        color: Colours.palette.m3onSurface
        fill: root.iconFilled ? 1 : 0
    }

    StyledText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.icon !== "" ? 38 : 10
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideRight
        color: Colours.palette.m3onSurface
        font: Tokens.font.body.small
    }
}
