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

            // --- Clues panel (DOS-like): vertical groups above, horizontal groups below ---
            Column {
                id: cluePanel
                width: parent.width
                spacing: Theme.paddingMedium
                x: Theme.horizontalPageMargin

                property var vGroups: []
                property var hGroups: []

                function updateGroups() {
                    var gs = sherlockEngine.clueGroups
                    var v = []
                    var h = []
                    for (var i = 0; gs && i < gs.length; ++i) {
                        var g = gs[i]
                        if (!g) continue
                        if (g.orient === 0) v.push(g)   // 0 = Vertical
                        else h.push(g)                  // 1 = Horizontal
                    }
                    vGroups = v
                    hGroups = h
                }

                Component.onCompleted: {
                    updateGroups()
                    // Temporary debug
                    console.log("[clues] vGroups =", cluePanel.vGroups ? cluePanel.vGroups.length : "null",
                                "hGroups =", cluePanel.hGroups ? cluePanel.hGroups.length : "null")
                    if (cluePanel.vGroups && cluePanel.vGroups.length > 0)
                        console.log("[clues] vGroups[0] =", JSON.stringify(cluePanel.vGroups[0]))
                    if (cluePanel.hGroups && cluePanel.hGroups.length > 0)
                        console.log("[clues] hGroups[0] =", JSON.stringify(cluePanel.hGroups[0]))
                }

                Connections {
                    target: sherlockEngine
                    onClueGroupsChanged: cluePanel.updateGroups()
                }

                // TEMP DEBUG HEADER
                Label {
                    width: parent.width
                    text: "Vertical clue groups: " + cluePanel.vGroups.length
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                // Vertical clues area (empty for now, but space is now correct)
                Row {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: cluePanel.vGroups.length > 0

                    Repeater {
                        model: cluePanel.vGroups
                        Column {
                            spacing: Theme.paddingSmall
                            Repeater {
                                model: modelData.clues
                                Components.ClueStrip { clue: modelData }
                            }
                        }
                    }
                }

                // TEMP DEBUG HEADER
                Label {
                    width: parent.width
                    text: "Horizontal clue groups: " + cluePanel.hGroups.length
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                // Horizontal clues (your current “Given strips” live here)
                SilicaFlickable {
                    id: hScroll
                    width: parent.width
                    height: hRow.implicitHeight
                    contentWidth: hRow.width
                    contentHeight: hRow.implicitHeight
                    clip: true
                    interactive: true
                    visible: cluePanel.hGroups.length > 0

                    // Helps inside a vertical flickable
                    flickableDirection: Flickable.HorizontalFlick
                    pressDelay: 100

                    Row {
                        id: hRow
                        spacing: Theme.paddingSmall

                        Repeater {
                            model: cluePanel.hGroups

                            // each group is a Row of ClueStrips
                            Row {
                                spacing: Theme.paddingSmall

                                Repeater {
                                    model: modelData.clues
                                    // If you use import "../components" as Components:
                                    // Components.ClueStrip { clue: modelData }
                                    Components.ClueStrip { clue: modelData }
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
