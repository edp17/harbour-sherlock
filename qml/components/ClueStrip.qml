import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: root

    // Expecting engine clue maps: { type, row, col, item }
    // type: currently 0 = Given
    property var clue: ({})
    property int n: sherlockEngine.size
    property int iconPx: Theme.iconSizeMedium
    property int epoch: sherlockEngine.iconEpoch

    height: Math.max(iconPx, Theme.itemSizeSmall)
    width: parent ? parent.width : Screen.width

    // Display size (theme), but provider must be 16/32
    readonly property int iconDisplayPx: Theme.iconSizeMedium
    readonly property int iconProviderPx: (iconDisplayPx <= 20 ? 16 : 32)

    function rowLetter(r) {
        return String.fromCharCode("A".charCodeAt(0) + r)
    }

    function posLabel(r, c) {
        return rowLetter(r) + (c + 1)
    }

    function iconOneBasedIndex(r, item) {
        // icon set is row-major: (row * n + item) + 1
        return (r * n + item + 1)
    }

    function iconSourceForClue() {
        if (!clue) return ""

        var r = Number(clue.row)
        var it = Number(clue.item)
        if (isNaN(r) || isNaN(it)) return ""

        // Use the explicit row/item form (provider parses this reliably)
        return "image://sherlock/"
                + iconProviderPx
                + "/r" + r + "_i" + it
                + "?e=" + sherlockEngine.iconEpoch
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.horizontalPageMargin
        anchors.rightMargin: Theme.horizontalPageMargin
        spacing: Theme.paddingMedium

        Image {
            id: icon
            width: iconDisplayPx
            height: iconDisplayPx
            fillMode: Image.PreserveAspectFit
            smooth: false
            source: iconSourceForClue()
        }

        Label {
            // simple arrow; swap to an Icon later if you want
            text: "\u2192"
            verticalAlignment: Text.AlignVCenter
            height: parent.height
            color: Theme.secondaryColor
        }

        Label {
            verticalAlignment: Text.AlignVCenter
            height: parent.height
            color: Theme.primaryColor

            text: {
                if (!root.clue || root.clue.row === undefined || root.clue.col === undefined)
                    return ""

                var r = Number(root.clue.row)
                var c = Number(root.clue.col)
                if (isNaN(r) || isNaN(c) || r < 0 || c < 0 || r >= n || c >= n)
                    return ""

                // “A1-style position”
                return posLabel(r, c)
            }
        }
    }
}
