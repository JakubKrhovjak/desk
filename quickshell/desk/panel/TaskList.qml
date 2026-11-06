pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

    readonly property string configDir: `${Quickshell.env("HOME")}/.config/desk`
    readonly property string hiddenWorkspace: "special:minimized"
    readonly property var monitor: Hypr.monitorFor(screen)

    property var pins: []

    // Panel je jen jeden, takže ukazuje okna ze všech monitorů: normální plochy a minimalizovaná okna
    readonly property var windows: Hypr.toplevels.values.filter(t => (t?.workspace?.id ?? -1) > 0 || isMinimized(t))
    readonly property var windowKeys: windows.map(t => appKey(t)).filter(key => key !== "")
    readonly property var appKeys: [...new Set([...pins, ...windowKeys])]

    function isMinimized(toplevel: var): bool {
        return toplevel?.workspace?.name === hiddenWorkspace;
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

    function run(lines: var): void {
        Quickshell.execDetached(["hyprctl", "eval", lines.join("; ")]);
    }

    function target(toplevel: var): string {
        return `"address:0x${toplevel.address.replace(/^0x/, "")}"`;
    }

    function raise(toplevel: var): void {
        run([`hl.dispatch(hl.dsp.focus({ window = ${target(toplevel)} }))`, "hl.dispatch(hl.dsp.window.bring_to_top())"]);
    }

    function restore(toplevel: var): void {
        const workspace = toplevel.monitor?.activeWorkspace?.id ?? monitor?.activeWorkspace?.id ?? 1;
        // Přesun a fokus musí jít v jednom příkazu: dva samostatné procesy se můžou předběhnout a okno se neukáže
        run([
            `hl.dispatch(hl.dsp.window.move({ workspace = ${workspace}, follow = false, window = ${target(toplevel)} }))`,
            `hl.dispatch(hl.dsp.focus({ window = ${target(toplevel)} }))`,
            "hl.dispatch(hl.dsp.window.bring_to_top())"
        ]);
    }

    function close(toplevel: var): void {
        run([`hl.dispatch(hl.dsp.window.close({ window = ${target(toplevel)} }))`]);
    }

    function show(toplevel: var): void {
        if (isMinimized(toplevel))
            restore(toplevel);
        else
            raise(toplevel);
    }

    // Nové okno se otevře na monitoru, kde se kliklo
    function launch(key: string): void {
        run([`hl.dispatch(hl.dsp.focus({ monitor = "${screen.name}" }))`]);
        entryFor(key)?.execute();
    }

    function activate(key: string): void {
        const group = windowsOf(key);
        console.log("TASKLOG", Date.now() % 100000, "activate", key, "oken", group.length, "minim", group.map(t => isMinimized(t)).join(), "aktivni", Hyprland.activeToplevel?.title?.slice(0, 25)); // DOČASNÉ
        if (group.length === 0)
            launch(key);
        else
            show(group[(group.indexOf(Hyprland.activeToplevel) + 1) % group.length]);
    }

    function closeOne(key: string): void {
        const group = windowsOf(key);
        const toplevel = group.find(t => t === Hyprland.activeToplevel) ?? group[0];
        if (toplevel)
            close(toplevel);
    }

    function setPinned(key: string, pinned: bool): void {
        const others = pins.filter(pin => pin !== key);
        pins = pinned ? [...others, key] : others;
        pinStore.setText(JSON.stringify(pins));
    }

    function loadPins(content: string): void {
        try {
            const parsed = JSON.parse(content);
            if (Array.isArray(parsed))
                pins = parsed;
        } catch (error) {
            console.warn("desk: invalid pinned apps file:", error);
        }
    }

    function menuItemsFor(key: string): var {
        const group = windowsOf(key);
        const pinned = pins.includes(key);
        const hasEntry = !!entryFor(key);
        const windowRows = group.length > 1 ? group.map(t => ({ label: t.title, action: () => show(t) })) : [];
        const launchRows = hasEntry ? [{ label: group.length > 0 ? "New window" : "Launch", action: () => launch(key) }] : [];
        const pinRows = hasEntry || pinned ? [{ label: pinned ? "Unpin from panel" : "Pin to panel", action: () => setPinned(key, !pinned) }] : [];
        const closeRows = group.length > 0 ? [{ label: group.length > 1 ? "Close all windows" : "Close window", action: () => group.map(t => close(t)) }] : [];
        const onTopRows = group.length === 1 ? [{
                label: group[0].lastIpcObject?.pinned ? "Unpin from top" : "Pin on top",
                action: () => run([`hl.dispatch(hl.dsp.window.pin({ action = "toggle", window = ${target(group[0])} }))`])
            }] : [];
        return [...windowRows, ...launchRows, ...pinRows, ...onTopRows, ...closeRows];
    }

    function openMenu(key: string, item: Item): void {
        menu.items = menuItemsFor(key);
        menu.anchor.rect.x = item.mapToItem(window.contentItem, 0, 0).x;
        menu.anchor.rect.y = window.height;
        menu.visible = true;
    }

    FileView {
        id: pinStore

        path: `${root.configDir}/panel-pins.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loadPins(text())
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
        orderFile: `${root.configDir}/panel-tasks-order.json`

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

                    StyledRect {
                        id: menuRow

                        required property var modelData

                        width: menuColumn.width
                        implicitHeight: 34
                        radius: Tokens.rounding.small
                        color: "transparent"

                        StateLayer {
                            radius: menuRow.radius
                            color: Colours.palette.m3onSurface
                            onClicked: {
                                menu.visible = false;
                                menuRow.modelData.action();
                            }
                        }

                        StyledText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuRow.modelData.label
                            elide: Text.ElideRight
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                        }
                    }
                }
            }
        }
    }
}
