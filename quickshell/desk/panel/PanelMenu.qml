pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

// Kontextová nabídka panelu pod zadaným místem. Položka: { label, action }.
PopupWindow {
    id: menu

    required property var window

    property var items: []

    function openAt(x: real, menuItems: var): void {
        items = menuItems;
        anchor.rect.x = x;
        anchor.rect.y = window.height;
        visible = true;
    }

    anchor.window: window
    color: "transparent"
    implicitWidth: 260
    implicitHeight: menuColumn.implicitHeight + 12

    HyprlandFocusGrab {
        active: menu.visible
        windows: [menu]
        onCleared: menu.visible = false
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.medium
        color: Colours.palette.m3surfaceContainer

        Column {
            id: menuColumn

            anchors.fill: parent
            anchors.margins: 6

            Repeater {
                model: menu.items

                MenuRow {
                    required property var modelData

                    width: menuColumn.width
                    label: modelData.label
                    onActivated: {
                        menu.visible = false;
                        modelData.action();
                    }
                }
            }
        }
    }
}
