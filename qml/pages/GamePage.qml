/*
    Copyright (C) 2026 edp17 and chatGPT

    This file is part of harbour-sherlock.

    The harbour-sherlock is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The harbour-sherlock is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the harbour-sherlock. If not, see <http://www.gnu.org/licenses/>.
*/
import QtQuick 2.6
import Sailfish.Silica 1.0

import "../components" as Components
import "../"

Page
{
    id: page

    allowedOrientations: Orientation.All

    // Layout helpers (were accidentally removed in A3 cleanup)
    readonly property int n: sherlockEngine.size
    readonly property real margin: Theme.horizontalPageMargin
    readonly property real gap: Theme.paddingSmall
    property bool solvedPopupShownForThisState: false

    SettingsStore {
        id: appSettings
    }

    function showNotification(text) {
        if (pageStack && pageStack.showNotification)
            pageStack.showNotification(text)
    }

    Connections {
        target: appSettings
        onBoardSizeChanged: {
            sherlockEngine.setBoardSize(appSettings.boardSize)
        }
        onPlayerNameChanged: {
            sherlockEngine.setPlayerName(appSettings.playerName)
        }
        onDifficultyChanged: {
            sherlockEngine.setDifficulty(appSettings.difficulty)
        }
    }

Connections {
    target: sherlockEngine
    onDosClueGroupsChanged: {
        clueModel.rebuildFlat()
        clueModel.rebuildHFlat()
    }
}

    Connections {
        target: sherlockEngine
        onSolvedChanged: {
            if (sherlockEngine.solved) {
                solvedPopup.elapsedSeconds = sherlockEngine.elapsedSeconds
                solvedPopup.playerName = appSettings.playerName
                solvedPopup.difficulty = appSettings.difficulty
                solvedPopup.open()
                solvedPopupShownForThisState = true
            } else {
                solvedPopup.close()
                solvedPopupShownForThisState = false
            }
        }
    }

    Timer {
        id: solvedStartupTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: {
            if (sherlockEngine.solved) {
                // Use the same assignments you do on a normal solve (if you have them)
                // Minimal version (works even if you don't set fields here):
                solvedPopup.elapsedSeconds = sherlockEngine.elapsedSeconds
                solvedPopup.playerName = appSettings.playerName
                solvedPopup.difficulty = appSettings.difficulty
                solvedPopup.open()
                solvedPopupShownForThisState = true
            }
        }
    }

    Component.onCompleted: {
        clueModel.rebuildFlat()
        clueModel.rebuildHFlat()
        sherlockEngine.setPlayerName(appSettings.playerName)
        sherlockEngine.setBoardSize(appSettings.boardSize)
        sherlockEngine.setDifficulty(appSettings.difficulty)
        solvedStartupTimer.start()
    }

    Connections {
        target: sherlockEngine
        onMessage: {
            if (pageStack && pageStack.showNotification)
                pageStack.showNotification(text)
        }
    }

    Component {
        id: dimmedClueEffect

        ShaderEffect {
            property variant source
            fragmentShader: "varying highp vec2 qt_TexCoord0;\n" +
                            "uniform sampler2D source;\n" +
                            "uniform lowp float qt_Opacity;\n" +
                            "void main(void) {\n" +
                            "    lowp vec4 pixel = texture2D(source, qt_TexCoord0);\n" +
                            "    lowp float grey = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));\n" +
                            "    gl_FragColor = vec4(vec3(grey), pixel.a) * qt_Opacity;\n" +
                            "}\n"
        }
    }

    SilicaFlickable
    {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu
        {
            MenuItem {
                text: qsTr("Random puzzle")
                onClicked: sherlockEngine.startRandomPuzzle()
            }
            MenuItem {
                text: qsTr("Select bank puzzle")
                onClicked: pageStack.push(Qt.resolvedUrl("PuzzlePickerPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }

        Components.MagnifierPopup {
            id: magnifierPopup
        }

        Components.SolvedPopup {
            id: solvedPopup
            onNextPuzzleRequested: sherlockEngine.nextPuzzleAccordingToMode()
            onScoresRequested: pageStack.push(Qt.resolvedUrl("ScoresPage.qml"))
        }

        RemorsePopup {
            id: restartRemorse
        }

        Column
        {
            id: column
            width: parent.width
            spacing: 2//Theme.paddingSmall

            // First row - header
            Item {
                width: parent.width
                height: Theme.itemSizeSmall

                Label {
                    id: timerLabel
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        var s = sherlockEngine.elapsedSeconds
                        var m = Math.floor(s / 60)
                        var ss = s % 60
                        return (m < 10 ? "0" : "") + m + ":" + (ss < 10 ? "0" : "") + ss
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.secondaryColor
                }

                Label {
                    id: titleLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter

                    text: qsTr("Sherlock")
                    // PageHeader-like look:
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    color: Theme.highlightColor
                }
            }

            // Second row
            Item {
                id: bankRow
                width: parent.width
                height: Theme.itemSizeSmall

                readonly property bool isBank: (sherlockEngine.puzzleSource === sherlockEngine.PUZZLE_BANK())
                readonly property int  bankId: sherlockEngine.puzzleId
                readonly property int  bankTotal: sherlockEngine.bankCount()
                readonly property bool bankSolved: (isBank && sherlockEngine.bankPuzzleSolved(bankId))

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: page.margin
                    anchors.rightMargin: page.margin
                    spacing: Theme.paddingMedium

                    IconButton {
                        id: prevBtn
                        anchors.verticalCenter: parent.verticalCenter
                        icon.source: "image://theme/icon-m-left"
                        enabled: bankRow.isBank
                        onClicked: sherlockEngine.previousBankPuzzle()
                    }

                    Label {
                        id: puzzleLabel
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - prevBtn.width - nextBtn.width - 2*parent.spacing
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor

                        text: {
                            var n = sherlockEngine.size
                            if (bankRow.isBank) {
                                var total = bankRow.bankTotal > 0 ? bankRow.bankTotal : 1000
                                var t = "#" + (bankRow.bankId + 1) + "/" + total + " (" + n + "×" + n + ")"
                                if (bankRow.bankSolved) t += qsTr(" (Solved!)")
                                return t
                            } else {
                                return qsTr("Random") + " (" + n + "×" + n + ")"
                            }
                        }
                    }

                    IconButton {
                        id: nextBtn
                        anchors.verticalCenter: parent.verticalCenter
                        icon.source: "image://theme/icon-m-right"

                        onClicked: {
                            if (bankRow.isBank)
                                sherlockEngine.nextBankPuzzle()
                            else
                                sherlockEngine.startRandomPuzzle()
                        }
                    }
                }
            }

            Row {
                id: actionRow
                width: parent.width

                Components.GameActionButton {
                    width: parent.width / 5
                    symbol: "↻"
                    text: qsTr("Restart")
                    enabled: !sherlockEngine.solved
                    onClicked: restartRemorse.execute(qsTr("Restarting puzzle"), function() {
                        sherlockEngine.restartCurrentPuzzle()
                    })
                }

                Components.GameActionButton {
                    width: parent.width / 5
                    symbol: "↶"
                    text: qsTr("Undo")
                    enabled: sherlockEngine.canUndo
                    onClicked: sherlockEngine.undo()
                }

                Components.GameActionButton {
                    width: parent.width / 5
                    symbol: "↷"
                    text: qsTr("Redo")
                    enabled: sherlockEngine.canRedo
                    onClicked: sherlockEngine.redo()
                }

                Components.GameActionButton {
                    width: parent.width / 5
                    symbol: "✓"
                    text: qsTr("Verify")
                    enabled: !sherlockEngine.solved
                    onClicked: sherlockEngine.verify()
                }

                Components.GameActionButton {
                    width: parent.width / 5
                    symbol: sherlockEngine.hasHint ? "✓" : "?"
                    text: sherlockEngine.hasHint ? qsTr("Apply hint") : qsTr("Hint")
                    enabled: !sherlockEngine.solved
                    onClicked: {
                        if (sherlockEngine.hasHint)
                            sherlockEngine.applyHint()
                        else
                            sherlockEngine.hint()
                    }
                }
            }

            // --- Docked clue panels (DOS-like layout) ---
            // Board
            Components.SherlockBoard {
                id: board
                width: parent.width
                magnifierEnabled: appSettings.magnifierEnabled

                onMagnifyRequested: {
                    magnifierPopup.row = row
                    magnifierPopup.col = col
                    magnifierPopup.focusItem = focusItem
                    magnifierPopup.gx = gx
                    magnifierPopup.gy = gy
                    magnifierPopup.gw = gw
                    magnifierPopup.gh = gh
                    magnifierPopup.visible = true
                }
            }

            // Clues under the board (Semantic DOS-style clues)
            // Uses sherlockEngine.dosClueGroups (groups: orient/index/clues; clue: type/a/b/index/given)
            SectionHeader { text: qsTr("Clues") }

            Column {
                id: cluePanel
                width: parent.width
                spacing: 2

                // --- Clue icon sizing (separate from board icons) ---
                property int clueIconPx: Math.max(48, Math.min(96, Math.floor(width / 7)))
                property int clueSymbolH: Math.round(clueIconPx * 0.50)

                // Vertical clue tiles should be ~1 icon wide
                property int vGroupW: clueIconPx + Theme.paddingLarge * 2

                // Horizontal clue tiles must fit up to 3 icons in a row (XOR / 3-icon next-to variants)
                property int hGroupW: clueIconPx * 3 + Theme.paddingLarge * 2 + Theme.paddingSmall * 2

                // If you still use these names elsewhere:
                property int tilePx: clueIconPx
                property int groupW: hGroupW

                // Bigger icons for clues (separate from board cell rendering)
                property int tilePad: Theme.paddingSmall
                property int hTileH: iconPx + tilePad * 2
                property int vTileH: iconPx * 3 + tilePad * 2 + 4   // room for up to 3 icons
                property int tileW: iconPx + tilePad * 2

                property int iconPx: Math.round(tilePx * 0.78)
                property int clueGap: Math.max(1, Math.round(Theme.paddingSmall * 0.5))

                property int clueStripH: cluePanel.tilePx * 3
                                          + Math.round(cluePanel.tilePx * 0.35)
                                          + 10

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

function clueIconSource(row, item) {
    // Route ALL icon requests through the clamped iconUrl()
    return clueModel.iconUrl(row, item, clueIconPx)
}

                function genBankFile(row, item) {
                    var idx = row * iconBankN + item + 1
                    var idx2 = (idx < 10 ? "0" : "") + idx
                    var rowLetter = String.fromCharCode("A".charCodeAt(0) + row)
                    var colNumber = item + 1
                    return idx2 + "_" + rowLetter + colNumber + ".png"
                }

                function midTextForClue(clue, orient) {
                    var t = Number(clue.type)
                    var idx = Number(clue.index) + 1

                    if (t === 1) return "\u2192" // LeftOf
                    if (t === 2) return "\u2191" // Above

                    return "?"
                }

                function isPairwiseClue(clue) {
                    var t = Number(clue.type)
                    return (t === 1 || t === 2) // LeftOf / Above
                }

                function t(c) { return Number(c.type) }
                function hasC(c) { return (Number(c.flags) & 1) !== 0 }
                function cIsXbox(c) { return (Number(c.flags) & 2) !== 0 }

                function componentForType(tt) {
                    // MUST match ClueSemantics.h enum values:
                    // 1 LeftOf
                    // 2 SameColumn
                    // 3 NotSameColumn
                    // 4 SameColumnXor
                    // 5 NextTo
                    // 6 NotNextTo
                    if (tt === 2) return sameColComp
                    if (tt === 3) return notSameColComp
                    if (tt === 4) return sameColXorComp
                    if (tt === 5) return nextToComp
                    if (tt === 6) return notNextToComp
                    if (tt === 1) return leftOfComp
                    return null
                }

                function vGroups() {
                    var a = sherlockEngine.dosClueGroups ? sherlockEngine.dosClueGroups.concat([]) : []
                    var out = []
                    for (var i = 0; i < a.length; ++i) if (Number(a[i].orient) === 0) out.push(a[i])
                    return out
                }
                function hGroups() {
                    var a = sherlockEngine.dosClueGroups ? sherlockEngine.dosClueGroups.concat([]) : []
                    var out = []
                    for (var i = 0; i < a.length; ++i) if (Number(a[i].orient) === 1) out.push(a[i])
                    return out
                }

                function itemOfA(c) { return Number(c.a) }
                function itemOfB(c) { return Number(c.b) }
                function itemOfC(c) { return Number(c.c) }

// --- DOS clue strips: fixed (n-1) slots per stripe, 1 clue per slot ---
QtObject {
    id: clueModel
    // icon size relative to board; DO NOT hardcode 80
//    readonly property int slotPx: Math.max(44, Math.round(board.width / page.n))   // square slot
//    readonly property int iconPx: Math.max(22, Math.round(slotPx * 0.60))          // icon inside slot
// Slot geometry should follow clue icon size (not board cell size)
readonly property int iconPx: cluePanel.clueIconPx
readonly property int slotPx: iconPx + Theme.paddingLarge * 2    // square slot around the icon
    readonly property int stripH: (page.n - 1) * slotPx
    readonly property int stripW: slotPx
    readonly property int gap: Theme.paddingSmall

    readonly property color stripBg: Theme.rgba(Theme.primaryColor, 0.04)
    readonly property color stripBgAlt: Theme.rgba(Theme.primaryColor, 0.02)
    readonly property color stripBorder: Theme.rgba(Theme.primaryColor, 0.20)

// Flattened clue lists for the new presentation
property var vFlat: []     // vertical clues (max 18)
property var hFlat: []     // horizontal clues (max 12 shown)

// Rebuild flattened lists from sherlockEngine.dosClueGroups
function rebuildFlat() {
    var gs = sherlockEngine.dosClueGroups ? sherlockEngine.dosClueGroups : []

    var v = []
    var h = []

    for (var i = 0; i < gs.length; ++i) {
        var g = gs[i]
        if (!g || !g.clues) continue

        var orient = Number(g.orient)
        for (var k = 0; k < g.clues.length; ++k) {
            var c = g.clues[k]
            if (!c) continue
            if (orient === 0) v.push(c)
            else if (orient === 1) h.push(c)
        }
    }

    // Keep only first 18 vertical clues (6x3 grid)
    if (v.length > 18) v = v.slice(0, 18)

    vFlat = v
    hFlat = h
}

function rebuildHFlat() {
    var gs = sherlockEngine.dosClueGroups ? sherlockEngine.dosClueGroups : []
    var h = []

    for (var i = 0; i < gs.length; ++i) {
        var g = gs[i]
        if (!g || !g.clues) continue
        if (Number(g.orient) !== 1) continue // 1 = horizontal

        for (var k = 0; k < g.clues.length; ++k) {
            var c = g.clues[k]
            if (c) h.push(c)
        }
    }

    // show at most 3 cols × 4 rows = 12
    if (h.length > 12) h = h.slice(0, 12)

    hFlat = h
}

function clampIconPx(px) {
    // The optional SHI provider supports these two requested sizes. Bundled
    // themes always load their high-resolution masters from icons_32x32.
    var p = Math.round(Number(px))
    if (!isFinite(p)) return 32
    return (p <= 16) ? 16 : 32
}

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

function iconUrlGenerated(row, item, px) {
    var fn = genIconFileName(row, item)
    if (fn === "") return ""
    return Qt.resolvedUrl("../assets/generated_icons/" + encodeURIComponent(sherlockEngine.iconTheme)
                          + "/icons_32x32/" + fn) + "?e=" + sherlockEngine.iconEpoch
}

function iconUrlProvider(row, item, px) {
    var baseN = 6
    var rr = Number(row)
    var ii = Number(item)
    if (!isFinite(rr) || !isFinite(ii)) return ""
    rr = Math.max(0, Math.min(baseN - 1, rr))
    ii = Math.max(0, Math.min(baseN - 1, ii))

    var p = clampIconPx(px)

    // Provider uses 1..36 (row-major, 6x6)
    var oneBased = rr * baseN + ii + 1
    return "image://sherlock/" + p + "/" + oneBased + "?e=" + sherlockEngine.iconEpoch
}

function iconUrl(row, item, px) {
    return (sherlockEngine.iconSource === 0)
        ? iconUrlGenerated(row, item, px)
        : iconUrlProvider(row, item, px)
}

    function groupFor(orient, index) {
        var gs = sherlockEngine.dosClueGroups
        if (!gs) return null
        for (var i = 0; i < gs.length; ++i) {
            if (Number(gs[i].orient) === orient && Number(gs[i].index) === index)
                return gs[i]
        }
        return null
    }

    // 0..(n-2) fixed slots; show only the first (n-1) clues in that stripe
    function clueAt(orient, index, slot) {
        var g = groupFor(orient, index)
        if (!g || !g.clues) return null
        return (slot >= 0 && slot < g.clues.length) ? g.clues[slot] : null
    }

    // MUST match ClueSemantics.h enum values you’re using now:
    // 1 LeftOf
    // 2 SameColumn
    // 3 NotSameColumn
    // 4 SameColumnXor
    // 5 NextTo
    // 6 NotNextTo
    function componentForType(tt) {
        if (tt === 2) return sameColComp
        if (tt === 3) return notSameColComp
        if (tt === 4) return sameColXorComp
        if (tt === 5) return nextToComp
        if (tt === 6) return notNextToComp
        if (tt === 1) return leftOfComp
        return pairComp
    }
}

// Vertical stripes
// Vertical clues: 6 columns × up to 3 rows (max 18 clues)
Flickable {
    id: verticalClues
    width: parent.width
    clip: true

    readonly property int cols: page.n                 // 6
    readonly property int rows: Math.min(3, Math.max(1, Math.ceil(clueModel.vFlat.length / cols)))

    // Tile geometry (one clue per tile)
    readonly property int tileW: Math.floor((width - clueModel.gap * (cols - 1)) / cols)
    readonly property int tileH: Math.floor(cluePanel.clueIconPx * 3.45 + Theme.paddingLarge)

    height: rows * tileH + (rows - 1) * clueModel.gap

    contentWidth: width
    contentHeight: vGrid.height

    Grid {
        id: vGrid
        width: parent.width
        columns: verticalClues.cols
        columnSpacing: clueModel.gap
        rowSpacing: clueModel.gap

        // Create a full cols*rows grid so row2/3 exist only when needed
        Repeater {
            model: verticalClues.cols * verticalClues.rows

            delegate: Rectangle {
                width: verticalClues.tileW
                height: verticalClues.tileH
                clip: true

                // clue for this cell (may be null for padding cells)
                readonly property var clue: (index < clueModel.vFlat.length) ? clueModel.vFlat[index] : null
                readonly property var comp: (clue !== null) ? clueModel.componentForType(Number(clue.type)) : null
                readonly property string clueKey: clue !== null && clue.key !== undefined
                                                    ? String(clue.key) : ""
                readonly property bool clueDimmed: clueKey !== "" &&
                                                    sherlockEngine.dimmedClueKeys.indexOf(clueKey) >= 0
                readonly property bool clueHinted: clueKey !== "" &&
                                                    clueKey === sherlockEngine.hintClueKey

                opacity: clueDimmed && !clueHinted ? 0.42 : 1.0
                layer.enabled: clueDimmed && !clueHinted
                layer.effect: dimmedClueEffect
                color: clueHinted ? Theme.rgba("#FFC107", 0.22)
                                  : ((index % 2 === 0) ? clueModel.stripBg : clueModel.stripBgAlt)
                border.width: clueHinted ? 3 : 1
                border.color: clueHinted ? "#FFC107" : clueModel.stripBorder

                Behavior on opacity { FadeAnimation { duration: 120 } }

                onClueChanged: {
                    if (vCellLoader.item)
                        vCellLoader.item.clueObj = clue
                }

Loader {
    id: vCellLoader
    anchors.top: parent.top
    anchors.topMargin: Theme.paddingSmall
    anchors.horizontalCenter: parent.horizontalCenter
    active: (comp !== null)
    sourceComponent: comp

    onLoaded: {
        if (!item) return
        item.clueObj = clue

        // Scale-to-fit so wide components never overflow tiles
var iw = item.implicitWidth  > 0 ? item.implicitWidth  : item.width
var ih = item.implicitHeight > 0 ? item.implicitHeight : item.height
var sx = parent.width / Math.max(1, iw)
var sy = (parent.height - Theme.paddingSmall*2) / Math.max(1, ih)
item.scale = Math.min(1.0, sx, sy)
    }
}

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.clue !== null
                    onClicked: sherlockEngine.toggleDimmedClue(parent.clueKey)
                }
            }
        }
    }
}

// Clue stripes separator
Item {
    width: parent.width
    height: 8

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.highlightColor
        opacity: 0.22
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.secondaryColor
        opacity: 0.38
    }
}

// Horizontal stripes
// Horizontal clues: 2 columns × up to 6 rows. The wider cards keep all
// three pictures identifiable, including on narrower portrait displays.
Item {
    id: horizontalClues
    width: parent.width

    readonly property int cols: 2
    readonly property int rows: Math.min(6, Math.max(1, Math.ceil(clueModel.hFlat.length / cols)))

    readonly property int tileW: Math.floor((width - clueModel.gap * (cols - 1)) / cols)
    readonly property int tileH: Math.floor(cluePanel.clueIconPx + Theme.paddingLarge)

    height: rows * tileH + (rows - 1) * clueModel.gap

    Grid {
        id: hGrid
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width
        columns: horizontalClues.cols
        columnSpacing: clueModel.gap
        rowSpacing: Theme.paddingSmall

        Repeater {
            model: horizontalClues.cols * horizontalClues.rows

            delegate: Rectangle {
                width: horizontalClues.tileW
                height: horizontalClues.tileH
                clip: true

                readonly property var clue: (index < clueModel.hFlat.length) ? clueModel.hFlat[index] : null
                readonly property var comp: (clue !== null) ? clueModel.componentForType(Number(clue.type)) : null
                readonly property string clueKey: clue !== null && clue.key !== undefined
                                                    ? String(clue.key) : ""
                readonly property bool clueDimmed: clueKey !== "" &&
                                                    sherlockEngine.dimmedClueKeys.indexOf(clueKey) >= 0
                readonly property bool clueHinted: clueKey !== "" &&
                                                    clueKey === sherlockEngine.hintClueKey

                opacity: clueDimmed && !clueHinted ? 0.42 : 1.0
                layer.enabled: clueDimmed && !clueHinted
                layer.effect: dimmedClueEffect
                color: clueHinted ? Theme.rgba("#FFC107", 0.22)
                                  : ((index % 2 === 0) ? clueModel.stripBg : clueModel.stripBgAlt)
                border.width: clueHinted ? 3 : 1
                border.color: clueHinted ? "#FFC107" : clueModel.stripBorder

                Behavior on opacity { FadeAnimation { duration: 120 } }

                onClueChanged: {
                    if (hCellLoader.item)
                        hCellLoader.item.clueObj = clue
                }

                Loader {
                    id: hCellLoader
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingSmall
                    anchors.top: parent.top
                    anchors.topMargin: Theme.paddingSmall

                    active: (comp !== null)
                    sourceComponent: comp

                    onLoaded: {
                        if (!item) return
                        item.clueObj = clue

                        // scale-to-fit using implicit size when available
                        var iw = (item.implicitWidth  && item.implicitWidth  > 0) ? item.implicitWidth  : item.width
                        var ih = (item.implicitHeight && item.implicitHeight > 0) ? item.implicitHeight : item.height
                        var sx = (parent.width  - Theme.paddingSmall*2) / Math.max(1, iw)
                        var sy = (parent.height - Theme.paddingSmall*2) / Math.max(1, ih)
                        item.scale = Math.min(1.0, sx, sy)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.clue !== null
                    onClicked: sherlockEngine.toggleDimmedClue(parent.clueKey)
                }
            }
        }
    }
}

                Component {
                    id: iconImg
                    Image {
                        width: cluePanel.iconPx
                        height: cluePanel.iconPx
                        sourceSize.width: cluePanel.iconPx
                        sourceSize.height: cluePanel.iconPx
                        fillMode: Image.PreserveAspectFit
                        cache: true
                        asynchronous: true
                        smooth: false
                    }
                }

// --- Shared helpers for clue components ---
Component {
    id: clueIconTile
    Item {
        id: root
        property int row: 0
        property int item: 0
        property int iconPx: cluePanel.clueIconPx

        width: iconPx
        height: iconPx

        Image {
            anchors.fill: parent
            source: clueModel.iconUrl(root.row, root.item, root.iconPx)
            fillMode: Image.PreserveAspectFit
            sourceSize.width: root.iconPx
            sourceSize.height: root.iconPx
            smooth: false
        }
    }
}

Component {
    id: clueSymbol
    Label {
        id: s
        property string sym: "?"
        property int px: 14
        text: sym
        font.pixelSize: px
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width: Math.max(px * 1.4, implicitWidth)
        height: Math.max(px * 1.2, implicitHeight)
        color: Theme.primaryColor
    }
}

Component {
    id: pairComp

    Item {
        id: root
        width: iconPx * 3.0
        height: iconPx * 1.2

        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx

        function apply() {
            if (!clueObj) return

            if (aLoader.item) { aLoader.item.row = clueObj.aRow; aLoader.item.item = clueObj.a; aLoader.item.iconPx = iconPx }
            if (symLoader.item) { symLoader.item.sym = "?"; symLoader.item.px = Math.round(iconPx * 0.55) }
            if (bLoader.item) { bLoader.item.row = clueObj.bRow; bLoader.item.item = clueObj.b; bLoader.item.iconPx = iconPx }
        }

        onClueObjChanged: apply()
        Component.onCompleted: apply()

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Loader { id: aLoader; sourceComponent: clueIconTile; onLoaded: root.apply() }
            Loader { id: symLoader; sourceComponent: clueSymbol; onLoaded: root.apply() }
            Loader { id: bLoader; sourceComponent: clueIconTile; onLoaded: root.apply() }
        }
    }
}

Component {
    id: clueDotsTile

    Item {
        id: root
        width: cluePanel.clueIconPx
        height: cluePanel.clueIconPx

        Rectangle {
            anchors.fill: parent
            color: "#d6c84b"                 // DOS yellow-ish
            border.width: Math.max(2, Math.floor(parent.width * 0.06))
            border.color: "#6a6a6a"
            radius: Math.floor(parent.width * 0.08)
        }

        Row {
            anchors.centerIn: parent
            spacing: Math.max(2, Math.floor(parent.width * 0.10))

            Repeater {
                model: 3
                delegate: Rectangle {
                    width: Math.max(3, Math.floor(root.width * 0.14))
                    height: width
                    radius: width / 2
                    color: "#2d61ff"          // DOS blue dots
                    border.width: 0
                }
            }
        }
    }
}

Component {
    id: clueUpDownArrowTile

    Item {
        id: root
        // Small marker, proportional to clue icon size
        width: Math.max(10, Math.floor(cluePanel.clueIconPx * 0.55))
        height: Math.max(10, Math.floor(cluePanel.clueIconPx * 0.55))

//        Rectangle {
//            anchors.fill: parent
//            color: "#d6c84b" // same yellow-ish as dots tile (tweak later if needed)
//            border.width: Math.max(2, Math.floor(parent.width * 0.10))
//            border.color: "#6a6a6a"
//            radius: Math.floor(parent.width * 0.18)
//        }

        Text {
            anchors.centerIn: parent
            text: "↕"
            font.pixelSize: Math.max(10, Math.floor(parent.height * 0.75))
            font.bold: true
            color: "yellow" //"#2d61ff" // DOS-ish blue
        }
    }
}

//----------------------------------------------------------
//-------------- RULES/CLUES -------------------------------
//----------------------------------------------------------
Component {
    id: sameColComp

    Item {
        id: root
        width: cluePanel.clueIconPx * 1.2
        height: cluePanel.clueIconPx * (root.hasC ? 3.2 : 2.1)
        clip: true

        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx

        readonly property bool hasC: !!clueObj
                                   && clueObj.c !== undefined
                                   && clueObj.c !== null
                                   && Number(clueObj.c) >= 0

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.aRow), Number(root.clueObj.a))
                            : ""
            }
            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.bRow), Number(root.clueObj.b))
                            : ""
            }
            Components.CluePicture {
                visible: root.hasC
                iconSize: root.iconPx
                iconSource: root.clueObj && root.hasC
                            ? cluePanel.clueIconSource(Number(root.clueObj.cRow), Number(root.clueObj.c))
                            : ""
            }
        }
    }
}

Component {
    id: notSameColComp

    Item {
        id: root
        width: cluePanel.clueIconPx * 1.2
        height: cluePanel.clueIconPx * (root.hasC ? 3.2 : 2.1)
        clip: true

        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx

        // C exists if c>=0 (do NOT rely on clueObj.hasC)
        readonly property bool hasC: !!clueObj
                                   && clueObj.c !== undefined
                                   && clueObj.c !== null
                                   && Number(clueObj.c) >= 0

        // Which one is red-X boxed:
        // Accept multiple backend field names; fall back:
        // - if 3 icons: default box C (2)
        // - if 2 icons: default box B (1) (matches your 2-icon example)
        readonly property int xboxPos: (function() {
            if (!clueObj) return -1

            var v =
                (clueObj.xMark !== undefined && clueObj.xMark !== null && Number(clueObj.xMark) >= 0) ? Number(clueObj.xMark) :
                (clueObj.xboxPos !== undefined && clueObj.xboxPos !== null) ? Number(clueObj.xboxPos) :
                (clueObj.xbox !== undefined && clueObj.xbox !== null) ? Number(clueObj.xbox) :
                (clueObj.xboxIndex !== undefined && clueObj.xboxIndex !== null) ? Number(clueObj.xboxIndex) :
                NaN

            if (isFinite(v)) return v

            return hasC ? 2 : 1
        })()

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            visible: !!root.clueObj

            Components.CluePicture {
                iconSize: root.iconPx
                crossed: root.xboxPos === 0
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.aRow), Number(root.clueObj.a))
                            : ""
            }
            Components.CluePicture {
                iconSize: root.iconPx
                crossed: root.xboxPos === 1
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.bRow), Number(root.clueObj.b))
                            : ""
            }
            Components.CluePicture {
                visible: root.hasC
                iconSize: root.iconPx
                crossed: root.xboxPos === 2
                iconSource: root.clueObj && root.hasC
                            ? cluePanel.clueIconSource(Number(root.clueObj.cRow), Number(root.clueObj.c))
                            : ""
            }
        }
    }
}


Component {
    id: sameColXorComp

    Item {
        id: root
        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx

        // Let content define size (prevents internal clipping)
        implicitWidth: col.implicitWidth
        implicitHeight: col.implicitHeight

        Column {
            id: col
            anchors.left: parent.left
            anchors.top: parent.top
            spacing: Math.max(2, Math.floor(iconPx * 0.08))
            visible: !!root.clueObj

            // A
            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.aRow), Number(root.clueObj.a))
                            : ""
            }

            // B
            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.bRow), Number(root.clueObj.b))
                            : ""
            }

            // up/down arrow marker between B and C
            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: clueUpDownArrowTile
            }

            // C
            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.cRow), Number(root.clueObj.c))
                            : ""
            }
        }
    }
}

Component {
    id: leftOfComp

    Item {
        id: root
        width: cluePanel.clueIconPx * 3.4
        height: cluePanel.clueIconPx * 1.2
        clip: true

        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            visible: !!root.clueObj

            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.aRow), Number(root.clueObj.a))
                            : ""
            }
            Loader { sourceComponent: clueDotsTile }   // the 3-dot middle tile
            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.bRow), Number(root.clueObj.b))
                            : ""
            }
        }
    }
}

Component {
    id: nextToComp

    Item {
        id: root
        width: cluePanel.clueIconPx * (root.hasC ? 3.4 : 2.3)
        height: cluePanel.clueIconPx * 1.2
        clip: true

        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx

        readonly property bool hasC: !!clueObj
                                   && clueObj.c !== undefined
                                   && clueObj.c !== null
                                   && Number(clueObj.c) >= 0

        Row {
            anchors.centerIn: parent
            spacing: 0
            visible: !!root.clueObj

            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.aRow), Number(root.clueObj.a))
                            : ""
            }
            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.bRow), Number(root.clueObj.b))
                            : ""
            }
            Components.CluePicture {
                visible: root.hasC
                iconSize: root.iconPx
                iconSource: root.clueObj && root.hasC
                            ? cluePanel.clueIconSource(Number(root.clueObj.cRow), Number(root.clueObj.c))
                            : ""
            }
        }
    }
}

Component {
    id: notNextToComp

    Item {
        id: root
        width: cluePanel.clueIconPx * (root.hasC ? 3.4 : 2.3)
        height: cluePanel.clueIconPx * 1.2
        clip: true

        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx

        readonly property bool hasC: !!clueObj
                                   && clueObj.c !== undefined
                                   && clueObj.c !== null
                                   && Number(clueObj.c) >= 0

        Row {
            anchors.centerIn: parent
            spacing: 0
            visible: !!root.clueObj

            Components.CluePicture {
                iconSize: root.iconPx
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.aRow), Number(root.clueObj.a))
                            : ""
            }
            Components.CluePicture {
                iconSize: root.iconPx
                crossed: true
                iconSource: root.clueObj
                            ? cluePanel.clueIconSource(Number(root.clueObj.bRow), Number(root.clueObj.b))
                            : ""
            }
            Components.CluePicture {
                visible: root.hasC
                iconSize: root.iconPx
                iconSource: root.clueObj && root.hasC
                            ? cluePanel.clueIconSource(Number(root.clueObj.cRow), Number(root.clueObj.c))
                            : ""
            }
        }
    }
}

//--------------------------------------------------------------------

            }
        }
    }

}
