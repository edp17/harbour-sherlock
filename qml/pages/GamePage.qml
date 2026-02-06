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
//                text: (sherlockEngine.puzzleSource === sherlockEngine.PUZZLE_BANK()
//                       ? ("Bank #" + sherlockEngine.puzzleId + "  (" + sherlockEngine.size + "×" + sherlockEngine.size + ")")
//                       : ("Seed " + sherlockEngine.puzzleSeed + "  (" + sherlockEngine.size + "×" + sherlockEngine.size + ")"))
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

            SectionHeader { text: "Clues" }

            // --- Clues panel (DOS-like): vertical groups above, horizontal groups below ---
            Column {
                id: cluePanel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: page.margin



                spacing: Theme.paddingMedium

                // Direct binding: updates automatically when SherlockEngine emits clueGroupsChanged
                readonly property var groups: sherlockEngine.clueGroups || []

                function vGroup(col) {
                    return (groups && groups.length > col) ? groups[col] : null
                }

                function hGroup(row) {
                    var i = page.n + row
                    return (groups && groups.length > i) ? groups[i] : null
                }

                // --- VERTICAL CLUES (top): n columns aligned under the board ---
                Column {
                    width: parent.width
                    spacing: page.gap

                    Grid {
                        id: vGrid
                        width: parent.width
                        columns: page.n
                        spacing: page.gap

                        readonly property real colW: Math.floor((width - (columns - 1) * spacing) / columns)

                        Repeater {
                            model: page.n   // columns 0..n-1

                            Column {
                                width: vGrid.colW
                                spacing: page.gap

                                readonly property var g: cluePanel.vGroup(index)

                                Repeater {
                                    model: (g && g.clues) ? g.clues : []

                                    Item {
                                        width: vGrid.colW
                                        height: clueStrip.implicitHeight
                                        clip: true

                                        Components.ClueStrip {
                                            id: clueStrip
                                            anchors.fill: parent
                                            clue: modelData
                                            orient: 0        // vertical
                                            showArrow: true
                                            showPosition: false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- HORIZONTAL CLUES (bottom): n rows, each row scrolls horizontally ---
                Column {
                    width: parent.width
                    spacing: page.gap

                    Repeater {
                        model: page.n       // rows 0..n-1

                        SilicaFlickable {
                            id: rowScroll
                            width: parent.width
                            clip: true
                            interactive: true
                            flickableDirection: Flickable.HorizontalFlick
                            pressDelay: 100

                            readonly property int rowIndex: index
                            readonly property var g: cluePanel.hGroup(rowIndex)

                            height: rowRow.implicitHeight
                            contentWidth: rowRow.width
                            contentHeight: rowRow.implicitHeight

                            Row {
                                id: rowRow
                                spacing: page.gap

                                Repeater {
                                    model: (g && g.clues) ? g.clues : []

                                    Components.ClueStrip {
                                        clue: modelData
                                        orient: 1         // horizontal
                                        showArrow: true
                                        showPosition: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // --- end clues panel ---
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
