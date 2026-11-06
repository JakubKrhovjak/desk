pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// Správce úloh jako v Plasmě: jedna malá ikona na aplikaci, připnuté aplikace zůstávají i bez okna.
// Klik: spustí neběžící aplikaci, zvedne okno, u více oken mezi nimi přepíná. Minimalizace je jen tlačítko v liště okna.
// Prostřední tlačítko zavře okno, pravé otevře nabídku s připnutím. Tažením jde ikony přeřadit.
// Minimalizace = skrytá speciální plocha, Hyprland vlastní nemá.
Item {
    id: root

    required property ShellScreen screen
    required property var window

    readonly property var monitor: Hypr.monitorFor(screen)

    property var pins: []

    // Panel je jen jeden, takže ukazuje okna ze všech monitorů: normální plochy a minimalizovaná okna
    readonly property var windows: Hypr.toplevels.values.filter(t => (t?.workspace?.id ?? -1) > 0 || isMinimized(t))
    readonly property var windowKeys: windows.map(t => appKey(t)).filter(key => key !== "")
    readonly property var appKeys: [...new Set([...pins, ...windowKeys])]

    function isMinimized(toplevel: var): bool {
        return toplevel?.workspace?.name === ShellEnv.minimizedWorkspace;
    }

    function entryFor(key: string): var {
        return DesktopEntries.applications.values && DesktopEntries.heuristicLookup(key);
    }

    // Klíč aplikace je ID záznamu .desktop, jinak třída okna
    function appKey(toplevel: var): string {
        const windowClass = toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || "";
        return entryFor(windowClass)?.id ?? windowClass;
    }

    function windowsOf(key: string): var {
        return windows.filter(t => appKey(t) === key);
    }

    function show(toplevel: var): void {
        if (isMinimized(toplevel))
            HyprWindows.restoreMinimized(toplevel.address, toplevel.monitor?.activeWorkspace?.id ?? monitor?.activeWorkspace?.id ?? 1);
        else
            HyprWindows.raise(toplevel.address);
    }

    // Nové okno se otevře na monitoru, kde se kliklo
    function launch(key: string): void {
        HyprWindows.focusMonitor(screen.name);
        entryFor(key)?.execute();
    }

    function activate(key: string): void {
        const group = windowsOf(key);
        if (group.length === 0)
            launch(key);
        else
            show(group[(group.indexOf(Hyprland.activeToplevel) + 1) % group.length]);
    }

    function closeOne(key: string): void {
        const group = windowsOf(key);
        const toplevel = group.find(t => t === Hyprland.activeToplevel) ?? group[0];
        if (toplevel)
            HyprWindows.close(toplevel.address);
    }

    function setPinned(key: string, pinned: bool): void {
        const others = pins.filter(pin => pin !== key);
        pins = pinned ? [...others, key] : others;
        pinStore.save(pins);
    }

    function menuItemsFor(key: string): var {
        const group = windowsOf(key);
        const pinned = pins.includes(key);
        const hasEntry = !!entryFor(key);
        const windowRows = group.length > 1 ? group.map(t => ({ label: t.title, action: () => show(t) })) : [];
        const launchRows = hasEntry ? [{ label: group.length > 0 ? "New window" : "Launch", action: () => launch(key) }] : [];
        const pinRows = hasEntry || pinned ? [{ label: pinned ? "Unpin from panel" : "Pin to panel", action: () => setPinned(key, !pinned) }] : [];
        const closeRows = group.length > 0 ? [{ label: group.length > 1 ? "Close all windows" : "Close window", action: () => group.map(t => HyprWindows.close(t.address)) }] : [];
        const onTopRows = group.length === 1 ? [{
                label: group[0].lastIpcObject?.pinned ? "Unpin from top" : "Pin on top",
                action: () => HyprWindows.togglePin(group[0].address)
            }] : [];
        return [...windowRows, ...launchRows, ...pinRows, ...onTopRows, ...closeRows];
    }

    function openMenu(key: string, item: Item): void {
        menu.items = menuItemsFor(key);
        menu.anchor.rect.x = item.mapToItem(window.contentItem, 0, 0).x;
        menu.anchor.rect.y = window.height;
        menu.visible = true;
    }

    JsonFile {
        id: pinStore

        path: `${ShellEnv.stateDir}/panel-pins.json`
        onValueLoaded: value => {
            if (Array.isArray(value))
                root.pins = value;
        }
    }

    // Střed ikony aplikace v okně panelu, kam odletí minimalizované okno
    function iconCenter(toplevel: var): var {
        const key = appKey(toplevel);
        const item = Array.from({ length: slots.count }, (_, index) => slots.itemAt(index)).find(slotItem => slotItem?.key === key);
        return item ? item.mapToItem(window.contentItem, item.width / 2, item.height / 2) : null;
    }

    SortableRow {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        orderFile: `${ShellEnv.stateDir}/panel-tasks-order.json`

        Repeater {
            id: slots

            model: ScriptModel {
                values: root.appKeys
            }

            SortItem {
                id: slot

                required property string modelData

                key: modelData

                StyledRect {
                    id: task

                    readonly property var group: root.windowsOf(slot.modelData)
                    readonly property bool isActive: group.includes(Hyprland.activeToplevel)
                    readonly property bool allMinimized: group.length > 0 && group.every(t => root.isMinimized(t))
                    readonly property string iconName: root.entryFor(slot.modelData)?.icon ?? ""

                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    color: isActive ? Colours.palette.m3secondaryContainer : "transparent"

                    StateLayer {
                        radius: task.radius
                        color: Colours.palette.m3onSurface
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.RightButton)
                                root.openMenu(slot.modelData, task);
                            else if (event.button === Qt.MiddleButton)
                                root.closeOne(slot.modelData);
                            else
                                root.activate(slot.modelData);
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 28
                        opacity: task.allMinimized ? 0.55 : 1
                        source: Quickshell.iconPath(task.iconName, "application-x-executable")
                    }

                    // Tečky pod ikonou: počet oken, nejvýš tři
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        Repeater {
                            model: Math.min(task.group.length, 3)

                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: task.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: menu

        property var items: []

        anchor.window: root.window
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
}
