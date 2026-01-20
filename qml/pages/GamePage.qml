import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

import "../components" as Components

Page
{
    id: page

    allowedOrientations: Orientation.All

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
                text: "Reset Marks"
                onClicked: sherlockEngine.resetMarks()
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

            Label
            {
                width: parent.width
                wrapMode: Text.WordWrap
                x: Theme.horizontalPageMargin
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

            // Clues under the board (DOS-like: vertical on top, horizontal below)
            SectionHeader { text: "Clues" }

            Column {
                id: cluePanel
                width: parent.width
                spacing: Theme.paddingSmall

                // Strip sizing
                readonly property int clueStripH: Math.floor(Theme.itemSizeLarge * 1.25)
                readonly property int clueStripW: Math.floor(Theme.itemSizeLarge * 2.4)

                // Filter helpers (QtQuick 2.6-safe)
                function cluesOfType(t) {
                    var out = []
                    var cs = sherlockEngine.clues
                    if (!cs) return out
                    for (var i = 0; i < cs.length; ++i) {
                        var c = cs[i]
                        if (c && Number(c.type) === t)
                            out.push(c)
                    }
                    return out
                }

                // Re-evaluates automatically when sherlockEngine.clues changes
                readonly property var vClues: cluesOfType(1)   // vertical (later)
                readonly property var hClues: cluesOfType(0)   // horizontal (current givens)

                // Top: vertical clues (only takes space if present)
                Flickable {
                    id: verticalClues
                    width: parent.width
                    height: (cluePanel.vClues.length > 0) ? cluePanel.clueStripH : 0
                    visible: cluePanel.vClues.length > 0
                    clip: true
                    contentWidth: vRow.width
                    contentHeight: vRow.height

                    Row {
                        id: vRow
                        spacing: Theme.paddingSmall

                        Repeater {
                            model: cluePanel.vClues
                            delegate: Components.ClueStrip {
                                clue: modelData
                                height: cluePanel.clueStripH
                                width: cluePanel.clueStripW
                                // (later we can add a "direction: down" API here)
                            }
                        }
                    }
                }

                // Bottom: horizontal clues
                Flickable {
                    id: horizontalClues
                    width: parent.width
                    height: (cluePanel.hClues.length > 0) ? cluePanel.clueStripH : 0
                    visible: cluePanel.hClues.length > 0
                    clip: true
                    contentWidth: hRow.width
                    contentHeight: hRow.height

                    Row {
                        id: hRow
                        spacing: Theme.paddingSmall

                        Repeater {
                            model: cluePanel.hClues
                            delegate: Components.ClueStrip {
                                clue: modelData
                                height: cluePanel.clueStripH
                                width: cluePanel.clueStripW
                            }
                        }
                    }
                }
            }
            // --- end docked clue panels ---
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
