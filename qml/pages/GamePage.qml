import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

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
            sherlockEngine.setSize(appSettings.boardSize)
            sherlockEngine.startBankPuzzle(0)
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
        sherlockEngine.setPlayerName(appSettings.playerName)
        sherlockEngine.setSize(appSettings.boardSize)
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

    SilicaFlickable
    {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu
        {
            MenuItem {
                text: "Random puzzle"
                onClicked: sherlockEngine.startRandomPuzzle()
            }
            MenuItem {
                text: "Select bank puzzle"
                onClicked: pageStack.push(Qt.resolvedUrl("PuzzlePickerPage.qml"))
            }
            MenuItem {
                text: "Restart puzzle"
                onClicked: {
                    sherlockEngine.restartCurrentPuzzle()
                }
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
                text: "Settings"
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: "Scores"
                onClicked: pageStack.push(Qt.resolvedUrl("ScoresPage.qml"))
            }
            MenuItem {
                text: "Game Rules"
                onClicked: pageStack.push(Qt.resolvedUrl("RulesPage.qml"))
            }
            MenuItem {
                text: "About"
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: "Reveal Solution (debug)"
                onClicked: sherlockEngine.revealSolution()
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

                    text: "Sherlock"
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
                                if (bankRow.bankSolved) t += " (Solved!)"
                                return t
                            } else {
                                return "Random (" + n + "×" + n + ")"
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
            SectionHeader { text: "Clues" }

            Column {
                id: cluePanel
                width: parent.width
                spacing: 2

                // --- Clue icon sizing (separate from board icons) ---
                property int clueIconPx: 80
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

                function genBankFile(row, item) {
                    var idx = row * iconBankN + item + 1
                    var idx2 = (idx < 10 ? "0" : "") + idx
                    var rowLetter = String.fromCharCode("A".charCodeAt(0) + row)
                    var colNumber = item + 1
                    return idx2 + "_" + rowLetter + colNumber + ".png"
                }

                function genIconFileName(row, item) {
                    // We always reuse the 6×6 generated icon set.
                    var baseN = 6

                    var rr = Number(row)
                    var ii = Number(item)
                    if (!isFinite(rr) || !isFinite(ii)) return ""

                    // Clamp to available icon range (0..5)
                    rr = Math.max(0, Math.min(baseN - 1, rr))
                    ii = Math.max(0, Math.min(baseN - 1, ii))

                    var idx = rr * baseN + ii + 1
                    var idx2 = (idx < 10 ? "0" : "") + idx
                    var rowLetter = String.fromCharCode("A".charCodeAt(0) + rr)
                    var colNumber = ii + 1
                    return idx2 + "_" + rowLetter + colNumber + ".png"
                }

                function iconSourceFor(row, item) {
                    var rr = Number(row)
                    var ii = Number(item)
                    if (!isFinite(rr) || !isFinite(ii)) return ""

                    // We reuse 6×6 icon bank naming for generated icons
                    var baseN = 6
                    rr = Math.max(0, Math.min(baseN - 1, rr))
                    ii = Math.max(0, Math.min(baseN - 1, ii))

                    if (sherlockEngine.iconSource === 0) {
                        var fn = genIconFileName(rr, ii)
                        if (fn === "") return ""
                        return Qt.resolvedUrl("../assets/generated_icons/icons_32x32/" + fn) + "?e=" + sherlockEngine.iconEpoch
                    }

                    // SHI provider uses 1..36 index (row-major in 6×6 bank)
                    var oneBased = rr * baseN + ii + 1
                    return "image://sherlock/32/" + oneBased + "?e=" + sherlockEngine.iconEpoch
                }

                function midTextForClue(clue, orient) {
                    var t = Number(clue.type)
                    var idx = Number(clue.index) + 1

                    if (t === 1) return "\u2192" // LeftOf
                    if (t === 2) return "\u2191" // Above

                    // Placement clues: no "col/row" text, orientation implies it.
                    if (t === 8)  return "" + idx         // IsInCol
                    if (t === 10) return "\u2260 " + idx  // NotInCol (≠)

                    if (t === 7)  return "" + idx         // IsInRow (future)
                    if (t === 9)  return "\u2260 " + idx  // NotInRow (future)

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
                    // 7 IsInCol
                    // 8 NotInCol
                    if (tt === 2) return sameColComp
                    if (tt === 3) return notSameColComp
                    if (tt === 4) return sameColXorComp
                    if (tt === 5) return nextToComp
                    if (tt === 6) return notNextToComp
                    if (tt === 7) return placementComp
                    if (tt === 8) return notPlacementComp
                    if (tt === 1) return leftOfComp
                    return pairComp
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
    readonly property int slotPx: Math.max(44, Math.round(board.width / page.n))   // square slot
    readonly property int iconPx: Math.max(22, Math.round(slotPx * 0.60))          // icon inside slot
    readonly property int stripH: (page.n - 1) * slotPx
    readonly property int stripW: slotPx
    readonly property int gap: Theme.paddingSmall

    readonly property color stripBg: Theme.rgba(Theme.primaryColor, 0.04)
    readonly property color stripBgAlt: Theme.rgba(Theme.primaryColor, 0.02)
    readonly property color stripBorder: Theme.rgba(Theme.primaryColor, 0.20)

    function genIconFileName(row, item) {
        var baseN = 6
        var rr = Math.max(0, Math.min(baseN - 1, Number(row)))
        var ii = Math.max(0, Math.min(baseN - 1, Number(item)))
        var idx = rr * baseN + ii + 1
        var idx2 = (idx < 10 ? "0" : "") + idx
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + rr)
        var colNumber = ii + 1
        return idx2 + "_" + rowLetter + colNumber + ".png"
    }

    function iconSourceFor(row, item) {
        var rr = Number(row), ii = Number(item)
        if (!isFinite(rr) || !isFinite(ii)) return ""
        if (sherlockEngine.iconSource === 0) {
            var fn = genIconFileName(rr, ii)
            return Qt.resolvedUrl("../assets/generated_icons/icons_32x32/" + fn) + "?e=" + sherlockEngine.iconEpoch
        }
        // SHI path (your ImageProvider)
        return "image://sherlock/r" + rr + "_i" + ii + "?e=" + sherlockEngine.iconEpoch
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
    // 7 IsInCol
    // 8 NotInCol
    function componentForType(tt) {
        if (tt === 2) return sameColComp
        if (tt === 3) return notSameColComp
        if (tt === 4) return sameColXorComp
        if (tt === 5) return nextToComp
        if (tt === 6) return notNextToComp
        if (tt === 7) return placementComp
        if (tt === 8) return notPlacementComp
        if (tt === 1) return leftOfComp
        return pairComp
    }
}

// Vertical stripes (one per column)
Flickable {
    id: verticalClues
    width: parent.width
    height: clueModel.stripH
    clip: true
    contentWidth: vRow.width
    contentHeight: vRow.height

    Row {
        id: vRow
        spacing: clueModel.gap

        Repeater {
            model: page.n
            delegate: Rectangle {
                width: clueModel.stripW
                height: clueModel.stripH
                color: (index % 2 === 0) ? clueModel.stripBg : clueModel.stripBgAlt
                border.width: 1
                border.color: clueModel.stripBorder

                Column {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: page.n - 1
                        delegate: Item {
                            width: parent.width
                            height: clueModel.slotPx

                            property var clue: clueModel.clueAt(0, index, modelData)  // orient 0 = Vertical

                            Loader {
                                anchors.centerIn: parent
                                sourceComponent: clue ? clueModel.componentForType(Number(clue.type)) : null
                                // pass-through
                                property var clueObj: clue
                                property int iconPx: clueModel.iconPx
                            }
                        }
                    }
                }
            }
        }
    }
}

// Horizontal stripes (one per row)
Flickable {
    id: horizontalClues
    width: parent.width
    height: clueModel.stripH
    clip: true
    contentWidth: hRow.width
    contentHeight: hRow.height

    Row {
        id: hRow
        spacing: clueModel.gap

        Repeater {
            model: page.n
            delegate: Rectangle {
                width: clueModel.stripW
                height: clueModel.stripH
                color: (index % 2 === 0) ? clueModel.stripBg : clueModel.stripBgAlt
                border.width: 1
                border.color: clueModel.stripBorder

                Column {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: page.n - 1
                        delegate: Item {
                            width: parent.width
                            height: clueModel.slotPx

                            property var clue: clueModel.clueAt(1, index, modelData) // orient 1 = Horizontal

                            Loader {
                                anchors.centerIn: parent
                                sourceComponent: clue ? clueModel.componentForType(Number(clue.type)) : null
                                property var clueObj: clue
                                property int iconPx: clueModel.iconPx
                            }
                        }
                    }
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
        property int iconPx: 24

        width: iconPx
        height: iconPx

        Image {
            anchors.fill: parent
            source: clueModel.iconSourceFor(root.row, root.item)
            fillMode: Image.PreserveAspectFit
            sourceSize.width: root.iconPx
            sourceSize.height: root.iconPx
            smooth: true
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
        width: iconPx * 3.0
        height: iconPx * 1.2

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.aRow; item.item = clueObj.a; item.iconPx = iconPx } }
            Loader { sourceComponent: clueSymbol; onLoaded: { if (!clueObj) return; item.sym = "?"; item.px = Math.round(iconPx * 0.55) } }
            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.bRow; item.item = clueObj.b; item.iconPx = iconPx } }
        }
    }
}

Component {
    id: sameColComp
    Item {
        width: iconPx * 1.2
        height: iconPx * 3.4

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.aRow; item.item = clueObj.a; item.iconPx = iconPx } }
            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.bRow; item.item = clueObj.b; item.iconPx = iconPx } }

            // optional third icon if present
            Loader {
                visible: clueObj.c !== undefined && clueObj.c >= 0
                sourceComponent: visible ? clueIconTile : null
                onLoaded: {
                    if (!clueObj) return
                    item.row = clueObj.cRow
                    item.item = clueObj.c
                    item.iconPx = iconPx
                }
            }
        }
    }
}

Component {
    id: notSameColComp
    Item {
        width: iconPx * 2.6
        height: iconPx * 3.2

        property bool hasC: (clueObj.c !== undefined && clueObj.c >= 0)
        property int xboxPos: (clueObj.xbox !== undefined ? clueObj.xbox : -1) // 0=A,1=B,2=C (recommended)

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            // Top row: if 3 icons, show the two that are "together"; else show A+B
            Row {
                spacing: Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Loader {
                    sourceComponent: clueIconTile
                    onLoaded: {
                        if (!clueObj) return
                        var ra = clueObj.aRow, ia = clueObj.a
                        var rb = clueObj.bRow, ib = clueObj.b
                        var rc = clueObj.cRow, ic = clueObj.c

                        // If C is X-boxed, top pair is A+B (together), bottom is C
                        // If A boxed -> top pair B+C, bottom A
                        // If B boxed -> top pair A+C, bottom B
                        if (hasC && xboxPos === 0) { item.row = rb; item.item = ib; }
                        else if (hasC && xboxPos === 1) { item.row = ra; item.item = ia; }
                        else { item.row = ra; item.item = ia; } // default A
                        item.iconPx = iconPx
                    }
                }

                Loader {
                    sourceComponent: clueIconTile
                    onLoaded: {
                        if (!clueObj) return
                        var ra = clueObj.aRow, ia = clueObj.a
                        var rb = clueObj.bRow, ib = clueObj.b
                        var rc = clueObj.cRow, ic = clueObj.c

                        if (hasC && xboxPos === 0) { item.row = rb; item.item = ib; } // A boxed => top pair B+C (we'll set below in the other loader)
                        // We need proper pair selection:
                        if (hasC && xboxPos === 0) { item.row = clueObj.bRow; item.item = clueObj.b; } // placeholder, overwritten below
                        item.iconPx = iconPx
                    }
                }

                // Fix the second loader properly using a small inline function:
                Component.onCompleted: {
                    // no-op; Loader onLoaded will run
                }
            }

            // Symbol row
            Loader {
                sourceComponent: clueSymbol
                onLoaded: { if (!clueObj) return; item.sym = "≠"; item.px = Math.round(iconPx * 0.55) }
            }

            // Bottom row: either the "boxed" one (if 3 icons) or just show A+B again? (DOS 2-icon uses just 2 icons, no extra row)
            Item {
                width: parent.width
                height: hasC ? iconPx : 0
                visible: hasC

                Loader {
                    anchors.centerIn: parent
                    sourceComponent: hasC ? clueIconTile : null
                    onLoaded: {
                        if (!clueObj) return
                        var which = xboxPos
                        if (which === 0) { item.row = clueObj.aRow; item.item = clueObj.a; }
                        else if (which === 1) { item.row = clueObj.bRow; item.item = clueObj.b; }
                        else { item.row = clueObj.cRow; item.item = clueObj.c; } // default C boxed
                        item.iconPx = iconPx
                    }
                }
            }
        }

        // Correct the top pair selection (because we need two loaders configured)
        // We do it after creation by directly updating the two loaders’ items.
        Component.onCompleted: {
            // Find the two loaders in the top Row
            var topRow = children[0] // Column
            // Column children: Row, symbol loader, bottom Item
            var r = topRow.children[0]
            var L1 = r.children[0]
            var L2 = r.children[1]
            if (!L1 || !L2) return

            function setLoader(L, row, item) {
                if (L.item) { L.item.row = row; L.item.item = item; L.item.iconPx = iconPx }
            }

            var hasC2 = hasC
            var xb = xboxPos
            if (!hasC2) {
                // 2-icon case: top pair is A+B
                if (L1.item) setLoader(L1, clueObj.aRow, clueObj.a)
                if (L2.item) setLoader(L2, clueObj.bRow, clueObj.b)
                return
            }

            // 3-icon case: top pair are the two NOT boxed
            if (xb === 0) { setLoader(L1, clueObj.bRow, clueObj.b); setLoader(L2, clueObj.cRow, clueObj.c) }
            else if (xb === 1) { setLoader(L1, clueObj.aRow, clueObj.a); setLoader(L2, clueObj.cRow, clueObj.c) }
            else { setLoader(L1, clueObj.aRow, clueObj.a); setLoader(L2, clueObj.bRow, clueObj.b) }
        }
    }
}

Component {
    id: sameColXorComp
    Item {
        width: iconPx * 2.6
        height: iconPx * 3.2

        property bool hasC: (clueObj.c !== undefined && clueObj.c >= 0)

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.aRow; item.item = clueObj.a; item.iconPx = iconPx } }

            Loader {
                sourceComponent: clueSymbol
                onLoaded: { if (!clueObj) return; item.sym = "OR"; item.px = Math.round(iconPx * 0.40) }
            }

            Row {
                spacing: Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.bRow; item.item = clueObj.b; item.iconPx = iconPx } }

                Loader {
                    visible: hasC
                    sourceComponent: visible ? clueIconTile : null
                    onLoaded: { if (!clueObj) return; item.row = clueObj.cRow; item.item = clueObj.c; item.iconPx = iconPx }
                }
            }
        }
    }
}

Component {
    id: leftOfComp
    Item {
        // expects: clueObj, iconPx
        width: iconPx * 3.2
        height: iconPx * 1.2

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.aRow; item.item = clueObj.a; item.iconPx = iconPx } }

            // dots + arrow (DOS style: dots mean unknown distance)
            Column {
                spacing: 0
                Label {
                    text: "…"
                    font.pixelSize: Math.round(iconPx * 0.55)
                    color: Theme.primaryColor
                    horizontalAlignment: Text.AlignHCenter
                    width: Math.round(iconPx * 0.9)
                }
                Label {
                    text: "→"
                    font.pixelSize: Math.round(iconPx * 0.55)
                    color: Theme.primaryColor
                    horizontalAlignment: Text.AlignHCenter
                    width: Math.round(iconPx * 0.9)
                }
            }

            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.bRow; item.item = clueObj.b; item.iconPx = iconPx } }
        }
    }
}

Component {
    id: nextToComp
    Item {
        width: iconPx * 3.2
        height: iconPx * 2.4
        property bool hasC: (clueObj.c !== undefined && clueObj.c >= 0)

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Row {
                spacing: Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.aRow; item.item = clueObj.a; item.iconPx = iconPx } }

                Loader { sourceComponent: clueSymbol; onLoaded: { if (!clueObj) return; item.sym = "↔"; item.px = Math.round(iconPx * 0.55) } }

                Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.bRow; item.item = clueObj.b; item.iconPx = iconPx } }
            }

            Loader {
                visible: hasC
                sourceComponent: visible ? clueIconTile : null
                onLoaded: { if (!clueObj) return; item.row = clueObj.cRow; item.item = clueObj.c; item.iconPx = iconPx }
            }
        }
    }
}

Component {
    id: notNextToComp
    Item {
        width: iconPx * 3.2
        height: iconPx * 2.6
        property bool hasC: (clueObj.c !== undefined && clueObj.c >= 0)

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Row {
                spacing: Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.aRow; item.item = clueObj.a; item.iconPx = iconPx } }

                Loader {
                    sourceComponent: clueSymbol
                    onLoaded: { if (!clueObj) return; item.sym = hasC ? "·" : "≠"; item.px = Math.round(iconPx * 0.55) }
                }

                Loader {
                    sourceComponent: clueIconTile
                    onLoaded: {
                        if (!clueObj) return
                        item.row = hasC ? clueObj.cRow : clueObj.bRow
                        item.item = hasC ? clueObj.c : clueObj.b
                        item.iconPx = iconPx
                    }
                }
            }

            Row {
                visible: hasC
                spacing: Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Loader { sourceComponent: clueSymbol; onLoaded: { if (!clueObj) return; item.sym = "≠"; item.px = Math.round(iconPx * 0.50) } }
                Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.bRow; item.item = clueObj.b; item.iconPx = iconPx } }
            }
        }
    }
}

Component {
    id: placementComp
    Item {
        width: iconPx * 1.6
        height: iconPx * 2.2

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.aRow; item.item = clueObj.a; item.iconPx = iconPx } }

            Label {
                text: String(Number(clueObj.index) + 1)
                font.pixelSize: Math.round(iconPx * 0.50)
                color: Theme.primaryColor
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
        }
    }
}

Component {
    id: notPlacementComp
    Item {
        width: iconPx * 1.8
        height: iconPx * 2.2

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Loader { sourceComponent: clueIconTile; onLoaded: { if (!clueObj) return; item.row = clueObj.aRow; item.item = clueObj.a; item.iconPx = iconPx } }

            Label {
                text: "≠ " + String(Number(clueObj.index) + 1)
                font.pixelSize: Math.round(iconPx * 0.45)
                color: Theme.primaryColor
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
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
