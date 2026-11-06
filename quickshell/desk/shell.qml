//@ pragma UseQApplication
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Prostředí "desk": stavební kameny z Caelestie (symlinky), vlastní panel a rozložení.
import "modules"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "modules/windowswitcher"
import "panel"
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus

ShellRoot {
    id: root

    // Panel a vše k němu patřící jen na hlavním monitoru
    readonly property string primaryScreen: Screens.screens.some(s => s.name === ShellEnv.mainMonitor) ? ShellEnv.mainMonitor : (Screens.screens[0]?.name ?? "")

    settings.watchFiles: false

    // Night Shift hlídá svůj plán po celou dobu běhu shellu, nejen při otevřeném panelu
    readonly property var nightShift: NightShiftState

    IpcHandler {
        target: "nightshift"

        function open(): void {
            WindowFactory.openPage("nightshift");
        }
    }

    // Otevře stránku Nastavení podle id z PageRegistry
    IpcHandler {
        target: "settings"

        function open(page: string): void {
            WindowFactory.openPage(page);
        }
    }

    Component.onCompleted: Quickshell.execDetached([`${ShellEnv.deskDir}/toolbox-tray.sh`])

    // Ikony Simpleton v barvách schématu; nové barvy se v běžícím shellu ukážou až po jeho restartu
    FileView {
        path: `${Paths.state}/scheme.json`
        watchChanges: true
        onFileChanged: Quickshell.execDetached([`${ShellEnv.deskDir}/recolor-icons.sh`])
    }

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    GSFLoader {}
    ServiceLoader {}

    Background {}
    AreaPicker {}
    Lock {
        id: lock
    }

    FileDialog {
        id: filePicker

        title: "Files"
        onAccepted: path => Quickshell.execDetached(["xdg-open", path])
    }

    IpcHandler {
        target: "files"

        function open(): void {
            filePicker.open();
        }

        function close(): void {
            filePicker.close();
        }
    }

    // Menu aplikací je jen v panelu na hlavním monitoru, bez ohledu na to, kde je fokus
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            const hasFullscreen = ShellEnv.hasFullscreen(Hypr.focusedWorkspace);
            const state = ShellState.forScreen(Screens.screens.find(s => s.name === root.primaryScreen));
            if (state && !hasFullscreen)
                state.launcher = !state.launcher;
        }
    }

    Variants {
        model: Screens.screens.filter(s => s.name === root.primaryScreen)

        Scope {
            id: perScreen

            required property ShellScreen modelData

            Panel {
                id: panel

                screen: perScreen.modelData
                onFilesRequested: filePicker.open()
                onLockRequested: lock.lock.locked = true
                Component.onCompleted: root.mainPanel = panel
            }

            Overlay {
                screen: perScreen.modelData
                panelWindow: panel
            }
        }
    }

    property var mainPanel: null

    MinimizeAnimation {
        panel: root.mainPanel
    }

    Shortcuts {}
    WindowMenu {}
    WindowSwitcher {
        focusedMonitorOnly: true
        ignoredClasses: ["jetbrains-toolbox"]
        minimizedWorkspace: ShellEnv.minimizedWorkspace
    }
    IdleMonitors {
        lock: lock
    }
}
