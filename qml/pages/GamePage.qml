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

// Clues under the board (Option B: semantic DOS-style clues)
// Uses sherlockEngine.dosClueGroups (groups: orient/index/clues; clue: type/a/b/index/given)

Column {
    id: cluePanel
    width: parent.width
    spacing: Theme.paddingSmall

    readonly property int clueStripH: Math.floor(Theme.itemSizeLarge * 1.15)

    function clueText(c, orient) {
        var t = Number(c.type)
        var a = Number(c.a) + 1
        var b = Number(c.b) + 1
        // ClueType enum (from your C++): 1=LeftOf, 2=Above
        if (t === 1) return a + " \u2192 " + b      // →
        if (t === 2) return a + " \u2191 " + b      // ↑
        return a + " ? " + b
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
            spacing: Theme.paddingSmall

            Repeater {
                model: sherlockEngine.dosClueGroups
                delegate: Item {
                    height: cluePanel.clueStripH
                    width: innerRow.width
                    visible: (Number(modelData.orient) === 0)
                    opacity: visible ? 1.0 : 0.0

                    Row {
                        id: innerRow
                        spacing: Theme.paddingSmall
                        height: cluePanel.clueStripH

                        Repeater {
                            model: visible ? modelData.clues : []
                            delegate: Rectangle {
                                height: cluePanel.clueStripH
                                radius: Theme.paddingSmall
                                color: Theme.rgba(Theme.primaryColor, 0.06)
                                border.width: 1
                                border.color: Theme.rgba(Theme.primaryColor, 0.12)

                                Label {
                                    anchors.centerIn: parent
                                    text: cluePanel.clueText(modelData, 0)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primaryColor
                                }

                                implicitWidth: Math.max(Theme.itemSizeSmall * 1.6, label.implicitWidth + Theme.paddingLarge)
                                Label { id: label; visible: false }
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
            spacing: Theme.paddingSmall

            Repeater {
                model: sherlockEngine.dosClueGroups
                delegate: Item {
                    height: cluePanel.clueStripH
                    width: innerRow.width
                    visible: (Number(modelData.orient) === 1)
                    opacity: visible ? 1.0 : 0.0

                    Row {
                        id: innerRow
                        spacing: Theme.paddingSmall
                        height: cluePanel.clueStripH

                        Repeater {
                            model: visible ? modelData.clues : []
                            delegate: Rectangle {
                                height: cluePanel.clueStripH
                                radius: Theme.paddingSmall
                                color: Theme.rgba(Theme.primaryColor, 0.06)
                                border.width: 1
                                border.color: Theme.rgba(Theme.primaryColor, 0.12)

                                Label {
                                    anchors.centerIn: parent
                                    text: cluePanel.clueText(modelData, 1)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primaryColor
                                }

                                implicitWidth: Math.max(Theme.itemSizeSmall * 1.6, label.implicitWidth + Theme.paddingLarge)
                                Label { id: label; visible: false }
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
