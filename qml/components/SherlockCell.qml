import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: root

    property int rowIndex: 0
    property int colIndex: 0
    property bool use16px: false
    property bool magnifierEnabled: false
    signal magnifyRequested(int row, int col, int focusItem, real gx, real gy, real gw, real gh)
    readonly property bool conflicted: {
        var list = sherlockEngine.conflictCells
        if (!list || list.length === 0) return false
        var idx = rowIndex * n + colIndex
        for (var k = 0; k < list.length; ++k) {
            if (Number(list[k]) === idx) return true
        }
        return false
    }

    readonly property bool hinted: sherlockEngine.hasHint && (sherlockEngine.hintCell === (rowIndex * n + colIndex))
    readonly property bool isFocused: (rowIndex === sherlockEngine.lastTouchedRow
                                     && colIndex === sherlockEngine.lastTouchedCol)

    readonly property int n: sherlockEngine.size
    readonly property int iconBankN: 6
    readonly property int mask: {
        var list = sherlockEngine.boardMasks
        var i = rowIndex * n + colIndex
        if (!list || list.length !== n*n) return (1 << n) - 1
        return Number(list[i])
    }
    readonly property bool fixed: sherlockEngine.fixedAt(rowIndex, colIndex)
    readonly property int certainCand: {
        if (!isCertain) return -1
        for (var i = 0; i < n; ++i) {
            if ((mask & (1 << i)) !== 0) return i
        }
        return -1
    }

    // 1..n*n mapping (used by your icon naming / provider)
    readonly property int oneBasedIndex: (rowIndex * sherlockEngine.size + colIndex + 1)

    readonly property int popCount: {
        var m = root.mask
        var c = 0
        for (var i = 0; i < root.n; ++i) if (m & (1 << i)) c++
        return c
    }
    readonly property bool isCertain: (mask !== 0) && ((mask & (mask - 1)) === 0)

    readonly property int certainItem: {
        // returns 0..n-1 for the remaining bit
        for (var i = 0; i < n; ++i) {
            if ((mask & (1 << i)) !== 0)
                return i
        }
        return 0
    }

    // When certain, show the chosen item in this row.
    // When not certain, keep showing the column's default.
    readonly property int displayItem: isCertain ? certainItem : colIndex

    // Provider / filename mapping uses row-major index
    readonly property int displayOneBasedIndex: (rowIndex * iconBankN + displayItem + 1)

    function genBankFile(row, item) {
        var idx = row * iconBankN + item + 1
        var idx2 = (idx < 10 ? "0" : "") + idx
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + row)
        var colNumber = item + 1
        return idx2 + "_" + rowLetter + colNumber + ".png"
    }

    Rectangle {
        anchors.fill: parent
        color: root.hinted ? Theme.rgba("#FFC107", 0.35) : "transparent"
        border.width: root.conflicted ? 3
                     : (root.hinted ? 5
                     : (root.isCertain ? (root.fixed ? 3 : 2) : 1))
        border.color: root.conflicted ? Theme.errorColor
                    : (root.hinted ? Theme.highlightColor
                    : (root.isCertain
                        ? (root.fixed ? Theme.highlightColor
                                      : Theme.rgba(Theme.highlightColor, 0.65))
                        : Theme.rgba(Theme.primaryColor, 0.25)))
    }

    // Subtle focus ring for the last interacted cell (helps orientation on small grids)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: "transparent"
        visible: root.isFocused && !root.conflicted && !root.hinted
        border.width: 2
        border.color: Theme.rgba(Theme.highlightColor, 0.45)
        radius: Theme.paddingSmall / 2
        z: 5
    }


    // Main icon
    Image {
        id: icon

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.paddingSmall
        anchors.bottom: marksArea.top
        anchors.bottomMargin: Theme.paddingSmall

        // IMPORTANT: keep icon inside the area ABOVE the marks
        width: Math.floor(parent.width * 0.92)

        source: (sherlockEngine.iconSource === 0)
                ? Qt.resolvedUrl("../assets/generated_icons/"
                                 + (use16px ? "icons_16x16/" : "icons_32x32/")
                                 + fileNameForCell()
                                 + "?e=" + sherlockEngine.iconEpoch)
                : ("image://sherlock/" + (use16px ? "16" : "32") + "/" + displayOneBasedIndex
                   + "?e=" + sherlockEngine.iconEpoch)

        smooth: false
        cache: true
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        visible: root.isCertain
    }

    // Candidate marks overlay (1 row, n columns; fills the tile)
    Item {
        id: marksArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 0
        height: Math.floor(parent.height * 0.46)
        z: 10

        Grid {
            id: marksGrid
            anchors.fill: parent
            anchors.margins: 0
            anchors.centerIn: parent
            readonly property int cols: Math.ceil(root.n / 2)
            columns: cols
            rows: 2
            spacing: 0

            readonly property real cellSize: Math.floor(Math.min(width / cols, height / 2))

            Repeater {
                model: root.n

                Rectangle {
                    id: markCell
                    width: marksGrid.cellSize
                    height: marksGrid.cellSize
                    radius: Theme.paddingSmall / 2

                    readonly property int cand: index
                    visible: cand < root.n
                    readonly property bool isOn: visible && ((root.mask & (1 << cand)) !== 0)

                    // Visual: dim if eliminated
                    border.width: 1
                    color: markCell.isOn
                           ? Theme.rgba(Theme.highlightColor, 0.18)
                           : Theme.rgba(Theme.primaryColor, 0.00)
                    border.color: markCell.isOn
                           ? Theme.rgba(Theme.primaryColor, 0.30)
                           : Theme.rgba(Theme.primaryColor, 0.18)

                    // Candidate icon
                    Image {
                        anchors.centerIn: parent
                        width: parent.width * 0.9
                        height: width
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        cache: true
                        asynchronous: true

                        source: Qt.resolvedUrl("../assets/generated_icons/" + (use16px ? "icons_16x16/" : "icons_32x32/")
                                              + genBankFile(root.rowIndex, markCell.cand) + "?e=" + sherlockEngine.iconEpoch)

                        opacity: markCell.isOn ? 1.0 : 0.18
                        visible: true

                    }

                    // Input layer
                    BackgroundItem {
                        anchors.fill: parent
                        highlightedColor: Theme.rgba(Theme.highlightColor, 0.10)
                        enabled: !root.fixed && !sherlockEngine.solved

                        onClicked: {
                            //Start timer on first move
                            sherlockEngine.timerOnUserAction()
                            // Simple and predictable: always toggle on tap (unless fixed/solved)
                            sherlockEngine.toggleCandidate(root.rowIndex, root.colIndex, markCell.cand)
                        }

                        onPressAndHold: {
                            if (root.magnifierEnabled && !root.fixed && !sherlockEngine.solved) {
                                var p = root.mapToItem(null, 0, 0)
                                sherlockEngine.timerOnUserAction()
                                root.magnifyRequested(root.rowIndex, root.colIndex, -1, p.x, p.y, root.width, root.height)
                                return
                            }
                            sherlockEngine.timerOnUserAction()
                            if (root.fixed || sherlockEngine.solved)
                                return

                        }

                    }
                }
            }
        }
    }

    function fileNameForCell() {
        var item = certainItem
        var idx = rowIndex * iconBankN + item + 1
        var idx2 = (idx < 10 ? "0" : "") + idx
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + rowIndex)
        var colNumber = item + 1
        return idx2 + "_" + rowLetter + colNumber + ".png"
    }
}
