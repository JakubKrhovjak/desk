import QtQuick

// Zavírání se zpožděním: dokud platí held, nic se neděje, po jeho konci se za interval spustí onTriggered.
// Myš přechází mezi plochami a okny, bez zpoždění by panel při přejezdu zmizel.
Timer {
    property bool held

    onHeldChanged: {
        if (held)
            stop();
        else
            restart();
    }
}
