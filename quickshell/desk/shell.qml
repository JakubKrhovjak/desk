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
import qs.modules.nexus

ShellRoot {
    id: root

    // Panel a vše k němu patřící jen na hlavním monitoru
    readonly property string primaryScreen: Screens.screens.some(s => s.name === "HDMI-A-1") ? "HDMI-A-1" : (Screens.screens[0]?.name ?? "")

    settings.watchFiles: false

    // Night Shift hlídá svůj plán po celou dobu běhu shellu, nejen při otevřeném panelu
    readonly property var nightShift: NightShiftState

    IpcHandler {
        target: "nightshift"

        function open(): void {
            WindowFactory.create(null, { startPage: PageRegistry.pages.findIndex(page => page.id === "nightshift") });
        }
    }

    Component.onCompleted: Quickshell.execDetached([`${Quickshell.env("HOME")}/.config/desk/toolbox-tray.sh`])

    // Ikony Simpleton v barvách schématu; nové barvy se v běžícím shellu ukážou až po jeho restartu
    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/caelestia/scheme.json`
        watchChanges: true
        onFileChanged: Quickshell.execDetached([`${Quickshell.env("HOME")}/.config/desk/recolor-icons.sh`])
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
            const hasFullscreen = Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
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
                primary: perScreen.modelData.name === root.primaryScreen
                onFilesRequested: filePicker.open()
                onLockRequested: lock.lock.locked = true
                Component.onCompleted: root.mainPanel = panel
            }

            Overlay {
                screen: perScreen.modelData
                primary: perScreen.modelData.name === root.primaryScreen
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
        minimizedWorkspace: "special:minimized"
    }
    IdleMonitors {
        lock: lock
    }
}
