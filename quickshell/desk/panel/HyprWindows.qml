pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Ovládání oken z panelu: jediné místo, které skládá příkazy pro Hyprland. Funkce na druhé straně jsou v desk/*.lua.
Singleton {
    // Hyprland hlásí adresu s předponou 0x, Quickshell bez ní
    function address(value: string): string {
        return `0x${value.replace(/^0x/, "")}`;
    }

    function selector(value: string): string {
        return `"address:${address(value)}"`;
    }

    // Víc kroků musí jít v jednom příkazu: samostatné procesy se můžou předběhnout
    function run(lines: var): void {
        Quickshell.execDetached(["hyprctl", "eval", lines.join("; ")]);
    }

    function focus(value: string): string {
        return `hl.dispatch(hl.dsp.focus({ window = ${selector(value)} }))`;
    }

    function raise(value: string): void {
        run([`restore_window("${address(value)}")`]);
    }

    function restoreMinimized(value: string, workspace: int): void {
        run([`restore_minimized("${address(value)}", ${workspace})`]);
    }

    function show(toplevel: var): void {
        if (ShellEnv.isMinimized(toplevel))
            restoreMinimized(toplevel.address, toplevel.monitor?.activeWorkspace?.id ?? Hypr.focusedWorkspace?.id ?? 1);
        else
            raise(toplevel.address);
    }

    // Názvy tříd určují aplikace a jdou do Lua jako kód, proto jen znaky, které se v nich běžně vyskytují
    function setTrayClasses(classes: var): void {
        const names = classes.filter(name => /^[\w.-]+$/.test(name)).map(name => `"${name}"`);
        run([`set_tray_classes({ ${names.join(", ")} })`]);
    }

    function fitWindowsToPanel(oldHeight: int): void {
        run([`fit_windows_to_panel(${oldHeight})`]);
    }

    // Stejně jako křížek v liště okna: aplikaci s ikonou v trayi jen schová
    function closeFromBar(value: string): void {
        run([focus(value), "close_active()"]);
    }

    function close(value: string): void {
        run([`hl.dispatch(hl.dsp.window.close({ window = ${selector(value)} }))`]);
    }

    function togglePin(value: string): void {
        run([`hl.dispatch(hl.dsp.window.pin({ action = "toggle", window = ${selector(value)} }))`]);
    }

    function minimize(value: string): void {
        run([focus(value), "minimize_active()"]);
    }

    function toggleMaximize(value: string): void {
        run([focus(value), "toggle_maximize()"]);
    }

    function focusMonitor(name: string): void {
        run([`hl.dispatch(hl.dsp.focus({ monitor = "${name}" }))`]);
    }
}
