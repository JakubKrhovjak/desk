import QtQuick
import qs.components

// Položka v SortableRow: pozici určuje řádek, sousedé při přetahování plynule uhýbají.
Item {
    id: root

    required property string key
    property bool shown: true
    property real padding: 0

    readonly property bool dragged: parent?.dragged === root
    readonly property real dragOffset: dragged ? parent.dragLeft - x : 0
    property real offset: dragOffset

    visible: shown
    x: parent?.slotX(root) ?? 0
    z: dragged ? 1 : 0
    opacity: dragged ? 0.75 : 1
    anchors.verticalCenter: parent?.verticalCenter
    implicitWidth: (children[0]?.implicitWidth ?? 0) + padding * 2
    implicitHeight: children[0]?.implicitHeight ?? 0

    transform: Translate {
        x: root.offset
    }

    Behavior on x {
        enabled: !root.dragged

        Anim {}
    }

    Behavior on offset {
        enabled: !root.dragged

        Anim {}
    }
}
