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
                text: "Use Generated Icons"
//                onClicked: sherlockEngine.iconSource = 0   // Generated
                onClicked: sherlockEngine.iconSource = sherlockEngine.Generated
            }
            MenuItem {
                text: "Reveal Solution (debug)"
                onClicked: sherlockEngine.revealSolution()
            }
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
    width: parent.width
    spacing: Theme.paddingSmall

    // Top: vertical clues (future)
    Flickable {
        id: verticalClues
        width: parent.width
        height: Theme.itemSizeSmall * 1.2
        clip: true
        contentWidth: vRow.width
        contentHeight: vRow.height

        Row {
            id: vRow
            spacing: Theme.paddingSmall
            Repeater {
                model: sherlockEngine.clues
                delegate: Components.ClueStrip {
                    clue: modelData
                    // later: visible: modelData.type === 1
                    visible: false   // no vertical clues yet
                    height: verticalClues.height
                    width: Theme.itemSizeLarge * 2.2
                }
            }
        }
    }

    // Bottom: horizontal clues (current "Given" goes here)
    Flickable {
        id: horizontalClues
        width: parent.width
        height: Theme.itemSizeSmall * 1.2
        clip: true
        contentWidth: hRow.width
        contentHeight: hRow.height

        Row {
            id: hRow
            spacing: Theme.paddingSmall
            Repeater {
                model: sherlockEngine.clues
                delegate: Components.ClueStrip {
                    clue: modelData
                    // later: visible: modelData.type !== 1
                    visible: true
                    height: horizontalClues.height
                    width: Theme.itemSizeLarge * 2.2
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
