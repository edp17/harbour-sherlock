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
property int clueIconPx: Math.max(24, Math.min(48, Math.floor(Math.min(width, Theme.itemSizeLarge) * 0.55)))
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
                    // 1 LeftOf        - keep
                    // 2 SameColumn    - keep
                    // 3 NotSameColumn - keep
                    // 4 SameColumnXor - keep
                    // 5 NextTo        - keep
                    // 6 NotNextTo     - keep
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
    readonly property int slotPx: Math.max(44, Math.round(board.width / page.n))   // square slot
    readonly property int iconPx: Math.max(22, Math.round(slotPx * 0.60))          // icon inside slot
    readonly property int stripH: (page.n - 1) * slotPx
    readonly property int stripW: slotPx
    readonly property int gap: Theme.paddingSmall

    readonly property color stripBg: Theme.rgba(Theme.primaryColor, 0.04)
    readonly property color stripBgAlt: Theme.rgba(Theme.primaryColor, 0.02)
    readonly property color stripBorder: Theme.rgba(Theme.primaryColor, 0.20)

function clampIconPx(px) {
    // Only these folders exist (and are what your provider supports)
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
    var p = clampIconPx(px)
    var fn = genIconFileName(row, item)
    if (fn === "") return ""
    return Qt.resolvedUrl("../assets/generated_icons/icons_" + p + "x" + p + "/" + fn) + "?e=" + sherlockEngine.iconEpoch
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

        Repeater {                                           //Outer → stripes
            model: page.n
            delegate: Rectangle {
                property int stripeIndex: index
                width: clueModel.stripW
                height: clueModel.stripH
                color: (index % 2 === 0) ? clueModel.stripBg : clueModel.stripBgAlt
                border.width: 1
                border.color: clueModel.stripBorder

                Column {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {                               //Inner → slots
                        model: page.n - 1
                        delegate: Item {
                            width: parent.width
                            height: clueModel.slotPx

                            property var clue: clueModel.clueAt(0, stripeIndex, modelData)  // orient 0 = Vertical

Loader {
    id: vClueLoader
    anchors.centerIn: parent

    // Guard: never instantiate a clue component for null/undefined modelData
    readonly property bool hasClue: (clue !== undefined && clue !== null)

    active: hasClue
    sourceComponent: active ? clueModel.componentForType(Number(clue.type)) : null

    // keep iconPx available even before item exists (some components bind to it)
    property int iconPx: clueModel.iconPx

    onLoaded: {
        if (item) item.clueObj = clue
    }
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

        Repeater {                                       //Outer → stripes
            model: page.n
            delegate: Rectangle {
                property int stripeIndex: index
                width: clueModel.stripW
                height: clueModel.stripH
                color: (index % 2 === 0) ? clueModel.stripBg : clueModel.stripBgAlt
                border.width: 1
                border.color: clueModel.stripBorder

                Column {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {                          //Inner → slots
                        model: page.n - 1
                        delegate: Item {
                            width: parent.width
                            height: clueModel.slotPx

                            property var clue: clueModel.clueAt(1, stripeIndex, modelData)  // orient 1 = Horizontal

Loader {
    id: hClueLoader
    anchors.centerIn: parent

    readonly property bool hasClue: (clue !== undefined && clue !== null)

    active: hasClue
    sourceComponent: active ? clueModel.componentForType(Number(clue.type)) : null

    property int iconPx: clueModel.iconPx

    onLoaded: {
        if (item) item.clueObj = clue
    }
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
        property int iconPx: cluePanel.clueIconPx//24

        width: iconPx
        height: iconPx

        Image {
            anchors.fill: parent
            source: clueModel.iconUrl(root.row, root.item, root.iconPx)
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
        id: root
        width: iconPx * 3.0
        height: iconPx * 1.2

        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx//24

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
    id: clueIconComp

    Item {
        id: root
        width: iconPx
        height: iconPx

        property int row: 0
        property int item: 0
        property int iconPx: cluePanel.clueIconPx
        property bool xBox: false   // for the red-X framed icon cases

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: cluePanel.clueIconSource(root.row, root.item)
            sourceSize.width: root.iconPx
            sourceSize.height: root.iconPx
            smooth: true
        }

        // “Red X box” overlay (DOS style)
        Rectangle {
            anchors.fill: parent
            visible: root.xBox
            color: "transparent"
            border.width: Math.max(2, Math.floor(root.width * 0.08))
            border.color: "red"
            radius: Math.floor(root.width * 0.08)

            Text {
                anchors.centerIn: parent
                text: "X"
                color: "red"
                font.pixelSize: Math.floor(parent.width * 0.55)
                font.bold: true
            }
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

        function apply() {
            if (!clueObj) return

            if (aLoader.item) {
                aLoader.item.row = clueObj.aRow
                aLoader.item.item = clueObj.a
                aLoader.item.iconPx = iconPx
            }
            if (bLoader.item) {
                bLoader.item.row = clueObj.bRow
                bLoader.item.item = clueObj.b
                bLoader.item.iconPx = iconPx
            }
            if (cLoader.item) {
                cLoader.item.row = clueObj.cRow
                cLoader.item.item = clueObj.c
                cLoader.item.iconPx = iconPx
            }
        }

        onClueObjChanged: apply()
        Component.onCompleted: apply()

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Loader { id: aLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }
            Loader { id: bLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }

            Loader {
                id: cLoader
                visible: root.hasC
                sourceComponent: visible ? clueIconComp : null
                onLoaded: root.apply()
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
                (clueObj.xboxPos !== undefined && clueObj.xboxPos !== null) ? Number(clueObj.xboxPos) :
                (clueObj.xbox !== undefined && clueObj.xbox !== null) ? Number(clueObj.xbox) :
                (clueObj.xboxIndex !== undefined && clueObj.xboxIndex !== null) ? Number(clueObj.xboxIndex) :
                NaN

            if (isFinite(v)) return v

            return hasC ? 2 : 1
        })()

        function apply() {
            if (!clueObj) return

            if (aLoader.item) {
                aLoader.item.row = clueObj.aRow
                aLoader.item.item = clueObj.a
                aLoader.item.iconPx = iconPx
                aLoader.item.xBox = (root.xboxPos === 0)
            }

            if (bLoader.item) {
                bLoader.item.row = clueObj.bRow
                bLoader.item.item = clueObj.b
                bLoader.item.iconPx = iconPx
                bLoader.item.xBox = (root.xboxPos === 1)
            }

            if (cLoader.item) {
                cLoader.item.row = clueObj.cRow
                cLoader.item.item = clueObj.c
                cLoader.item.iconPx = iconPx
                cLoader.item.xBox = (root.xboxPos === 2)
            }
        }

        onClueObjChanged: apply()
        Component.onCompleted: apply()

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            visible: !!root.clueObj

            Loader { id: aLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }
            Loader { id: bLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }

            Loader {
                id: cLoader
                visible: root.hasC
                sourceComponent: visible ? clueIconComp : null
                onLoaded: root.apply()
            }
        }
    }
}

Component {
    id: sameColXorComp

    Item {
        id: root
        width: cluePanel.clueIconPx * 2.8
        height: cluePanel.clueIconPx * 2.6
        clip: true

        property var clueObj: null
        property int iconPx: cluePanel.clueIconPx

        function apply() {
            if (!clueObj) return

            if (aLoader.item) {
                aLoader.item.row = clueObj.aRow
                aLoader.item.item = clueObj.a
                aLoader.item.iconPx = iconPx
            }
            if (bLoader.item) {
                bLoader.item.row = clueObj.bRow
                bLoader.item.item = clueObj.b
                bLoader.item.iconPx = iconPx
            }
            if (cLoader.item) {
                cLoader.item.row = clueObj.cRow
                cLoader.item.item = clueObj.c
                cLoader.item.iconPx = iconPx
            }
        }

        onClueObjChanged: apply()
        Component.onCompleted: apply()

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            visible: !!root.clueObj

            Loader {
                id: aLoader
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: clueIconComp
                onLoaded: root.apply()
            }

            // The DOS clue is conceptually XOR: same column as B OR C (but not both).
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "OR"
                font.pixelSize: Math.max(14, Math.floor(iconPx * 0.35))
                font.bold: true
                color: Theme.primaryColor
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall

                Loader { id: bLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }
                Loader { id: cLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }
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

        function apply() {
            if (!clueObj) return
            if (aLoader.item) { aLoader.item.row = clueObj.aRow; aLoader.item.item = clueObj.a; aLoader.item.iconPx = iconPx }
            if (bLoader.item) { bLoader.item.row = clueObj.bRow; bLoader.item.item = clueObj.b; bLoader.item.iconPx = iconPx }
        }

        onClueObjChanged: apply()
        Component.onCompleted: apply()

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            visible: !!root.clueObj

            Loader { id: aLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }
            Loader { sourceComponent: clueDotsTile }   // the 3-dot middle tile
            Loader { id: bLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }
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

        function apply() {
            if (!clueObj) return

            if (aLoader.item) {
                aLoader.item.row = clueObj.aRow
                aLoader.item.item = clueObj.a
                aLoader.item.iconPx = iconPx
            }
            if (bLoader.item) {
                bLoader.item.row = clueObj.bRow
                bLoader.item.item = clueObj.b
                bLoader.item.iconPx = iconPx
            }
            if (cLoader.item) {
                cLoader.item.row = clueObj.cRow
                cLoader.item.item = clueObj.c
                cLoader.item.iconPx = iconPx
            }
        }

        onClueObjChanged: apply()
        Component.onCompleted: apply()

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            visible: !!root.clueObj

            Loader { id: aLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }
            Loader { id: bLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }

            Loader {
                id: cLoader
                visible: root.hasC
                sourceComponent: visible ? clueIconComp : null
                onLoaded: root.apply()
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

        function apply() {
            if (!clueObj) return

            if (aLoader.item) {
                aLoader.item.row = clueObj.aRow
                aLoader.item.item = clueObj.a
                aLoader.item.iconPx = iconPx
                aLoader.item.xBox = false
            }

            if (bLoader.item) {
                bLoader.item.row = clueObj.bRow
                bLoader.item.item = clueObj.b
                bLoader.item.iconPx = iconPx
                // In BOTH 2-icon and 3-icon variants, B is the red-X boxed item
                bLoader.item.xBox = true
            }

            if (cLoader.item) {
                cLoader.item.row = clueObj.cRow
                cLoader.item.item = clueObj.c
                cLoader.item.iconPx = iconPx
                cLoader.item.xBox = false
            }
        }

        onClueObjChanged: apply()
        Component.onCompleted: apply()

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            visible: !!root.clueObj

            Loader { id: aLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }
            Loader { id: bLoader; sourceComponent: clueIconComp; onLoaded: root.apply() }

            Loader {
                id: cLoader
                visible: root.hasC
                sourceComponent: visible ? clueIconComp : null
                onLoaded: root.apply()
            }
        }
    }
}

//--------------------------------------------------------------------

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
