import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    // Expect you already expose sherlockEngine as a context property in your app root.
    // If it’s instead passed in, you can add: property var sherlockEngine

    function genIconFileName(row, item) {
        var baseN = 6
        var rr = Number(row)
        var ii = Number(item)
        if (!isFinite(rr) || !isFinite(ii)) return ""
        rr = Math.max(0, Math.min(baseN - 1, rr))
        ii = Math.max(0, Math.min(baseN - 1, ii))
        var idx = rr * baseN + ii + 1
        var idx2 = (idx < 10 ? "0" : "") + idx
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + rr)
        var colNumber = ii + 1
        return idx2 + "_" + rowLetter + colNumber + ".png"
    }

    function iconSourceFor(row, item) {
        var rr = Number(row)
        var ii = Number(item)
        if (!isFinite(rr) || !isFinite(ii)) return ""

        // sherlockEngine.iconSource: 0 = generated icons, else image provider
        if (sherlockEngine && sherlockEngine.iconSource === 0) {
            var fn = genIconFileName(rr, ii)
            if (fn === "") return ""
            return Qt.resolvedUrl("../assets/generated_icons/icons_32x32/" + fn) + "?e=" + sherlockEngine.iconEpoch
        }

        // Uses your C++ image provider naming from GamePage.qml :contentReference[oaicite:1]{index=1}
        return "image://sherlock/r" + rr + "_i" + ii + "?e=" + (sherlockEngine ? sherlockEngine.iconEpoch : 0)
    }

    function arrowForType(t) {
        t = Number(t)
        if (t === 1) return "\u2192" // LeftOf :contentReference[oaicite:2]{index=2}
        if (t === 2) return "\u2191" // Above :contentReference[oaicite:3]{index=3}
        return "\u2192"
    }

    Component {
        id: bulletRow
        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            Rectangle {
                width: Theme.paddingLarge
                height: Theme.paddingLarge
                radius: Theme.paddingSmall
                color: Theme.highlightBackgroundColor
            }

            Label {
                width: parent.width - Theme.horizontalPageMargin * 2 - Theme.paddingLarge - Theme.paddingMedium
                wrapMode: Text.WordWrap
                text: modelData
            }
        }
    }

    Component {
        id: exampleClueRow

        Item {
            id: wrapper
            width: parent ? parent.width : page.width

            // Give it a real height (writable), so Loader can reserve space.
            height: Math.max(leftIcon.height, rightIcon.height, arrowLabel.implicitHeight, descLabel.implicitHeight)

            Row {
                id: row
                width: parent.width
                spacing: Theme.paddingMedium

                Image {
                    id: leftIcon
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    source: iconSourceFor(0, 0)
                }

                Label {
                    id: arrowLabel
                    text: arrowForType(1)
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Image {
                    id: rightIcon
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    source: iconSourceFor(0, 1)
                }

                Label {
                    id: descLabel
                    width: Math.max(0,
                                    parent.width
                                    - (Theme.iconSizeMedium * 2)
                                    - (Theme.paddingMedium * 2)
                                    - Theme.fontSizeLarge)
                    text: "means: left item is left of right item"
                    wrapMode: Text.WordWrap
                    color: Theme.secondaryColor
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

function midTextForRulesExample(type, index1based) {
    if (type === 1) return "\u2192" // LeftOf
    if (type === 2) return "\u2191" // Above
    if (type === 8) return "" + index1based        // IsInCol/IsInRow (displayed as number only)
    if (type === 10) return "\u2260 " + index1based // NotInCol/NotInRow (≠ N)
    return "?"
}

Component {
    id: exampleArrowClueRow

    Item {
        width: parent ? parent.width : page.width
        height: Math.max(leftIcon.height, rightIcon.height, midLabel.implicitHeight, descLabel.implicitHeight)

        Row {
            id: row
            width: parent.width
            spacing: Theme.paddingMedium

            Image {
                id: leftIcon
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: false
                source: iconSourceFor(0, 0)
            }

            Label {
                id: midLabel
                text: midTextForRulesExample(1, 0) // →
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            Image {
                id: rightIcon
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: false
                source: iconSourceFor(0, 1)
            }

            Label {
                id: descLabel
                width: Math.max(0, parent.width - (Theme.iconSizeMedium * 2) - Theme.paddingMedium * 2 - Theme.fontSizeLarge)
                text: "means: left icon is left of right icon"
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}

Component {
    id: examplePlacementClueRow

    // parameterized via properties set by Loader
    Item {
        id: wrapper
        width: parent ? parent.width : page.width

        property int type: 8              // 8=IsInCol/IsInRow, 10=NotInCol/NotInRow
        property int index1based: 3
        property string description: ""

        height: Math.max(icon.height, mid.implicitHeight, desc.implicitHeight)

        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            Image {
                id: icon
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: false
                source: iconSourceFor(0, 0)
            }

            Label {
                id: mid
                text: midTextForRulesExample(wrapper.type, wrapper.index1based)
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            Label {
                id: desc
                width: Math.max(0, parent.width - Theme.iconSizeMedium - Theme.paddingMedium * 2 - Theme.fontSizeLarge)
                text: wrapper.description
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}

    SilicaFlickable {
        anchors.fill: parent

        contentHeight: contentColumn.height

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader { title: "Game rules" }

            // Keep left/right margins consistent with Silica pages
            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingLarge

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Goal: determine the correct item in every cell. Each cell ends with exactly one certain item."
                }

                SectionHeader { text: "Marking" }

                Repeater {
                    model: [
                        "Tap candidates to toggle them on/off.",
                        "Set a cell to a single certain item (the cell shows a large icon).",
                        "Givens are locked and cannot be changed.",
                        "Undo/Redo restores your previous states (including across restart)."
                    ]
                    delegate: bulletRow
                }

                SectionHeader { text: "Magnifier" }

                Repeater {
                    model: [
                        "Long-press anywhere inside a cell to open the magnifier popup.",
                        "You can disable the magnifier in Settings."
                    ]
                    delegate: bulletRow
                }

SectionHeader { text: "Clues" }

Label {
    width: parent.width
    wrapMode: Text.WordWrap
    text: "Clues describe relationships between icons. Clues are shown in DOS-style stripes:"
}

Repeater {
    model: [
        "Vertical stripes are column clues. The number refers to a column (1.." + (sherlockEngine ? sherlockEngine.size : 6) + ").",
        "Horizontal stripes are row clues. The number refers to a row (1.." + (sherlockEngine ? sherlockEngine.size : 6) + ").",
        "Arrows show relative position: → (left of) and ↑ (above)."
    ]
    delegate: bulletRow
}

// Example: pairwise arrow clue
Loader {
    width: parent.width
    sourceComponent: exampleArrowClueRow
    height: item ? item.height : 0
}

// Example: placement clue (number only)
Loader {
    width: parent.width
    sourceComponent: examplePlacementClueRow
    height: item ? item.height : 0
    onLoaded: {
        item.type = 8
        item.index1based = 3
        item.description = "means: this icon is in column/row 3 (stripe orientation tells which)"
    }
}

// Example: negative placement clue (≠ number)
Loader {
    width: parent.width
    sourceComponent: examplePlacementClueRow
    height: item ? item.height : 0
    onLoaded: {
        item.type = 10
        item.index1based = 3
        item.description = "means: this icon is NOT in column/row 3 (stripe orientation tells which)"
    }
}

                SectionHeader { text: "Timer & score" }

                Repeater {
                    model: [
                        "The timer starts on your first action and persists across restart.",
                        "When solved, your time is recorded on the Scores page."
                    ]
                    delegate: bulletRow
                }

                Item { width: 1; height: Theme.paddingLarge }
            }
        }

        VerticalScrollDecorator { }
    }
}
