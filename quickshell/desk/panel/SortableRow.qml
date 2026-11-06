import QtQuick
import qs.components
import qs.services

// Vodorovný řádek položek SortItem, které jde přeuspořádat tažením myší.
// Pořadí se ukládá do souboru, takže ho sdílí panely na všech monitorech a přežije restart.
Item {
    id: root

    required property string orderFile
    property real spacing: 2

    property var order: []
    property Item dragged: null
    property real grabOffset: 0

    readonly property bool dragging: dragged !== null
    readonly property real dragLeft: Math.max(0, Math.min(width - (dragged?.width ?? 0), dragHandler.centroid.position.x - grabOffset))
    readonly property var items: Array.from(children).filter(child => child.key !== undefined)
    readonly property var sorted: {
        const rank = item => {
            const index = order.indexOf(item.key);
            return index < 0 ? order.length + items.indexOf(item) : index;
        };
        return [...items].sort((a, b) => rank(a) - rank(b));
    }
    readonly property var shownItems: sorted.filter(item => item.shown)

    function slotX(item: Item): real {
        return shownItems.slice(0, shownItems.indexOf(item)).reduce((sum, other) => sum + other.implicitWidth + spacing, 0);
    }

    // Levé okraje položek, jako by přetahovaná v řádku nebyla
    function packedLefts(others: var): var {
        return others.reduce((lefts, other, index) => [...lefts, index === 0 ? 0 : lefts[index - 1] + others[index - 1].implicitWidth + spacing], []);
    }

    // Přetahovaná položka přeskočí souseda, když její střed mine střed mezi oběma možnými pozicemi
    function reorder(): void {
        const others = sorted.filter(item => item !== dragged);
        const shownOthers = others.filter(item => item.shown);
        const lefts = packedLefts(shownOthers);
        const size = dragged.implicitWidth;
        const center = dragLeft + size / 2;
        const passed = shownOthers.filter((item, index) => center > lefts[index] + (item.implicitWidth + size) / 2).length;
        const insertAt = passed > 0 ? others.indexOf(shownOthers[passed - 1]) + 1 : 0;
        const next = [...others.slice(0, insertAt), dragged, ...others.slice(insertAt)].map(item => item.key);
        if (next.join() !== sorted.map(item => item.key).join())
            order = next;
    }

    implicitWidth: shownItems.reduce((sum, item) => sum + item.implicitWidth, 0) + Math.max(0, shownItems.length - 1) * spacing
    implicitHeight: DeskPanelSettings.buttonSize

    onDragLeftChanged: {
        if (dragging)
            reorder();
    }

    DragHandler {
        id: dragHandler

        target: null
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                const pressX = centroid.pressPosition.x;
                const item = root.shownItems.find(candidate => pressX >= candidate.x && pressX <= candidate.x + candidate.width) ?? null;
                root.grabOffset = item ? pressX - item.x : 0;
                root.dragged = item;
            } else if (root.dragged) {
                root.dragged = null;
                orderStore.save(root.sorted.map(item => item.key));
            }
        }
    }

    JsonFile {
        id: orderStore

        path: root.orderFile
        onValueLoaded: {
            if (!root.dragging && Array.isArray(value))
                root.order = value;
        }
    }
}
