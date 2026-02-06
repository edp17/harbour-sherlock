import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

import "../components" as Components

Page
{
    id: page

    allowedOrientations: Orientation.All

    // Layout helpers (were accidentally removed in A3 cleanup)
    readonly property int n: sherlockEngine.size
    readonly property real margin: Theme.horizontalPageMargin
    readonly property real gap: Theme.paddingSmall

    function showNotification(text) {
        if (pageStack && pageStack.showNotification)
            pageStack.showNotification(text)
    }

    Connections {
        target: sherlockEngine
        onMessage: {
            if (pageStack && pageStack.showNotification)
                pageStack.showNotification(text)
        }
    }

    SilicaFlickable
    {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu
        {
            MenuItem {
                text: "New Game"
                onClicked: sherlockEngine.newGame()
            }
            MenuItem {
                text: "Undo"
                enabled: sherlockEngine.canUndo
                onClicked: sherlockEngine.undo()
            }
            MenuItem {
                text: "Redo"
                enabled: sherlockEngine.canRedo
                onClicked: sherlockEngine.redo()
            }
            MenuItem {
                text: "Verify"
                onClicked: sherlockEngine.verify()
            }
            MenuItem {
                text: "Reset Marks"
                onClicked: sherlockEngine.resetMarks()
            }
            MenuItem {
                text: "Hint"
                enabled: !sherlockEngine.solved
                onClicked: sherlockEngine.hint()
            }
            MenuItem {
                text: "Apply hint"
                enabled: sherlockEngine.hasHint && !sherlockEngine.solved
                onClicked: sherlockEngine.applyHint()
            }
            MenuItem {
                text: "Random puzzle"
                onClicked: sherlockEngine.startRandomPuzzle()
            }
            MenuItem {
                text: "Next bank puzzle"
                onClicked: sherlockEngine.nextBankPuzzle()
            }
            MenuItem {
                text: "Board size: 4x4"
                onClicked: sherlockEngine.setBoardSize(4)
            }
            MenuItem {
                text: "Board size: 5x5"
                onClicked: sherlockEngine.setBoardSize(5)
            }
            MenuItem {
                text: "Board size: 6x6"
                onClicked: sherlockEngine.setBoardSize(6)
            }
            MenuItem {
                text: "Reveal Solution (debug)"
                onClicked: sherlockEngine.revealSolution()
            }
//            MenuItem {
//                text: "Use Generated Icons"
//                onClicked: sherlockEngine.iconSource = 0   // Generated
//                onClicked: sherlockEngine.iconSource = sherlockEngine.Generated
//            }
//            MenuItem {
//                text: "Import sherlock.shi"
//                onClicked: {
//                    var p = pageStack.push(pickerPage)
//                    p.selectedContentChanged.connect(function() {
//                        if (p.selectedContent && p.selectedContent.length > 0) {
//                            // file:// URL -> local path
//                            var url = p.selectedContent[0].url
//                            var path = url.toString().replace("file://", "")
//                            sherlockEngine.importSherlockShi(path)
//                        }
//                        pageStack.pop()
//                    })
//                }
//            }
//            MenuItem {
//                text: "Show Data Dir"
//                onClicked: page.showNotification(sherlockEngine.dataDir)
//            }
//            MenuItem {
//                text: "Icon Gallery"
//                onClicked: pageStack.push(Qt.resolvedUrl("IconGalleryPage.qml"))
//            }
//            MenuItem {
//                text: "Use Original (SHI) Icons"
//                onClicked: sherlockEngine.iconSource = 1   // Shi
//                onClicked: sherlockEngine.iconSource = sherlockEngine.Shi
//                enabled: sherlockEngine.hasImportedImages
//            }
        }

        Column
        {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader { title: "Sherlock" }

            Label {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: page.margin
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: (sherlockEngine.puzzleSource === sherlockEngine.PUZZLE_BANK()
                       ? ("Bank #" + (sherlockEngine.puzzleId + 1) + "/" + sherlockEngine.bankCount()
                          + "  (" + sherlockEngine.size + "×" + sherlockEngine.size + ")")
                       : ("Seed " + sherlockEngine.puzzleSeed
                          + "  (" + sherlockEngine.size + "×" + sherlockEngine.size + ")"))
            }

            Label {
                visible: sherlockEngine.solved
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: page.margin
                text: "Solved!"
                color: Theme.highlightColor
                font.bold: true
            }

            Label
            {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: page.margin

                wrapMode: Text.WordWrap
                text: sherlockEngine.size + "×" + sherlockEngine.size +
                      " deduction board. Tap toggles a candidate. Long-press sets a certain candidate.\nImported images: " +
                      (sherlockEngine.hasImportedImages ? "yes" : "no (placeholders)")
            }

            // --- Docked clue panels (DOS-like layout) ---
            // Board
            Components.SherlockBoard {
                id: board
                width: parent.width
            }

            // Clues under the board (Semantic DOS-style clues)
            // Uses sherlockEngine.dosClueGroups (groups: orient/index/clues; clue: type/a/b/index/given)
            SectionHeader { text: "Clues" }

            Column {
                id: cluePanel
                width: parent.width
                spacing: Theme.paddingSmall

                readonly property int clueStripH: (iconPx + clueGap) * (sherlockEngine.size - 1) + Theme.paddingLarge

                readonly property int iconPx: Math.floor(Theme.iconSizeSmall * 0.70)
                readonly property int clueGap: Math.max(1, Math.floor(Theme.paddingSmall * 0.45))

                readonly property color stripBg: Theme.rgba(Theme.primaryColor, 0.04)
                readonly property color stripBorder: Theme.rgba(Theme.primaryColor, 0.20)
                readonly property color stripBgAlt: Theme.rgba(Theme.primaryColor, 0.02)
                readonly property color textCol: Theme.primaryColor

// DOS monochrome mode
//readonly property color stripBg: Theme.rgba(Theme.primaryColor, 0.02)
//readonly property color stripBorder: Theme.rgba(Theme.primaryColor, 0.35)
//readonly property color stripBgAlt: Theme.rgba(Theme.primaryColor, 0.00)
//readonly property color textCol: Theme.primaryColor

                readonly property int iconBankN: 6

                function genBankFile(row, item) {
                    var idx = row * iconBankN + item + 1
                    var idx2 = (idx < 10 ? "0" : "") + idx
                    var rowLetter = String.fromCharCode("A".charCodeAt(0) + row)
                    var colNumber = item + 1
                    return idx2 + "_" + rowLetter + colNumber + ".png"
                }

                function genIconFileName(row, item) {
                    var n = Number(sherlockEngine.size)
                    var rr = Number(row)
                    var ii = Number(item)
                    if (!isFinite(n) || !isFinite(rr) || !isFinite(ii) || n <= 0) return ""

                    var idx = rr * n + ii + 1
                    var idx2 = (idx < 10 ? "0" : "") + idx
                    var rowLetter = String.fromCharCode("A".charCodeAt(0) + rr)
                    var colNumber = ii + 1
                    return idx2 + "_" + rowLetter + colNumber + ".png"
                }

                function iconSourceFor(row, item) {
                    var rr = Number(row)
                    var ii = Number(item)
                    if (!isFinite(rr) || !isFinite(ii)) return ""

                    if (sherlockEngine.iconSource === 0) {
                        var fn = genIconFileName(rr, ii)
                        if (fn === "") return ""
                        return Qt.resolvedUrl("../assets/generated_icons/icons_32x32/" + fn) + "?e=" + sherlockEngine.iconEpoch
                    }

                    return "image://sherlock/r" + rr + "_i" + ii + "?e=" + sherlockEngine.iconEpoch
                }

                function arrowForType(t) {
                    t = Number(t)
                    if (t === 1) return "\u2192" // LeftOf
                    if (t === 2) return "\u2191" // Above
                    return "?"
                }

                // Top: vertical semantic clues
                Flickable {
                    id: verticalClues
                    width: parent.width
                    height: cluePanel.clueStripH
                    clip: true
                    contentWidth: vRow.width
                    contentHeight: vRow.height

                    Row {
                        id: vRow
                        spacing: cluePanel.clueGap

                        Repeater {
                            model: sherlockEngine.dosClueGroups
                            delegate: Rectangle {
                                visible: (Number(modelData.orient) === 0)
                                width: cluePanel.iconPx * 3 + Theme.paddingLarge// * 2
                                height: cluePanel.clueStripH
                                radius: 0
                                color: (modelData.index % 2 === 0) ? cluePanel.stripBg : cluePanel.stripBgAlt
                                border.width: 1
                                border.color: cluePanel.stripBorder

                                Column {
                                    anchors.centerIn: parent
                                    spacing: cluePanel.clueGap

                                    Repeater {
                                        model: visible ? modelData.clues : []
                                        delegate: Row {
                                            spacing: Theme.paddingSmall

                                            Image {
                                                width: cluePanel.iconPx
                                                height: cluePanel.iconPx
                                                sourceSize.width: cluePanel.iconPx
                                                sourceSize.height: cluePanel.iconPx

                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true
                                                smooth: false
                                                mipmap: false
                                                visible: source !== ""
                                                source: cluePanel.iconSourceFor(modelData.aRow, modelData.a)
                                            }

                                            Label {
                                                text: cluePanel.arrowForType(modelData.type)
                                                font.pixelSize: Theme.fontSizeTiny
                                                font.bold: true
                                                color: cluePanel.textCol
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Image {
                                                width: cluePanel.iconPx
                                                height: cluePanel.iconPx
                                                sourceSize.width: cluePanel.iconPx
                                                sourceSize.height: cluePanel.iconPx

                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true
                                                smooth: false
                                                mipmap: false
                                                visible: source !== ""
                                                source: cluePanel.iconSourceFor(modelData.bRow, modelData.b)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                }

                // Bottom: horizontal semantic clues
                Flickable {
                    id: horizontalClues
                    width: parent.width
                    height: cluePanel.clueStripH
                    clip: true
                    contentWidth: hRow.width
                    contentHeight: hRow.height

                    Row {
                        id: hRow
                        spacing: cluePanel.clueGap

                        Repeater {
                            model: sherlockEngine.dosClueGroups
                            delegate: Rectangle {
                                visible: (Number(modelData.orient) === 1)
                                width: cluePanel.iconPx * 3 + Theme.paddingLarge// * 2
                                height: cluePanel.clueStripH
                                radius: 0
                                color: (modelData.index % 2 === 0) ? cluePanel.stripBg : cluePanel.stripBgAlt
                                border.width: 1
                                border.color: cluePanel.stripBorder

                                Column {
                                    anchors.centerIn: parent
                                    spacing: cluePanel.clueGap

                                    Repeater {
                                        model: visible ? modelData.clues : []
                                        delegate: Row {
                                            spacing: cluePanel.clueGap

                                            Image {
                                                width: cluePanel.iconPx
                                                height: cluePanel.iconPx
                                                sourceSize.width: cluePanel.iconPx
                                                sourceSize.height: cluePanel.iconPx
                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true
                                                smooth: false
                                                mipmap: false
                                                visible: source !== ""
                                                source: cluePanel.iconSourceFor(modelData.aRow, modelData.a)
                                            }

                                            Label {
                                                text: cluePanel.arrowForType(modelData.type)   // should be →
                                                font.pixelSize: Theme.fontSizeTiny
                                                font.bold: true
                                                color: cluePanel.textCol
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Image {
                                                width: cluePanel.iconPx
                                                height: cluePanel.iconPx
                                                sourceSize.width: cluePanel.iconPx
                                                sourceSize.height: cluePanel.iconPx
                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true
                                                smooth: false
                                                mipmap: false
                                                visible: source !== ""
                                                source: cluePanel.iconSourceFor(modelData.bRow, modelData.b)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component
    {
        id: pickerPage
        FilePickerPage {
            title: "Select sherlock.shi"
            nameFilters: [ "*.shi", "*.*" ]
        }
    }
}
