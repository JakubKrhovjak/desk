pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Animace minimalizace jako v Plasmě: snímek okna se zmenší a odletí do ikony v panelu.
// Pracuje se snímkem, takže se aplikace při animaci nepřekresluje. Skutečné okno schová až finish_minimize v Hyprlandu.
Scope {
    id: root

    required property var panel

    property var request: null

    function strip(address: string): string {
        return address.replace(/^0x/, "");
    }

    IpcHandler {
        target: "minimize"

        function animate(address: string, x: int, y: int, width: int, height: int): void {
            const toplevel = Hypr.toplevels.values.find(t => root.strip(t.address) === root.strip(address));
            root.request = toplevel?.wayland ? {
                address,
                toplevel,
                monitor: toplevel.monitor?.name ?? "",
                x,
                y,
                width,
                height
            } : null;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: surface

            required property ShellScreen modelData

            readonly property var request: root.request?.monitor === modelData.name ? root.request : null
            readonly property point target: {
                const center = request && root.panel?.screen === modelData ? root.panel.taskIconCenter(request.toplevel) : null;
                return center ?? (request ? Qt.point(request.x - modelData.x + request.width / 2, 0) : Qt.point(0, 0));
            }

            property real progress: 0

            function finish(): void {
                root.request = null;
                progress = 0;
            }

            screen: modelData
            visible: request !== null
            color: "transparent"
            mask: Region {}
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "desk-minimize"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            ScreencopyView {
                id: snapshot

                readonly property real startX: (surface.request?.x ?? 0) - surface.modelData.x
                readonly property real startY: (surface.request?.y ?? 0) - surface.modelData.y
                readonly property real endWidth: 28
                readonly property real scaleX: 1 + (endWidth / Math.max(width, 1) - 1) * surface.progress
                readonly property real scaleY: 1 + (endWidth / Math.max(height, 1) - 1) * surface.progress

                captureSource: surface.request?.toplevel.wayland ?? null
                live: false
                width: surface.request?.width ?? 0
                height: surface.request?.height ?? 0
                opacity: 1 - surface.progress * surface.progress * 0.7

                x: startX + (surface.target.x - endWidth / 2 - startX) * surface.progress
                y: startY + (surface.target.y - endWidth / 2 - startY) * surface.progress

                transform: Scale {
                    xScale: snapshot.scaleX
                    yScale: snapshot.scaleY
                }

                onHasContentChanged: {
                    if (hasContent && surface.request) {
                        Quickshell.execDetached(["hyprctl", "eval", `finish_minimize("${surface.request.address}")`]);
                        shrink.restart();
                    }
                }
            }

            NumberAnimation {
                id: shrink

                target: surface
                property: "progress"
                from: 0
                to: 1
                duration: 240
                easing.type: Easing.InCubic
                onFinished: surface.finish()
            }

            // Pojistka: když snímek nepřijde, okno stejně schová Hyprland a tahle vrstva nesmí zůstat viset
            Timer {
                running: surface.request !== null && !snapshot.hasContent
                interval: 400
                onTriggered: surface.finish()
            }
        }
    }
}
