pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus

// Správce úloh jako v Plasmě: jedna malá ikona na aplikaci, připnuté aplikace zůstávají i bez okna.
// Klik: spustí neběžící aplikaci, zvedne okno, jediné aktivní okno minimalizuje, u více oken mezi nimi přepíná.
// Prostřední tlačítko zavře okno, pravé otevře nabídku s připnutím. Tažením jde ikony přeřadit.
// Minimalizace = skrytá speciální plocha, Hyprland vlastní nemá.
Item {
    id: root

    required property ShellScreen screen
    required property var window

    readonly property var monitor: Hypr.monitorFor(screen)

    property var pins: []

    // Panel je jen jeden, takže ukazuje okna ze všech monitorů: normální plochy a minimalizovaná okna.
    // Aplikace s ikonou v trayi žije jen tam, pokud si ji uživatel výslovně nepřipnul. Nastavení má vlastní tlačítko v panelu.
    readonly property var windows: PanelApps.ordinaryWindows.filter(t => !WindowFactory.isSettingsWindow(t) && (!PanelApps.trayKeys.includes(PanelApps.appKey(t)) || pins.includes(PanelApps.appKey(t))))
    readonly property var windowKeys: windows.map(t => PanelApps.appKey(t)).filter(key => key !== "")
    readonly property var appKeys: [...new Set([...pins, ...windowKeys])]

    function windowsOf(key: string): var {
        return windows.filter(t => PanelApps.appKey(t) === key);
    }

    // Nové okno se otevře na monitoru, kde se kliklo
    function launch(key: string): void {
        HyprWindows.focusMonitor(screen.name);
        PanelApps.entryFor(key)?.execute();
    }

    function activate(key: string): void {
        const group = windowsOf(key);
        if (group.length === 0)
            launch(key);
        else if (group.length === 1 && group[0] === Hyprland.activeToplevel && !ShellEnv.isMinimized(group[0]))
            HyprWindows.minimize(group[0].address);
        else
            HyprWindows.show(group[(group.indexOf(Hyprland.activeToplevel) + 1) % group.length]);
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
        const hasEntry = !!PanelApps.entryFor(key);
        const windowRows = group.length > 1 ? group.map(t => ({ label: t.title, action: () => HyprWindows.show(t) })) : [];
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
        menu.openAt(item.mapToItem(window.contentItem, 0, 0).x, menuItemsFor(key));
    }

    JsonFile {
        id: pinStore

        path: `${ShellEnv.stateDir}/panel-pins.json`
        onValueLoaded: {
            if (Array.isArray(value))
                root.pins = value;
        }
    }

    // Střed ikony aplikace v okně panelu, kam odletí minimalizované okno
    function iconCenter(toplevel: var): var {
        const key = PanelApps.appKey(toplevel);
        return PanelApps.centerOf(slots, slotItem => slotItem.key === key, window);
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
                    readonly property bool allMinimized: group.length > 0 && group.every(t => ShellEnv.isMinimized(t))
                    // Okna shellu by jinak dostala zelenou ikonu Quickshellu, která se nepřebarví; mají společnou položku v panelu
                    readonly property string entryIcon: PanelApps.entryFor(slot.modelData)?.icon ?? ""
                    readonly property string shellIcon: group.every(t => WindowFactory.isSettingsWindow(t)) ? "preferences-system" : "system-file-manager"
                    readonly property string iconName: entryIcon === ShellEnv.shellClass ? shellIcon : entryIcon

                    implicitWidth: DeskPanelSettings.taskSize
                    implicitHeight: DeskPanelSettings.taskSize
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
                        implicitSize: DeskPanelSettings.iconSize
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

    PanelMenu {
        id: menu

        window: root.window
    }
}
