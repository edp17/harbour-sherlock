import QtQuick 2.6
import Sailfish.Silica 1.0

BackgroundItem {
    id: root
    width: parent ? parent.width : Screen.width
    height: Theme.itemSizeSmall
    highlightedColor: Theme.rgba(Theme.highlightColor, 0.15)

    // modelData is a QVariantMap from engine.clues()
    property var clue: modelData
    property int n: sherlockEngine.size

    // Helper for generated icon filename for (row,item)
    function genFileName(row, item) {
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + row)
        var colNumber = item + 1
        // generated set is 01_A1..36_F6 in row-major order
        var oneBased = row * n + item + 1
        var idx2 = (oneBased < 10 ? "0" : "") + oneBased
        return idx2 + "_" + rowLetter + colNumber + ".png"
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.horizontalPageMargin
        spacing: Theme.paddingMedium

        // Left: icon
        Image {
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            fillMode: Image.PreserveAspectFit
            smooth: false

            source: (sherlockEngine.iconSource === 0)
                ? Qt.resolvedUrl("../assets/generated_icons/icons_32x32/" + genFileName(clue.row, clue.item))
                : ("image://sherlock/32/" + (clue.row * n + clue.item + 1) + "?e=" + sherlockEngine.iconEpoch)
        }

        // Middle: operator (for now “=” to mean “given here”)
        Label {
            text: "\u2192"   // arrow for “given at”
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeLarge
            verticalAlignment: Text.AlignVCenter
        }

        // Right: target location (e.g. “A3”)
        Label {
            text: String.fromCharCode("A".charCodeAt(0) + clue.row) + (clue.col + 1)
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeLarge
            verticalAlignment: Text.AlignVCenter
        }
    }

    onClicked: {
        // later: hide/disable clue, or show explanation
    }
}
