pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Caelestia.Config
import qs.services
import qs.utils

// Systémová lišta vodorovně: levý klik aktivuje, pravý otevře nabídku aplikace
Row {
    id: root

    required property var window

    spacing: 4

    FerdiumUnread {
        id: ferdiumUnread
    }

    Repeater {
        model: ScriptModel {
            values: SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))
        }

        MouseArea {
            id: item

            required property SystemTrayItem modelData

            implicitWidth: 30
            implicitHeight: 38
            anchors.verticalCenter: parent?.verticalCenter
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            onClicked: event => {
                if (event.button === Qt.LeftButton && !modelData.onlyMenu) {
                    modelData.activate();
                } else if (event.button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                } else if (modelData.hasMenu) {
                    const point = mapToItem(root.window.contentItem, event.x, event.y);
                    modelData.display(root.window, point.x, point.y);
                }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 22
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
                color: "#e5383b"

                Text {
                    id: badgeText

                    anchors.centerIn: parent
                    text: parent.label
                    color: "#ffffff"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
        }
    }
}
