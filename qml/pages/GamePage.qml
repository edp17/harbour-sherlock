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
            Item {
                id: dockedArea
                width: parent.width

                // tweakable sizing
                readonly property real gap: Theme.paddingLarge
                readonly property real sideW: Math.min(Theme.itemSizeLarge * 2.2, Math.floor(width * 0.38))

                Column {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    // Board + right-side clues
                    Row {
                        id: topRow
                        width: parent.width
                        spacing: dockedArea.gap

                        Components.SherlockBoard {
                            id: board
                            width: Math.max(Theme.itemSizeLarge * 4, topRow.width - dockedArea.sideW - topRow.spacing)
                        }

                        // Right panel: vertical clue list
                        SilicaListView {
                            id: rightClues
                            width: dockedArea.sideW
                            height: board.height
                            clip: true
                            spacing: Theme.paddingSmall

                            model: sherlockEngine.clues

                            header: Label {
                                x: Theme.paddingSmall
                                width: parent.width - 2*Theme.paddingSmall
                                text: "Clues"
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            delegate: Components.ClueStrip {
                                width: rightClues.width
                                clue: modelData
                            }
                        }
                    }

                    // Bottom panel: horizontal clue list (scroll)
                    Flickable {
                        id: bottomClues
                        width: parent.width
                        height: Theme.itemSizeSmall * 1.2
                        clip: true

                        contentWidth: bottomRow.width
                        contentHeight: bottomRow.height

                        Row {
                            id: bottomRow
                            spacing: Theme.paddingSmall

                            Repeater {
                                model: sherlockEngine.clues
                                delegate: Components.ClueStrip {
                                    width: Theme.itemSizeLarge * 2.2
                                    height: bottomClues.height
                                    clue: modelData
                                }
                            }
                        }
                    }
                }
            }// --- end docked clue panels ---
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
