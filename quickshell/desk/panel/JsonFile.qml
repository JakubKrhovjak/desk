import QtQuick
import Quickshell.Io

// JSON soubor se stavem panelu, sledovaný kvůli změnám zvenčí. Chybějící soubor není chyba, poškozený se ohlásí.
FileView {
    id: root

    signal valueLoaded(value: var)

    function save(value: var): void {
        setText(JSON.stringify(value));
    }

    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
        try {
            root.valueLoaded(JSON.parse(text()));
        } catch (error) {
            console.warn(`desk: invalid file ${root.path}:`, error);
        }
    }
}
