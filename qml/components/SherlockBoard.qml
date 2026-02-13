import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: root

    // Single source of truth: engine-selected board size
    property int n: sherlockEngine.size

    // Controlled by Settings (GamePage passes it in)
    property bool magnifierEnabled: false

    // Bubble from cells to GamePage
    signal magnifyRequested(int row, int col, int focusItem, real gx, real gy, real gw, real gh)

    // Board padding similar to your other apps
    readonly property real margin: 0
    readonly property real gap: Theme.paddingSmall

    width: parent ? parent.width : Screen.width
    height: grid.implicitHeight

    Grid {
        id: grid
        columns: n
        x: 0
        y: 0
        spacing: gap

        readonly property real cellSize: Math.floor((root.width - 2*root.margin - (n-1)*root.gap) / n)

        Repeater {
            model: n * n

            SherlockCell {
                width: grid.cellSize
                height: grid.cellSize

                // 0..(n*n-1)
                property int row: Math.floor(index / n)
                property int col: index % n

                rowIndex: row
                colIndex: col

                magnifierEnabled: root.magnifierEnabled

                onMagnifyRequested: root.magnifyRequested(row, col, focusItem, gx, gy, gw, gh)
            }
        }
    }
}
