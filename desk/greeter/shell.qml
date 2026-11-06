pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Wayland

// Přihlašovací obrazovka prostředí desk ve stylu jeho zamykací obrazovky.
// Běží pod uživatelem greeter, proto je samostatná: vše potřebné je v /usr/share/desk-greeter (desk/greeter/install.sh).
ShellRoot {
    id: root

    readonly property var settings: JSON.parse(settingsFile.text())
    readonly property var colours: settings.colours

    property bool busy: false
    property string message: ""
    property string username: settings.user
    property string password: ""
    signal passwordCleared

    function colour(name: string): color {
        return `#${colours[name]}`;
    }

    function logIn(): void {
        if (busy || username.length === 0)
            return;
        busy = true;
        message = "";
        Greetd.createSession(username);
    }

    function fail(text: string): void {
        message = text;
        password = "";
        busy = false;
        passwordCleared();
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
    }

    FileView {
        id: settingsFile

        path: Quickshell.shellPath("settings.json")
        blockLoading: true
    }

    Connections {
        target: Greetd

        function onAuthMessage(text: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired)
                Greetd.respond(root.password);
            else if (error)
                root.message = text;
        }

        function onAuthFailure(text: string): void {
            root.fail("Wrong password");
        }

        function onError(text: string): void {
            root.fail(text);
        }

        function onReadyToLaunch(): void {
            Greetd.launch(root.settings.command);
        }
    }

    Process {
        id: powerAction
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: surface

            required property ShellScreen modelData
            // Přihlášení jen na hlavním monitoru, ostatní ukazují tapetu
            readonly property bool isMain: modelData.name === root.settings.main || !Quickshell.screens.some(screen => screen.name === root.settings.main) && modelData === Quickshell.screens[0]

            screen: modelData
            color: root.colour("surface")
            WlrLayershell.namespace: "desk-greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: isMain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("wallpaper.jpg")
                sourceSize.width: surface.width
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(root.colour("surface"), 0.45)
            }

            SystemClock {
                id: clock

                precision: SystemClock.Minutes
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: surface.isMain
                spacing: 18

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    Text {
                        text: Qt.formatTime(clock.date, "HH")
                        color: root.colour("primary")
                        font.family: "Rubik"
                        font.weight: Font.Bold
                        font.pixelSize: 120
                    }

                    Text {
                        text: Qt.formatTime(clock.date, "mm")
                        color: root.colour("secondary")
                        font.family: "Rubik"
                        font.weight: Font.Bold
                        font.pixelSize: 120
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(clock.date, "dddd • d MMM").toUpperCase()
                    color: root.colour("onSurface")
                    font.family: "Rubik"
                    font.weight: Font.DemiBold
                    font.pixelSize: 20
                }

                Item {
                    implicitHeight: 28
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 112
                    implicitHeight: 112
                    radius: 36
                    color: root.colour("surfaceContainer")

                    Text {
                        anchors.centerIn: parent
                        text: "person"
                        color: root.colour("onSurfaceVariant")
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 64
                    }
                }

                TextInput {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 340
                    horizontalAlignment: TextInput.AlignHCenter
                    text: root.username
                    color: root.colour("onSurface")
                    selectionColor: root.colour("primary")
                    selectedTextColor: root.colour("onPrimary")
                    font.family: "Rubik"
                    font.pixelSize: 18
                    activeFocusOnTab: true
                    enabled: !root.busy
                    onTextEdited: root.username = text
                    onAccepted: passwordInput.forceActiveFocus()
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 340
                    implicitHeight: 52
                    radius: height / 2
                    color: Qt.alpha(root.colour("surfaceContainer"), 0.9)
                    border.width: root.message.length > 0 ? 2 : passwordInput.activeFocus ? 1 : 0
                    border.color: root.message.length > 0 ? root.colour("error") : root.colour("primary")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text.length === 0
                        text: "Password"
                        color: root.colour("onSurfaceVariant")
                        font.family: "Rubik"
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: passwordInput

                        anchors.left: parent.left
                        anchors.right: enterButton.left
                        anchors.leftMargin: 24
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: root.colour("onSurface")
                        selectionColor: root.colour("primary")
                        selectedTextColor: root.colour("onPrimary")
                        font.family: "Rubik"
                        font.pixelSize: 18
                        activeFocusOnTab: true
                        enabled: !root.busy
                        focus: surface.isMain
                        onTextEdited: {
                            root.password = text;
                            root.message = "";
                        }
                        onAccepted: root.logIn()
                        Keys.onEscapePressed: {
                            clear();
                            root.password = "";
                        }

                        Connections {
                            target: root

                            function onPasswordCleared(): void {
                                passwordInput.clear();
                                passwordInput.forceActiveFocus();
                            }
                        }

                        Component.onCompleted: if (surface.isMain) forceActiveFocus()
                    }

                    MouseArea {
                        id: enterButton

                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.logIn()

                        Text {
                            anchors.centerIn: parent
                            text: root.busy ? "hourglass_empty" : "arrow_forward"
                            color: root.colour("primary")
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 24
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 20
                    text: root.message
                    color: root.colour("error")
                    font.family: "Rubik"
                    font.pixelSize: 14
                }
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24
                spacing: 8
                visible: surface.isMain

                Repeater {
                    model: [
                        { icon: "restart_alt", command: ["systemctl", "reboot"], colour: "secondary" },
                        { icon: "power_settings_new", command: ["systemctl", "poweroff"], colour: "error" }
                    ]

                    MouseArea {
                        id: powerButton

                        required property var modelData

                        width: 48
                        height: 48
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerAction.command = modelData.command;
                            powerAction.running = true;
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.alpha(root.colour("surfaceContainer"), powerButton.containsMouse ? 1 : 0.7)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: powerButton.modelData.icon
                            color: root.colour(powerButton.modelData.colour)
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 24
                        }
                    }
                }
            }
        }
    }
}
