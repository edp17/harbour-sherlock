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
Item {
    id: cluePanel
    width: parent.width

    readonly property int n: sherlockEngine.size
    readonly property real gap: Theme.paddingSmall
    readonly property real margin: Theme.horizontalPageMargin

    // size each strip so n columns fit
    readonly property real stripW: Math.floor((width - 2*margin - (n-1)*gap) / n)
    readonly property real stripH: Theme.itemSizeSmall

    property var vGroups: []
    property var hGroups: []

    function updateGroups() {
        var gs = sherlockEngine.clueGroups
        var v = []
        var h = []
        if (gs && gs.length) {
            for (var i = 0; i < gs.length; ++i) {
                var g = gs[i]
                if (g.orient === 0) v.push(g)
                else if (g.orient === 1) h.push(g)
            }
        }
        vGroups = v
        hGroups = h
    }

    Component.onCompleted: updateGroups()

    Connections {
        target: sherlockEngine
        onClueGroupsChanged: cluePanel.updateGroups()
    }

    Column {
        x: margin
        width: parent.width - 2*margin
        spacing: Theme.paddingMedium

        // ---- Vertical clues (top): grid with n columns, each column is a stack
        Grid {
            id: vGrid
            columns: cluePanel.n
            spacing: cluePanel.gap

            Repeater {
                model: cluePanel.vGroups

                Column {
                    spacing: cluePanel.gap
                    readonly property var g: modelData

                    Repeater {
                        model: g.clues

                        Components.ClueStrip {
                            width: cluePanel.stripW
                            height: cluePanel.stripH
                            clue: modelData
                        }
                    }
                }
            }
        }

        // ---- Horizontal clues (bottom): n rows, each row has 1..K strips
        Column {
            id: hCol
            spacing: cluePanel.gap

            Repeater {
                model: cluePanel.hGroups

                Row {
                    spacing: cluePanel.gap
                    readonly property var g: modelData

                    Repeater {
                        model: g.clues

                        Components.ClueStrip {
                            width: cluePanel.stripW
                            height: cluePanel.stripH
                            clue: modelData
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
