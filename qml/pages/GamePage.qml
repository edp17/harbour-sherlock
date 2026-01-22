import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

import "../components" as Components

Page
{
    id: page

    allowedOrientations: Orientation.All

    readonly property real margin: Theme.horizontalPageMargin
    readonly property real gap: Theme.paddingSmall
    readonly property int n: sherlockEngine.size

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

            SectionHeader { text: "Clues" }

            // --- Clues panel (DOS-like): vertical groups above, horizontal groups below ---
            Column {
                id: cluePanel

                // Align clue area to the same left/right margins as the board grid
                readonly property real margin: Theme.horizontalPageMargin
                readonly property real gap: Theme.paddingSmall
                readonly property int n: sherlockEngine.size

                x: margin
                width: parent.width - 2*margin
                spacing: Theme.paddingMedium

                property var vGroups: []
                property var hGroups: []

                function updateGroups() {
                    var gs = sherlockEngine.clueGroups
                    var v = []
                    var h = []
                    for (var i = 0; gs && i < gs.length; ++i) {
                        var g = gs[i]
                        if (!g) continue
                        if (Number(g.orient) === 0) v.push(g)  // 0 = Vertical
                        else                        h.push(g)  // 1 = Horizontal
                    }
                    vGroups = v
                    hGroups = h
                }

                Component.onCompleted: updateGroups()

                Connections {
                    target: sherlockEngine
                    onClueGroupsChanged: cluePanel.updateGroups()
                }

                function groupCol(g) { return (g && g.clues && g.clues.length > 0) ? Number(g.clues[0].col) : -1 }
                function groupRow(g) { return (g && g.clues && g.clues.length > 0) ? Number(g.clues[0].row) : -1 }

                function groupsForCol(col) {
                    var out = []
                    for (var i = 0; cluePanel.vGroups && i < cluePanel.vGroups.length; ++i) {
                        var g = cluePanel.vGroups[i]
                        if (groupCol(g) === col) out.push(g)
                    }
                    return out
                }

                function groupsForRow(row) {
                    var out = []
                    for (var i = 0; cluePanel.hGroups && i < cluePanel.hGroups.length; ++i) {
                        var g = cluePanel.hGroups[i]
                        if (groupRow(g) === row) out.push(g)
                    }
                    return out
                }

                // --- VERTICAL CLUES (top): n columns aligned under the board ---
                Column {
                    width: parent.width
                    spacing: page.gap
                    visible: cluePanel.vGroups && cluePanel.vGroups.length > 0

                    Grid {
                        id: vGrid
                        width: parent.width
                        columns: cluePanel.n
                        spacing: page.gap

                        readonly property real colW: Math.floor((width - (columns - 1) * spacing) / columns)

                        Repeater {
                            model: cluePanel.n  // columns 0..n-1

                            Column {
                                width: vGrid.colW
                                spacing: page.gap

                                readonly property int colIndex: index
                                readonly property var colGroups: cluePanel.groupsForCol(colIndex)

                                // stack groups within this column
                                Repeater {
                                    model: colGroups

                                    Column {
                                        spacing: page.gap

                                        // each clue inside the group
                                        Repeater {
                                            model: modelData.clues
                                            Components.ClueStrip {
                                                clue: modelData
                                                orient: 0          // vertical: arrow down
                                                showArrow: true
                                                showPosition: true
                                            }
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
                    visible: cluePanel.hGroups && cluePanel.hGroups.length > 0

                    Repeater {
                        model: cluePanel.n  // rows 0..n-1

                        SilicaFlickable {
                            id: rowScroll
                            width: parent.width
                            clip: true
                            interactive: true
                            flickableDirection: Flickable.HorizontalFlick
                            pressDelay: 100

                            readonly property int rowIndex: index
                            readonly property var rowGroups: cluePanel.groupsForRow(rowIndex)

                            visible: rowGroups && rowGroups.length > 0
                            height: rowRow.implicitHeight
                            contentWidth: rowRow.width
                            contentHeight: rowRow.implicitHeight

                            Row {
                                id: rowRow
                                spacing: page.gap

                                Repeater {
                                    model: rowScroll.rowGroups

                                    Row {
                                        spacing: page.gap

                                        Repeater {
                                            model: modelData.clues
                                            Components.ClueStrip {
                                                clue: modelData
                                                orient: 1          // horizontal: arrow right
                                                showArrow: true
                                                showPosition: true
                                            }
                                        }
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
