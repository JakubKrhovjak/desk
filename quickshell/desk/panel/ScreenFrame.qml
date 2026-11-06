import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components.containers
import qs.services

// Rámeček plochy v barvě panelu: navazuje na panel a jeho vnitřní rohy mají stejný poloměr jako okna, která do něj zapadnou.
// Leží pod okny, takže maximalizované okno přes něj přejde a v jeho rozích zůstane vidět stejná barva.
StyledWindow {
    id: root

    name: "desk-frame"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    mask: Region {}

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Rectangle {
        anchors.fill: parent
        color: Colours.tPalette.m3surface
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: hole
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: hole

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: ShellEnv.edgeGap
            radius: ShellEnv.windowRounding
        }
    }
}
