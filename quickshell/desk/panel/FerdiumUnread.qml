import QtQuick
import Quickshell
import Quickshell.Io

// Počet nepřečtených zpráv z Ferdia: čte jeho rozhraní D-Bus org.ferdium.Ferdium a sleduje změny.
Scope {
    id: root

    property int direct: 0
    property int indirect: 0

    // Text odznaku: počet přímých zpráv, tečka jen u nepřímých, jinak prázdné
    readonly property string label: direct > 99 ? "99+" : direct > 0 ? String(direct) : indirect > 0 ? "•" : ""

    function parseCounts(output: string): void {
        const counts = output.split("\n").map(line => line.match(/^u (\d+)/)).filter(match => match).map(match => Number(match[1]));
        direct = counts[0] ?? 0;
        indirect = counts[1] ?? 0;
    }

    // Když Ferdium neběží, busctl nevypíše nic a odznak zmizí
    Process {
        id: reader

        command: ["busctl", "--user", "get-property", "org.ferdium.Ferdium", "/org/ferdium", "org.ferdium.Ferdium", "UnreadDirectMessageCount", "UnreadIndirectMessageCount"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCounts(text)
        }
    }

    Process {
        id: monitor

        running: true
        command: ["gdbus", "monitor", "--session", "--dest", "org.ferdium.Ferdium", "--object-path", "/org/ferdium"]
        stdout: SplitParser {
            onRead: refresh.restart()
        }
        onExited: monitorRestart.restart()
    }

    Timer {
        id: monitorRestart

        interval: 5000
        onTriggered: monitor.running = true
    }

    // Jedna změna v D-Bus vypíše víc řádků, přečte se to jen jednou
    Timer {
        id: refresh

        interval: 100
        onTriggered: reader.running = true
    }

    // Pojistka, kdyby se změna ztratila; zároveň první načtení po startu
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }
}
