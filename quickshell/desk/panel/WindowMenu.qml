pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// Nabídka okna po pravém kliku na titulkovou lištu: připnutí navrch a ovládání okna.
// Vyvolává ji keybinds.lua přes IPC, protože lišta je kreslená pluginem v Hyprlandu.
Scope {
    id: root

    property bool open: false
    property string address
    property bool pinned
    property int cursorX
    property int cursorY

    readonly property ShellScreen targetScreen: Quickshell.screens.find(s => cursorX >= s.x && cursorX < s.x + s.width) ?? Quickshell.screens[0]

    readonly property var items: [
        { label: pinned ? "Unpin from top" : "Pin on top", icon: "push_pin", filled: pinned, action: () => HyprWindows.togglePin(address) },
        { label: "Minimize", icon: "minimize", action: () => HyprWindows.minimize(address) },
        { label: "Maximize", icon: "crop_square", action: () => HyprWindows.toggleMaximize(address) },
        { label: "Close", icon: "close", action: () => HyprWindows.closeFromBar(address) }
    ]

    IpcHandler {
        target: "windowmenu"

        function open(address: string, x: int, y: int, pinned: bool): void {
            root.address = address;
            root.cursorX = x;
            root.cursorY = y;
            root.pinned = pinned;
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }
    }

    LazyLoader {
        active: root.open

        StyledWindow {
            id: win

            name: "desk-window-menu"
            screen: root.targetScreen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // Klik mimo nabídku ji zavře
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: root.open = false
            }

            StyledRect {
                x: Math.min(root.cursorX - win.screen.x, win.width - width - 6)
                y: Math.min(root.cursorY - win.screen.y, win.height - height - 6)
                width: 220
                height: column.implicitHeight + 12
                radius: Tokens.rounding.medium
                color: Colours.palette.m3surfaceContainer

                Column {
                    id: column

                    anchors.fill: parent
                    anchors.margins: 6

                    Repeater {
                        model: root.items

                        MenuRow {
                            required property var modelData

                            width: column.width
                            label: modelData.label
                            icon: modelData.icon
                            iconFilled: modelData.filled ?? false
                            onActivated: {
                                root.open = false;
                                modelData.action();
                            }
                        }
                    }
                }
            }
        }
    }
}
