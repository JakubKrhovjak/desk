import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Skupina položek panelu ve stylu modulů lišty Caelestie: zaoblená pilulka na ploše panelu
StyledRect {
    id: root

    default property alias content: row.data

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: row.implicitWidth + 8
    implicitHeight: 40
    radius: Tokens.rounding.full
    color: Colours.tPalette.m3surfaceContainer

    Row {
        id: row

        anchors.centerIn: parent
        height: parent.height
        spacing: 2
    }
}
