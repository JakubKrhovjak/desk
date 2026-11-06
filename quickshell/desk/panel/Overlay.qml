pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.bar.popouts as BarPopouts
import qs.modules.launcher as Launcher
import qs.modules.nexus
import qs.modules.notifications as Notifications
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar

// Vrstva nad plochou, sahá po panel: nabídka aplikací, notifikace, nabídka vypnutí a dashboard shora.
StyledWindow {
    id: root

    required property var panelWindow

    readonly property var screenState: ShellState.forScreen(screen)
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool hasFullscreen: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

    // Launcher z Caelestie čte rozměry ostatních panelů, které tady nejsou
    readonly property var absentPanels: ({
            dashboard: { nonAnimHeight: 0 },
            bar: { implicitWidth: 0 },
            popouts: { hasCurrent: false, currentCenter: 0, nonAnimHeight: 0, nonAnimWidth: 0 },
            utilities: { implicitWidth: 0 }
        })

    name: "desk-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: (screenState?.launcher || screenState?.session) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    onHasFullscreenChanged: {
        screenState.launcher = false;
        screenState.session = false;
        screenState.dashboard = false;
        popouts.close();
    }

    // Klikat jde jen na to, co je zrovna vidět; zbytek propouští myš do oken
    mask: Region {
        Region { item: dashZone }
        Region { item: launcherBg.visible ? launcherBg : null }
        Region { item: popoutBg.visible ? popoutBg : null }
        Region { item: notifsBg.visible ? notifsBg : null }
        Region { item: sessionBg.visible ? sessionBg : null }
        Region { item: sidebarBg.visible ? sidebarBg : null }
    }

    // Klik mimo zavře otevřený panel; horní panel zůstává klikací, aby tlačítko umělo i zavřít
    HyprlandFocusGrab {
        active: (root.screenState?.launcher || root.screenState?.session || (root.screenState?.sidebar && root.sidebarPinned)) ?? false
        windows: [root, root.panelWindow]
        onCleared: {
            root.screenState.launcher = false;
            root.screenState.session = false;
            root.screenState.sidebar = false;
            root.sidebarPinned = false;
        }
    }

    StyledRect {
        anchors.fill: parent
        opacity: root.screenState?.session ? 0.5 : 0
        color: Colours.palette.m3scrim

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    // Dashboard: krátké podržení myši na horním okraji ho vysune zpod panelu. Otevřený ho drží panel a plocha dashboardu.
    // Myš přechází mezi dvěma okny (panel a tahle vrstva), proto se zavírá s krátkým zpožděním. Plochy pro hover
    // nesmí během otevírání měnit velikost: Qt pak hlásí odchod myši a dashboard kmitá.
    readonly property bool dashboardTriggered: panelWindow?.dashboardTriggered ?? false
    readonly property bool dashboardHeld: dashHover.hovered || (panelWindow?.dashboardHeld ?? false)


    onDashboardTriggeredChanged: {
        if (dashboardTriggered)
            dashOpen.restart();
        else
            dashOpen.stop();
    }

    onDashboardHeldChanged: {
        if (dashboardHeld)
            dashClose.stop();
        else if (screenState?.dashboard)
            dashClose.restart();
    }

    Timer {
        id: dashOpen

        interval: 150
        onTriggered: {
            if (root.screenState && !root.hasFullscreen && !dashReopenGuard.running) {
                dashClose.stop();
                root.screenState.dashboard = true;
            }
        }
    }

    Timer {
        id: dashClose

        interval: 200
        onTriggered: {
            if (root.screenState?.dashboard) {
                root.screenState.dashboard = false;
                dashReopenGuard.restart();
            }
        }
    }

    // Po zavření se dashboard chvíli znovu neotevře, ani když je myš pořád u okraje
    Timer {
        id: dashReopenGuard

        interval: 500
    }

    Item {
        id: dashZone

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: dash.implicitWidth || 854
        height: root.screenState?.dashboard ? dash.implicitHeight : 0

        HoverHandler {
            id: dashHover
        }
    }

    StyledRect {
        anchors.horizontalCenter: dash.horizontalCenter
        y: dash.y
        width: dash.width
        height: dash.height
        visible: dash.visible
        opacity: dash.opacity
        color: Colours.tPalette.m3surface
        bottomLeftRadius: Tokens.rounding.extraLarge
        bottomRightRadius: Tokens.rounding.extraLarge
    }

    DashWrapper {
        id: dash

        screenState: root.screenState
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // Nabídka aplikací: objeví se uprostřed obrazovky jako na Macu
    StyledRect {
        id: launcherBg

        x: launcher.x
        y: launcher.y
        width: launcher.width
        height: launcher.height
        visible: launcher.visible
        opacity: launcher.opacity
        color: Colours.tPalette.m3surface
        radius: Tokens.rounding.extraLarge
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        screenState: root.screenState
        panels: root.absentPanels

        x: (parent.width - implicitWidth) / 2
        y: (parent.height - implicitHeight) / 2 + 20 * offsetScale
    }

    // Wi-Fi a Bluetooth: vyskakovací panel Caelestie, vyjede zpod panelu pod ikonou.
    // Zůstává otevřený, dokud je myš nad ikonou nebo nad ním; dialog s heslem a nastavení se samy nezavírají.
    readonly property string statusHover: panelWindow?.statusHover ?? ""
    readonly property bool popoutHeld: popoutHover.hovered || popoutContentHover.hovered || statusHover !== ""

    // Tlačítko Open settings otevře okno Nexus na stránce daného panelu místo Nexusu vloženého do vyskakovacího panelu
    Connections {
        target: root.popouts

        function onIsDetachedChanged(): void {
            if (!root.popouts.isDetached)
                return;
            const page = ["appearance", "network", "bluetooth", "audio"].indexOf(root.popouts.queuedMode);
            // Až po skončení obsluhy: zavření přímo tady je smyčka vazby a isDetached by zůstalo viset na true
            Qt.callLater(() => {
                root.popouts.close();
                WindowFactory.create(null, { startPage: page });
            });
        }
    }

    // Historie notifikací: otevře se po najetí na zvonek a po odjetí se zavře; cesta od zvonku k panelu může vést přes
    // volné místo, proto delší zpoždění. Klik ji připne, pak drží do kliknutí jinam.
    property bool sidebarPinned: false
    readonly property bool notificationsHovered: panelWindow?.notificationsHovered ?? false
    readonly property bool sidebarHeld: notificationsHovered || sidebarBgHover.hovered || sidebarContentHover.hovered

    onNotificationsHoveredChanged: {
        if (notificationsHovered && screenState && !hasFullscreen)
            screenState.sidebar = true;
    }

    onSidebarHeldChanged: {
        if (sidebarHeld)
            sidebarClose.stop();
        else
            sidebarClose.restart();
    }

    Timer {
        id: sidebarClose

        interval: 400
        onTriggered: {
            if (root.screenState && !root.sidebarPinned)
                root.screenState.sidebar = false;
        }
    }

    Connections {
        target: root.panelWindow

        function onNotificationsClicked(): void {
            const close = root.sidebarPinned && root.screenState.sidebar;
            root.sidebarPinned = !close;
            root.screenState.sidebar = !close;
        }
    }

    onStatusHoverChanged: {
        if (statusHover === "" || hasFullscreen || popouts.isDetached || popouts.currentName === "wirelesspassword")
            return;
        popouts.currentCenter = panelWindow.statusCenter();
        popouts.currentName = statusHover;
        popouts.hasCurrent = true;
    }

    onPopoutHeldChanged: {
        if (popoutHeld)
            popoutClose.stop();
        else
            popoutClose.restart();
    }

    Timer {
        id: popoutClose

        interval: 200
        onTriggered: {
            if (!root.popouts.isDetached && root.popouts.currentName !== "wirelesspassword")
                root.popouts.hasCurrent = false;
        }
    }

    property alias popouts: popoutsWrapper

    StyledRect {
        id: popoutBg

        x: popoutsWrapper.x
        y: popoutsWrapper.y
        width: popoutsWrapper.width
        height: popoutsWrapper.height
        visible: popoutsWrapper.visible
        color: Colours.tPalette.m3surface
        radius: popoutsWrapper.isDetached ? Tokens.rounding.extraLarge : 0
        bottomLeftRadius: Tokens.rounding.extraLarge
        bottomRightRadius: Tokens.rounding.extraLarge

        HoverHandler {
            id: popoutHover
        }
    }

    BarPopouts.Wrapper {
        id: popoutsWrapper

        property real slide: hasCurrent ? 0 : 1

        screen: root.screen
        offsetScale: slide
        clip: true

        // Tlačítka uvnitř panelu si hover berou pro sebe, proto hlídání i tady, ne jen na pozadí
        HoverHandler {
            id: popoutContentHover
        }

        visible: slide < 1 && width > 0 && height > 0

        x: isDetached ? (parent.width - nonAnimWidth) / 2 : Math.max(6, Math.min(parent.width - nonAnimWidth - 6, currentCenter - nonAnimWidth / 2))
        y: isDetached ? (parent.height - nonAnimHeight) / 2 : (-implicitHeight - 5) * slide

        Behavior on slide {
            Anim {}
        }

        Behavior on x {
            enabled: popoutsWrapper.slide < 1

            Anim {}
        }

        Behavior on y {
            enabled: popoutsWrapper.isDetached

            Anim {}
        }
    }

    // Vyskakovací notifikace vpravo nahoře, jen na hlavním monitoru
    StyledRect {
        id: notifsBg

        x: notifs.x
        y: notifs.y
        width: notifs.width
        height: notifs.height
        visible: notifs.visible
        color: Colours.tPalette.m3surface
        bottomLeftRadius: Tokens.rounding.extraLarge
    }

    Notifications.Wrapper {
        id: notifs

        visible: height > 0
        screenState: root.screenState
        sidebarPanel: sidebar
        osdPanel: absentPanel
        sessionPanel: session
        utilitiesPanel: absentPanel

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Item {
        id: absentPanel
    }

    // Historie notifikací: vyjede zprava po kliknutí na zvonek
    StyledRect {
        id: sidebarBg

        x: sidebar.x
        y: sidebar.y
        width: sidebar.width
        height: sidebar.height
        visible: sidebar.visible
        opacity: sidebar.opacity
        color: Colours.tPalette.m3surface
        topLeftRadius: Tokens.rounding.extraLarge
        bottomLeftRadius: Tokens.rounding.extraLarge

        HoverHandler {
            id: sidebarBgHover
        }
    }

    Sidebar.Wrapper {
        id: sidebar

        screenState: root.screenState

        HoverHandler {
            id: sidebarContentHover
        }

        anchors.top: notifs.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    // Nabídka vypnutí
    StyledRect {
        id: sessionBg

        x: session.x
        y: session.y
        width: session.width
        height: session.height
        visible: session.visible
        opacity: session.opacity
        color: Colours.tPalette.m3surface
        topLeftRadius: Tokens.rounding.extraLarge
        bottomLeftRadius: Tokens.rounding.extraLarge
    }

    Session.Wrapper {
        id: session

        screenState: root.screenState
        sidebarVisible: sidebar.visible

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
    }
}
