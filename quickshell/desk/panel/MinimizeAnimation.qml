pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Animace minimalizace a obnovení jako v Plasmě: snímek okna letí po oblouku do ikony v panelu a zpět.
// Pracuje se snímkem, takže se aplikace při animaci nepřekresluje. Skutečné okno přesouvá Hyprland:
// finish_minimize hned po pořízení snímku, finish_restore až na konci animace.
// Skryté okno se vyfotit nedá, proto se snímek pro obnovení uloží už při minimalizaci.
Scope {
    id: root

    required property var panel

    property var request: null
    property var cache: ({})

    function findToplevel(address: string): var {
        return Hypr.toplevels.values.find(t => HyprWindows.address(t.address) === HyprWindows.address(address));
    }

    function finishRestore(address: string): void {
        HyprWindows.finishRestore(address);
    }

    IpcHandler {
        target: "minimize"

        function animate(address: string, x: int, y: int, width: int, height: int): void {
            const toplevel = root.findToplevel(address);
            root.request = toplevel?.wayland ? {
                mode: "minimize",
                address,
                toplevel,
                monitor: toplevel.monitor?.name ?? "",
                x,
                y,
                width,
                height
            } : null;
        }

        // Bez uloženého snímku (třeba po restartu shellu) se okno vrátí hned, bez animace
        function restore(address: string): void {
            const saved = root.cache[HyprWindows.address(address)];
            const toplevel = root.findToplevel(address);
            if (saved && toplevel)
                root.request = Object.assign({}, saved, { mode: "restore", address, toplevel });
            else
                root.finishRestore(address);
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

            function saveSnapshot(view: Item): void {
                const saved = request;
                view.grabToImage(image => {
                    root.cache[HyprWindows.address(saved.address)] = {
                        image,
                        url: image.url,
                        monitor: saved.monitor,
                        x: saved.x,
                        y: saved.y,
                        width: saved.width,
                        height: saved.height
                    };
                    // Okno se schová a animace začne až s hotovým snímkem, jinak by ho konec animace zahodil
                    HyprWindows.finishMinimize(saved.address);
                    shrink.restart();
                });
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

            Item {
                id: flyer

                readonly property real startX: (surface.request?.x ?? 0) - surface.modelData.x
                readonly property real startY: (surface.request?.y ?? 0) - surface.modelData.y
                readonly property real endSize: DeskPanelSettings.iconSize
                readonly property real scaleX: 1 + (endSize / Math.max(width, 1) - 1) * surface.progress
                readonly property real scaleY: 1 + (endSize / Math.max(height, 1) - 1) * surface.progress
                // Svislý pohyb se opožďuje za vodorovným, takže okno letí po oblouku
                readonly property real archProgress: surface.progress * surface.progress

                width: surface.request?.width ?? 0
                height: surface.request?.height ?? 0
                opacity: 1 - Math.max(0, surface.progress) ** 3 * 0.75

                x: startX + (surface.target.x - endSize / 2 - startX) * surface.progress
                y: startY + (surface.target.y - endSize / 2 - startY) * archProgress

                transform: Scale {
                    xScale: flyer.scaleX
                    yScale: flyer.scaleY
                }

                // Pro každou minimalizaci nový snímek: u znovu použitého by se hasContent podruhé nezměnil
                Loader {
                    id: snapshotLoader

                    anchors.fill: parent
                    active: surface.request?.mode === "minimize"

                    sourceComponent: ScreencopyView {
                        captureSource: surface.request?.toplevel.wayland ?? null
                        live: false

                        onHasContentChanged: {
                            if (hasContent && surface.request?.mode === "minimize") {
                                surface.saveSnapshot(this);
                            }
                        }
                    }
                }

                Image {
                    id: saved

                    anchors.fill: parent
                    visible: surface.request?.mode === "restore"
                    source: visible ? surface.request.url : ""
                    cache: false

                    onStatusChanged: {
                        if (status === Image.Ready && surface.request?.mode === "restore") {
                            surface.progress = 1;
                            grow.restart();
                        } else if (status === Image.Error && surface.request) {
                            root.finishRestore(surface.request.address);
                            surface.finish();
                        }
                    }
                }
            }

            NumberAnimation {
                id: shrink

                target: surface
                property: "progress"
                from: 0
                to: 1
                duration: 380
                easing.type: Easing.InOutCubic
                onFinished: surface.finish()
            }

            NumberAnimation {
                id: grow

                target: surface
                property: "progress"
                from: 1
                to: 0
                duration: 440
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
                onFinished: {
                    const address = surface.request?.address;
                    if (address) {
                        delete root.cache[HyprWindows.address(address)];
                        root.finishRestore(address);
                    }
                    reveal.restart();
                }
            }

            // Snímek zůstane chvíli nad oknem, dokud ho Hyprland nezobrazí, aby neproblikla plocha
            Timer {
                id: reveal

                interval: 70
                onTriggered: surface.finish()
            }

            // Pojistka: když snímek nepřijde, okno stejně přesune Hyprland a tahle vrstva nesmí zůstat viset
            Timer {
                running: surface.request?.mode === "minimize" && !shrink.running
                interval: 1000
                onTriggered: surface.finish()
            }
        }
    }
}
