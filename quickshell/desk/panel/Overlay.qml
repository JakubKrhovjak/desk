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
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.nexus
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities

// Vrstva nad plochou, sahá po panel: nabídka aplikací, notifikace, nabídka vypnutí, dashboard shora a utilities v rohu.
StyledWindow {
    id: root

    required property var panelWindow

    readonly property var screenState: ShellState.forScreen(screen)
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool hasFullscreen: ShellEnv.hasFullscreen(monitor?.activeWorkspace)

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
    // Nabídka aplikací chce psaní hned po otevření; OnDemand by klávesnici předal až po kliknutí
    WlrLayershell.keyboardFocus: screenState?.launcher ? WlrKeyboardFocus.Exclusive : screenState?.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    onHasFullscreenChanged: {
        screenState.launcher = false;
        screenState.session = false;
        screenState.dashboard = false;
        screenState.utilities = false;
        popouts.close();
    }

    // Klikat jde jen na to, co je zrovna vidět; zbytek propouští myš do oken
    mask: Region {
        Region { item: dashZone }
        Region { item: launcherCatcher.visible ? launcherCatcher : null }
        Region { item: popoutBg.visible ? popoutBg : null }
        Region { item: notifsBg.visible ? notifsBg : null }
        Region { item: osdBg.visible ? osdBg : null }
        Region { item: sessionBg.visible ? sessionBg : null }
        Region { item: sidebarBg.visible ? sidebarBg : null }
        // Nad hrou na celou obrazovku by pruh bral myš aplikaci
        Region { item: root.hasFullscreen ? null : utilitiesZone }
        Region { item: utilitiesBg.visible ? utilitiesBg : null }
    }

    // Klik mimo zavře otevřený panel; horní panel zůstává klikací, aby tlačítko umělo i zavřít.
    // Nabídka aplikací tu není: má výhradní klávesnici, se kterou se grab hned zruší a nabídku by zavřel.
    HyprlandFocusGrab {
        active: (root.screenState?.session || (root.screenState?.sidebar && root.sidebarPinned)) ?? false
        windows: [root, root.panelWindow]
        onCleared: {
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

    onDashboardTriggeredChanged: {
        if (dashboardTriggered)
            dashOpen.restart();
        else
            dashOpen.stop();
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

    HoldTimer {
        id: dashClose

        held: dashHover.hovered || dashContentHover.hovered || (root.panelWindow?.dashboardHeld ?? false)
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
        width: dash.implicitWidth || root.panelWindow.dashboardWidth
        // Bez animované výšky: zmenšující se plocha by při přepnutí záložky utekla zpod myši
        height: root.screenState?.dashboard ? Math.max(dash.implicitHeight, dash.nonAnimHeight) : 0

        HoverHandler {
            id: dashHover
        }
    }

    Bubble {
        target: dash
        bottomLeftRadius: Tokens.rounding.extraLarge
        bottomRightRadius: Tokens.rounding.extraLarge
    }

    Dashboard.Wrapper {
        id: dash

        keepLoaded: true
        screenState: root.screenState

        // Tlačítka uvnitř si hover berou pro sebe, proto hlídání i tady, ne jen na ploše pod dashboardem
        HoverHandler {
            id: dashContentHover
        }

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // Klik vedle nabídky aplikací ji zavře; vrstva začíná až pod panelem, ten zůstává klikací
    MouseArea {
        id: launcherCatcher

        anchors.fill: parent
        visible: launcher.visible
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.screenState.launcher = false
    }

    // Nabídka aplikací: objeví se uprostřed obrazovky jako na Macu
    Bubble {
        id: launcherBg

        target: launcher
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

    onNotificationsHoveredChanged: {
        if (notificationsHovered && screenState && !hasFullscreen)
            screenState.sidebar = true;
    }

    HoldTimer {
        // Utilities se při otevřené historii ukazují přímo pod ní, přejezd na ně ji nesmí zavřít
        held: root.notificationsHovered || sidebarBgHover.hovered || sidebarContentHover.hovered || utilitiesBgHover.hovered || utilitiesContentHover.hovered
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

    HoldTimer {
        held: popoutHover.hovered || popoutContentHover.hovered || root.statusHover !== ""
        interval: 200
        onTriggered: {
            if (!root.popouts.isDetached && root.popouts.currentName !== "wirelesspassword")
                root.popouts.hasCurrent = false;
        }
    }

    property alias popouts: popoutsWrapper

    Bubble {
        id: popoutBg

        target: popoutsWrapper
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
    Bubble {
        id: notifsBg

        target: notifs
        bottomLeftRadius: Tokens.rounding.extraLarge
    }

    Notifications.Wrapper {
        id: notifs

        visible: height > 0
        screenState: root.screenState
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: session
        utilitiesPanel: utilities

        anchors.top: parent.top
        anchors.right: parent.right
    }

    // Ukazatel hlasitosti a jasu: při změně vyjede zprava a sám se schová
    Bubble {
        id: osdBg

        target: osdWrapper
        topLeftRadius: Tokens.rounding.extraLarge
        bottomLeftRadius: Tokens.rounding.extraLarge
    }

    Item {
        id: osdWrapper

        visible: width > 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            screenState: root.screenState
            sidebarOrSessionVisible: sidebar.visible || session.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    // Historie notifikací: vyjede zprava po kliknutí na zvonek
    Bubble {
        id: sidebarBg

        target: sidebar
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
        anchors.bottom: utilities.top
        anchors.right: parent.right
    }

    // Utilities: najetí myší do pravého dolního rohu vysune rychlé přepínače a nahrávání obrazovky
    Item {
        id: utilitiesZone

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Tokens.sizes.utilities.width
        height: 3

        HoverHandler {
            id: utilitiesZoneHover

            onHoveredChanged: {
                if (hovered && root.screenState && !root.hasFullscreen)
                    root.screenState.utilities = true;
            }
        }
    }

    HoldTimer {
        held: utilitiesZoneHover.hovered || utilitiesBgHover.hovered || utilitiesContentHover.hovered
        interval: 300
        onTriggered: {
            if (root.screenState)
                root.screenState.utilities = false;
        }
    }

    Bubble {
        id: utilitiesBg

        target: utilities
        topLeftRadius: Tokens.rounding.extraLarge

        HoverHandler {
            id: utilitiesBgHover
        }
    }

    Utilities.Wrapper {
        id: utilities

        screenState: root.screenState
        sidebar: sidebar
        popouts: popoutsWrapper

        HoverHandler {
            id: utilitiesContentHover
        }

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    // Nabídka vypnutí
    Bubble {
        id: sessionBg

        target: session
        radius: Tokens.rounding.extraLarge
    }

    Session.Wrapper {
        id: session

        screenState: root.screenState
        sidebarVisible: sidebar.visible

        anchors.centerIn: parent
    }

    // Plocha pod vyskakovacím obsahem: kryje se s ním a poloměry si určí každé použití
    component Bubble: StyledRect {
        required property Item target

        x: target.x
        y: target.y
        width: target.width
        height: target.height
        visible: target.visible
        opacity: target.opacity
        color: PanelStyle.surface
    }
}
