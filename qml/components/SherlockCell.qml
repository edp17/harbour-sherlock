import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: root

    property int rowIndex: 0
    property int colIndex: 0
    property bool use16px: false

    readonly property int n: sherlockEngine.size
    readonly property int mask: {
        var list = sherlockEngine.boardMasks
        var i = rowIndex * n + colIndex
        if (!list || list.length !== n*n) return (1 << n) - 1
        return Number(list[i])
    }
    readonly property bool isCertainCell: (mask & (mask - 1)) === 0
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
    readonly property bool isCertain: (mask & (mask - 1)) === 0

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
    readonly property int displayOneBasedIndex: (rowIndex * n + displayItem + 1)

    // 1..n*n index of the icon to show in the BIG area
    readonly property int displayIconIndex: {
        // Map (rowIndex, item) -> 1-based icon id
        var item = isCertain ? certainItem : colIndex   // choose what you want for non-certain
        return rowIndex * root.n + item + 1
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.isCertain ? 2 : 1
        border.color: root.isCertain
                      ? Theme.rgba(Theme.highlightColor, 0.65)
                      : Theme.rgba(Theme.primaryColor, 0.25)
        }

    // Main icon
    Image {
        id: icon

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.paddingSmall

        // IMPORTANT: keep icon inside the area ABOVE the marks
        width: Math.floor(parent.width * 0.82)
        height: Math.floor((parent.height - marksArea.height - 2*Theme.paddingSmall) * 0.92)

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
    }

    Rectangle {
        visible: root.isCertain && root.certainCand >= 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.paddingSmall
        anchors.topMargin: Theme.paddingSmall
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.highlightColor, 0.85)

        width: badgeLabel.implicitWidth + Theme.paddingSmall * 2
        height: badgeLabel.implicitHeight + Theme.paddingSmall

        Label {
            id: badgeLabel
            anchors.centerIn: parent
            text: (root.certainCand + 1) // 1..n
            color: Theme.highlightColor // or Theme.primaryColor if you prefer contrast
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
    }

    // Candidate marks overlay (2 rows, ceil(n/2) columns)
    Item {
        id: marksArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.floor(parent.height * 0.36)
        anchors.margins: Theme.paddingSmall
        z: 10

        // Slight background so you can clearly see the overlay exists
        Rectangle {
            anchors.fill: parent
            radius: Theme.paddingSmall
            color: Theme.rgba(Theme.primaryColor, 0.06)
            border.width: 1
            border.color: Theme.rgba(Theme.primaryColor, 0.12)
            opacity: root.fixed ? 0.5 : 1.0
        }

        Grid {
            id: marksGrid
            anchors.centerIn: parent
            columns: Math.ceil(root.n / 2)
            spacing: Theme.paddingSmall

            readonly property real cellSize: Math.floor(
                Math.min(
                    (marksArea.width  - (columns - 1) * spacing) / columns,
                    (marksArea.height - (2 - 1) * spacing) / 2
                )
            )

            Repeater {
                model: root.n  // only real candidates, no dummy cells

                Rectangle {
                    id: markCell
                    width: marksGrid.cellSize
                    height: marksGrid.cellSize
                    radius: Theme.paddingSmall / 2

                    readonly property int cand: index
                    readonly property bool isOn: (root.mask & (1 << cand)) !== 0

                    color: markCell.isOn
                           ? Theme.rgba(Theme.highlightColor, 0.40)
                           : Theme.rgba(Theme.primaryColor, 0.02)

                    border.width: 1
                    border.color: Theme.rgba(Theme.primaryColor, 0.35)

                    BackgroundItem {
                        anchors.fill: parent
                        highlightedColor: "transparent"
                        enabled: !root.fixed

                        onClicked: {
                            // If not certain yet -> toggle normally
                            if (!root.isCertainCell) {
                                sherlockEngine.toggleCandidate(root.rowIndex, root.colIndex, markCell.cand)
                                return
                            }

                            // If the cell is already certain -> only allow clicking the "on" mark
                            // so setCertain() can undo/reset (your engine supports this)
                            if (markCell.isOn) {
                                sherlockEngine.setCertain(root.rowIndex, root.colIndex, markCell.cand)
                            }
                        }

                        onPressAndHold: {
                            if (!root.fixed)
                                sherlockEngine.setCertain(root.rowIndex, root.colIndex, markCell.cand)
                        }
                    }
                }
            }
        }
    }

    function fileNameForCell() {
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + rowIndex)
        var colNumber = displayItem + 1
        var idx2 = (displayOneBasedIndex < 10 ? "0" : "") + displayOneBasedIndex
        return idx2 + "_" + rowLetter + colNumber + ".png"
    }

    function fileNameForIndex(oneBased) {
        if (oneBased <= 0) return "00_blank.png"
        var idx2 = (oneBased < 10 ? "0" : "") + oneBased
        var r = Math.floor((oneBased - 1) / root.n)
        var c = (oneBased - 1) % root.n
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + r)
        var colNumber = c + 1
    }
}
