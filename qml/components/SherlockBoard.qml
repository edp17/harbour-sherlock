import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: root

    // Single source of truth: engine-selected board size
    property int n: sherlockEngine.size

    // Controlled by Settings (GamePage passes it in)
    property bool magnifierEnabled: false

    // Bubble from cells to GamePage
    signal magnifyRequested(int row, int col, int focusItem)

    // Board padding similar to your other apps
    readonly property real margin: Theme.horizontalPageMargin
    readonly property real gap: Theme.paddingSmall

    width: parent ? parent.width : Screen.width
    height: grid.implicitHeight + 2 * margin

    Grid {
        id: grid
        columns: n
        x: margin
        y: margin
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

                onMagnifyRequested: root.magnifyRequested(row, col, focusItem)
            }
        }
    }
}
