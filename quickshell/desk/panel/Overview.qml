pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils

// Přehled oken jako Mission Control: na každém monitoru jeho okna vedle sebe s živým náhledem. Klik okno zvedne,
// Escape nebo klik do prázdna přehled zavře. Minimalizovaná okna tu nejsou, ta jsou v panelu.
Scope {
    id: root

    property bool open: false
    property var ignoredClasses: []
    property var pendingWindow: null

    function toggle(): void {
        if (!open)
            Hyprland.refreshToplevels();
        open = !open;
    }

    // Vrstva s výhradní klávesnicí brání přepnutí fokusu, proto se okno zvedá až po jejím zavření
    function choose(toplevel: var): void {
        pendingWindow = toplevel;
        open = false;
        showLater.restart();
    }

    function windowsOn(screen: ShellScreen): var {
        return Hypr.toplevels.values.filter(t => t.monitor?.name === screen.name
            && t.workspace?.id === t.monitor?.activeWorkspace?.id
            && !root.ignoredClasses.includes(t.lastIpcObject?.class));
    }

    Timer {
        id: showLater

        interval: 50
        onTriggered: HyprWindows.show(root.pendingWindow)
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggle();
        }
    }

    Variants {
        model: root.open ? Screens.screens : []

        StyledWindow {
            id: window

            required property ShellScreen modelData
            readonly property var windows: root.windowsOn(modelData)

            screen: modelData
            name: "desk-overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: modelData.name === Hypr.focusedMonitor?.name ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Item {
                id: content

                readonly property int count: window.windows.length
                readonly property int columns: Math.max(1, Math.ceil(Math.sqrt(count)))
                readonly property int rows: Math.max(1, Math.ceil(count / columns))
                readonly property real gap: Tokens.padding.extraLargeIncreased
                readonly property real titleHeight: 40
                readonly property real cellWidth: (width - gap * (columns + 1)) / columns
                readonly property real cellHeight: (height - gap * (rows + 1)) / rows

                anchors.fill: parent
                focus: true
                opacity: 0
                Component.onCompleted: opacity = 1
                Keys.onEscapePressed: root.open = false

                Behavior on opacity {
                    Anim {}
                }

                StyledRect {
                    anchors.fill: parent
                    color: Colours.palette.m3scrim
                    opacity: 0.6
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: content.count === 0
                    text: "No windows on this screen"
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.large
                }

                Grid {
                    anchors.centerIn: parent
                    columns: content.columns
                    spacing: content.gap

                    Repeater {
                        model: window.windows

                        Item {
                            id: tile

                            required property var modelData
                            readonly property var size: modelData.lastIpcObject?.size ?? [16, 9]
                            readonly property real aspect: size[0] / Math.max(1, size[1])
                            readonly property real previewWidth: Math.min(content.cellWidth, (content.cellHeight - content.titleHeight) * aspect)

                            width: content.cellWidth
                            height: content.cellHeight

                            StyledClippingRect {
                                id: frame

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: title.top
                                anchors.bottomMargin: Tokens.spacing.small
                                width: tile.previewWidth
                                height: tile.previewWidth / tile.aspect
                                radius: Tokens.rounding.medium
                                color: Colours.palette.m3surfaceContainer

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.min(parent.width, parent.height) * 0.3
                                    visible: !preview.hasContent
                                    source: Icons.getAppIcon(tile.modelData.lastIpcObject?.class ?? "", "image-missing")
                                }

                                ScreencopyView {
                                    id: preview

                                    anchors.centerIn: parent
                                    captureSource: tile.modelData.wayland ?? null // qmllint disable unresolved-type
                                    live: true
                                    constraintSize.width: frame.width
                                    constraintSize.height: frame.height
                                }
                            }

                            Rectangle {
                                anchors.fill: frame
                                radius: Tokens.rounding.medium
                                color: "transparent"
                                border.width: 3
                                border.color: Colours.palette.m3primary
                                opacity: hover.containsMouse ? 1 : 0

                                Behavior on opacity {
                                    Anim {}
                                }
                            }

                            Row {
                                id: title

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                height: content.titleHeight
                                spacing: Tokens.spacing.small

                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 22
                                    source: Icons.getAppIcon(tile.modelData.lastIpcObject?.class ?? "", "image-missing")
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, tile.width - 40)
                                    text: tile.modelData.title
                                    elide: Text.ElideRight
                                    color: Colours.palette.m3onSurface
                                    font: Tokens.font.body.small
                                }
                            }

                            MouseArea {
                                id: hover

                                anchors.fill: frame
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.choose(tile.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
