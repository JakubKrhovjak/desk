pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.services

// Vazba mezi okny a aplikacemi v panelu. Aplikace s ikonou v trayi žije jen tam: nemá ikonu v seznamu oken
// a zavření jejího okna z lišty ho jen schová (close_active v desk/minimize.lua).
Singleton {
    id: root

    // Toolbox si své okno řídí sám jako vyskakovací panel (desk/toolbox.lua)
    readonly property var selfManagedTrayIds: ["toolbox"]

    readonly property var trayItems: SystemTray.items.values.filter(item => item.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(item.id))
    readonly property var trayKeys: trayItems.filter(item => !selfManagedTrayIds.includes(item.id)).map(item => trayKey(item))
    readonly property var ordinaryWindows: Hypr.toplevels.values.filter(toplevel => (toplevel?.workspace?.id ?? -1) > 0 || ShellEnv.isMinimized(toplevel))
    readonly property var trayClasses: [...new Set(ordinaryWindows.filter(toplevel => trayKeys.includes(appKey(toplevel))).map(toplevel => windowClass(toplevel)))].sort()
    // Pole vzniká znovu při každé změně oken, Hyprland se má dozvědět jen o změně obsahu
    readonly property string trayClassesKey: trayClasses.join()

    onTrayClassesKeyChanged: HyprWindows.setTrayClasses(trayClasses)
    Component.onCompleted: HyprWindows.setTrayClasses(trayClasses)

    // Reload konfigurace vynuluje seznam v Lua, shell ho musí poslat znovu
    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            HyprWindows.setTrayClasses(root.trayClasses);
        }
    }

    // Střed položky opakovače v okně panelu, kam odletí minimalizované okno
    function centerOf(repeater: var, matches: var, window: var): var {
        const item = Array.from({ length: repeater.count }, (_, index) => repeater.itemAt(index)).find(candidate => candidate && matches(candidate));
        return item ? item.mapToItem(window.contentItem, item.width / 2, item.height / 2) : null;
    }

    function entryFor(key: string): var {
        return DesktopEntries.applications.values && DesktopEntries.heuristicLookup(key);
    }

    function windowClass(toplevel: var): string {
        return toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || "";
    }

    // Klíč aplikace je ID záznamu .desktop, jinak třída okna
    function appKey(toplevel: var): string {
        const name = windowClass(toplevel);
        return entryFor(name)?.id ?? name;
    }

    function trayKey(item: var): string {
        return entryFor(item.id)?.id ?? item.id;
    }

    // Levý klik v trayi: okno schová, nebo ukáže; bez okna rozhoduje aplikace sama
    function activateTray(item: var): void {
        const group = selfManagedTrayIds.includes(item.id) ? [] : ordinaryWindows.filter(toplevel => appKey(toplevel) === trayKey(item));
        const active = group.find(toplevel => toplevel === Hyprland.activeToplevel && !ShellEnv.isMinimized(toplevel));
        if (group.length === 0)
            item.activate();
        else if (active)
            HyprWindows.minimize(active.address);
        else
            HyprWindows.show(group[0]);
    }
}
