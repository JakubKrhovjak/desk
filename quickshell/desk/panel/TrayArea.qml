pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services
import qs.utils

// Systémová lišta vodorovně: levý klik ukáže nebo schová okno aplikace, pravý otevře její nabídku
Row {
    id: root

    required property var window

    // Střed ikony aplikace, kam odletí její schované okno
    function iconCenter(toplevel: var): var {
        const key = PanelApps.appKey(toplevel);
        return PanelApps.centerOf(icons, candidate => PanelApps.trayKey(candidate.modelData) === key, window);
    }

    spacing: 4

    FerdiumUnread {
        id: ferdiumUnread
    }

    Repeater {
        id: icons

        model: ScriptModel {
            values: PanelApps.trayItems
        }

        MouseArea {
            id: item

            required property SystemTrayItem modelData

            implicitWidth: DeskPanelSettings.iconSize + 2
            implicitHeight: DeskPanelSettings.buttonSize
            anchors.verticalCenter: parent?.verticalCenter
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            onClicked: event => {
                if (event.button === Qt.LeftButton && !modelData.onlyMenu) {
                    PanelApps.activateTray(modelData);
                } else if (event.button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                } else if (modelData.hasMenu) {
                    const point = mapToItem(root.window.contentItem, event.x, event.y);
                    modelData.display(root.window, point.x, point.y);
                }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: DeskPanelSettings.trayIconSize
                source: Icons.getTrayIcon(item.modelData.id, item.modelData.icon)
            }

            // Červený odznak s počtem nepřečtených zpráv
            Rectangle {
                readonly property string label: item.modelData.id === "ferdium" ? ferdiumUnread.label : ""

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 3
                visible: label !== ""
                width: Math.max(14, badgeText.implicitWidth + 6)
                height: 14
                radius: 7
                color: Colours.palette.m3error

                StyledText {
                    id: badgeText

                    anchors.centerIn: parent
                    text: parent.label
                    color: Colours.palette.m3onError
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
        }
    }
}
