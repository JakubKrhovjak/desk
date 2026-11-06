pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.nexus

// Horní panel ve stylu lišty Caelestie: nabídka a tlačítka vlevo, okna uprostřed, tray a systém vpravo.
StyledWindow {
    id: root

    required property bool primary
    readonly property var screenState: ShellState.forScreen(screen)

    signal filesRequested
    signal lockRequested
    signal notificationsClicked

    readonly property bool notificationsHovered: !statusRow.dragging && notificationsButton.hovered

    name: "desk-panel"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Auto

    anchors.left: true
    anchors.right: true
    anchors.top: true
    implicitHeight: 46

    // Stejná plocha jako bubliny pod panelem, takže na něj plynule navazují
    Rectangle {
        anchors.fill: parent
        color: Colours.tPalette.m3surface
    }

    // Spoušť dashboardu: horní okraj obrazovky uprostřed; otevřený dashboard drží celá výška panelu nad ním
    readonly property bool dashboardTriggered: dashboardHold.hovered && dashboardHold.point.position.y < 3
    readonly property bool dashboardHeld: dashboardHold.hovered

    // Název vyskakovacího panelu pod myší a střed jeho ikony
    readonly property string statusHover: statusRow.dragging ? "" : keyboardButton.hovered ? "kblayout" : networkButton.hovered ? "network" : bluetoothButton.hovered ? "bluetooth" : volumeButton.hovered ? "audio" : ""

    function taskIconCenter(toplevel: var): var {
        return taskList.iconCenter(toplevel);
    }

    function statusCenter(): real {
        const button = ({ kblayout: keyboardButton, network: networkButton, bluetooth: bluetoothButton, audio: volumeButton })[statusHover] ?? networkButton;
        return button.mapToItem(contentItem, button.width / 2, 0).x;
    }

    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 854

        HoverHandler {
            id: dashboardHold
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 2

        PanelGroup {
            PanelButton {
                big: true
                colour: Colours.palette.m3tertiary
                image: Qt.resolvedUrl("arch-logo.svg")
                active: root.screenState?.launcher ?? false
                onClicked: root.screenState.launcher = !root.screenState.launcher
            }

            PanelButton {
                big: true
                icon: "folder"
                onClicked: root.filesRequested()
            }

            PanelButton {
                big: true
                icon: "screenshot_region"
                onClicked: Quickshell.execDetached(["qs", "-c", "desk", "ipc", "call", "picker", "openFreezeClip"])
            }

            PanelButton {
                big: true
                icon: "settings"
                onClicked: WindowFactory.create()
            }
        }

        TaskList {
            id: taskList

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            screen: root.screen
            window: root
        }

        // Pravá část panelu: položky jde přeuspořádat tažením, pořadí je v ~/.config/desk/panel-order.json
        PanelGroup {
            SortableRow {
                id: statusRow

                height: parent.height
                orderFile: `${Quickshell.env("HOME")}/.config/desk/panel-order.json`

                SortItem {
                    key: "tray"
                    shown: root.primary

                    TrayArea {
                        window: root
                    }
                }

                // Klávesnice, Wi-Fi a Bluetooth: najetí myší otevře vyskakovací panel Caelestie (Overlay)
                SortItem {
                    key: "keyboard"

                    PanelButton {
                        id: keyboardButton

                        label: Hypr.kbLayout
                    }
                }

                SortItem {
                    key: "network"

                    PanelButton {
                        id: networkButton

                        icon: Nmcli.activeEthernet ? "cable" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                    }
                }

                SortItem {
                    key: "bluetooth"

                    PanelButton {
                        id: bluetoothButton

                        icon: {
                            if (!Bluetooth.defaultAdapter?.enabled) // qmllint disable unresolved-type
                                return "bluetooth_disabled";
                            if (Bluetooth.devices.values.some(d => d.connected)) // qmllint disable unresolved-type
                                return "bluetooth_connected";
                            return "bluetooth";
                        }
                    }
                }

                SortItem {
                    key: "volume"

                    PanelButton {
                        id: volumeButton

                        icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                        onClicked: Audio.sink.audio.muted = !Audio.muted

                        WheelHandler {
                            onWheel: event => event.angleDelta.y > 0 ? Audio.incrementVolume(0.05) : Audio.decrementVolume(0.05)
                        }
                    }
                }

                SortItem {
                    key: "notifications"

                    PanelButton {
                        id: notificationsButton

                        icon: Notifs.notClosed.length > 0 ? "notifications_unread" : "notifications"
                        active: root.screenState?.sidebar ?? false
                        onClicked: root.notificationsClicked()
                    }
                }

                SortItem {
                    key: "clock"
                    padding: 8

                    Column {
                        x: 8

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Time.format("HH:mm")
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3tertiary
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.locale("en_US").toString(new Date(Time.format("yyyy-MM-ddTHH:mm:ss")), "MMM d, yyyy")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3tertiary
                        }
                    }

                    // Hodiny nemají tlačítko, kurzor aspoň napoví, že jdou přetáhnout
                    HoverHandler {
                        cursorShape: Qt.OpenHandCursor
                    }
                }

                SortItem {
                    key: "lock"

                    PanelButton {
                        icon: "lock"
                        onClicked: root.lockRequested()
                    }
                }

                SortItem {
                    key: "power"

                    PanelButton {
                        colour: Colours.palette.m3error
                        icon: "power_settings_new"
                        active: root.screenState?.session ?? false
                        onClicked: root.screenState.session = !root.screenState.session
                    }
                }
            }
        }
    }
}
