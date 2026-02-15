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
                spacing: 2//Theme.paddingSmall

                // Bigger icons for clues (separate from board cell rendering)
                property int tilePad: Theme.paddingSmall
                property int hTileH: iconPx + tilePad * 2
                property int vTileH: iconPx * 3 + tilePad * 2 + 4   // room for up to 3 icons
                property int tileW: iconPx + tilePad * 2

                property int tilePx: Math.max(Theme.itemSizeSmall, Math.round(Theme.itemSizeMedium * 0.85))
                property int iconPx: Math.round(tilePx * 0.78)
                property int clueGap: Theme.paddingSmall

//                property int clueStripH: tilePx * 3 + Theme.paddingLarge * 2
property int clueStripH: cluePanel.tilePx * 3
                          + Math.round(cluePanel.tilePx * 0.35)
                          + 10
                property int groupW: tilePx * 3 + Theme.paddingLarge

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

                // Top: vertical semantic clues
                Flickable {
                    id: verticalClues
                    width: parent.width
                    height: cluePanel.clueStripH
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    contentWidth: vRow.width
                    contentHeight: vRow.height

                    Row {
                        id: vRow
                        spacing: 2//Theme.paddingSmall

                        Repeater {
                            model: cluePanel.vGroups()

                            delegate: Rectangle {
                                width: cluePanel.groupW
                                height: cluePanel.clueStripH
                                radius: 0
                                color: (modelData.index % 2 === 0) ? cluePanel.stripBg : cluePanel.stripBgAlt
                                border.width: 1
                                border.color: cluePanel.stripBorder
                                clip: true

                                Column {
                                    anchors.top: parent.top
                                    anchors.topMargin: Theme.paddingMedium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    clip: true
                                    spacing: cluePanel.clueGap

                                    Repeater {
                                        model: modelData.clues
                                        delegate: Loader {
                                            width: parent.width
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            sourceComponent: cluePanel.componentForType(Number(modelData.type))
                                            property var c: modelData
                                            property int orient: 0
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
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    contentWidth: hRow.width
                    contentHeight: hRow.height

                    Row {
                        id: hRow
                        spacing: 2//Theme.paddingSmall

                        Repeater {
                            model: cluePanel.hGroups()

                            delegate: Rectangle {
                                width: cluePanel.groupW
                                height: cluePanel.clueStripH
                                radius: 0
                                color: (modelData.index % 2 === 0) ? cluePanel.stripBg : cluePanel.stripBgAlt
                                border.width: 1
                                border.color: cluePanel.stripBorder

                                Column {
                                    anchors.centerIn: parent
                                    spacing: cluePanel.clueGap

                                    Repeater {
                                        model: modelData.clues
                                        delegate: Loader {
                                            width: parent.width
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            sourceComponent: cluePanel.componentForType(Number(modelData.type))
                                            property var c: modelData
                                            property int orient: 1
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

                Component {
                    id: pairComp
                    Item {
                        width: parent ? parent.width : (cluePanel.groupW - Theme.paddingLarge)
                        height: cluePanel.tilePx   // one clue row height

                        Row {
                            anchors.centerIn: parent
                            spacing: 2//Theme.paddingSmall

                            // Loader provides property 'c'
                            Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
                            Label { text: cluePanel.midTextForClue(c, orient); font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
                            Image { visible: true; source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
                        }
                    }
                }

                Component {
                    id: clueIconTile

                    Rectangle {
                        id: tile
                        property int row: 0
                        property int item: 0
                        property bool xbox: false

                        width: cluePanel.tilePx
                        height: cluePanel.tilePx
                        radius: Theme.paddingSmall
                        color: "transparent"
                        border.width: xbox ? 2 : 0
                        border.color: xbox ? "red" : "transparent"

                        Image {
                            anchors.centerIn: parent
                            width: cluePanel.iconPx
                            height: cluePanel.iconPx
                            sourceSize.width: cluePanel.iconPx
                            sourceSize.height: cluePanel.iconPx
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            asynchronous: true
                            source: cluePanel.iconSourceFor(tile.row, tile.item)
                        }

                        Canvas {
                            anchors.fill: parent
                            visible: tile.xbox
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.lineWidth = 3
                                ctx.strokeStyle = "red"
                                ctx.beginPath()
                                ctx.moveTo(6,6); ctx.lineTo(width-6,height-6)
                                ctx.moveTo(width-6,6); ctx.lineTo(6,height-6)
                                ctx.stroke()
                            }
                        }
                    }
                }

                Component {
                    id: sameColComp

                    Item {
                        width: parent ? parent.width : Theme.itemSizeSmall
                        height: (cluePanel.hasC(c) ? 3 : 2) * cluePanel.tilePx
                                + (cluePanel.hasC(c) ? 3 : 2) * Theme.paddingSmall
                                + Math.round(cluePanel.tilePx * 0.5)

                        Column {
                            spacing: 2
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCente

                            Loader {
                                sourceComponent: clueIconTile
                                onLoaded: {
                                    item.row = Number(c.aRow)
                                    item.item = cluePanel.itemOfA(c)
                                    item.xbox = false
                                }
                            }

                            // up/down indicator like DOS (double arrow)
                            Label {
                                text: "↕"
                              width: cluePanel.tilePx
                              height: Theme.itemSizeExtraSmall
                              horizontalAlignment: Text.AlignHCenter
                              verticalAlignment: Text.AlignVCenter
                              font.pixelSize: Theme.fontSizeMedium
                              font.bold: true
                              color: cluePanel.textCol
                            }

                            Loader {
                                sourceComponent: clueIconTile
                                onLoaded: {
                                    item.row = Number(c.bRow)
                                    item.item = cluePanel.itemOfB(c)
                                    item.xbox = false
                                }
                            }

                            // optional third image (also same column)
                            Loader {
                                visible: cluePanel.hasC(c)
                                sourceComponent: clueIconTile
                                onLoaded: {
                                    item.row = Number(c.cRow)
                                    item.item = cluePanel.itemOfC(c)
                                    item.xbox = false
                                }
                            }
                        }
                    }
                }

                Component {
                    id: notSameColComp

                    Item {
                        width: parent ? parent.width : Theme.itemSizeSmall
                        height: (cluePanel.hasC(c) ? 3 : 2) * cluePanel.tilePx
                                + (cluePanel.hasC(c) ? 3 : 2) * Theme.paddingSmall
                                + Math.round(cluePanel.tilePx * 0.5)

                        Column {
                            spacing: 2
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCente

                            Loader {
                                sourceComponent: clueIconTile
                                onLoaded: {
                                    item.row = Number(c.aRow)
                                    item.item = cluePanel.itemOfA(c)
                                    item.xbox = false
                                }
                            }

                            Label {
                                // 2-icon variant: show "≠" between them; 3-icon variant: still vertical relation marker
                                text: cluePanel.hasC(c) ? "↕" : "≠"
                                width: cluePanel.iconPx
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: cluePanel.textCol
                            }

                            Loader {
                                sourceComponent: clueIconTile
                                onLoaded: {
                                    item.row = Number(c.bRow)
                                    item.item = cluePanel.itemOfB(c)
                                    item.xbox = false
                                }
                            }

                            Loader {
                                visible: cluePanel.hasC(c)
                                sourceComponent: clueIconTile
                                onLoaded: {
                                    item.row = Number(c.cRow)
                                    item.item = cluePanel.itemOfC(c)
                                    item.xbox = cluePanel.cIsXbox(c)
                                }
                            }
                        }
                    }
                }

                Component {
                    id: sameColXorComp

                    Item {
                        width: parent ? parent.width : Theme.itemSizeSmall * 2 + Theme.paddingSmall
                        height: Theme.itemSizeSmall * 3 + Theme.paddingSmall * 2

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2

                            Loader {
                                sourceComponent: clueIconTile
                                onLoaded: {
                                    item.row = Number(c.aRow)
                                    item.item = cluePanel.itemOfA(c)
                                    item.xbox = false
                                }
                            }

                            // show “OR” like DOS uses implicit “either/or”
                            Label {
                                text: "OR"
                                width: cluePanel.iconPx * 2 + Theme.paddingSmall
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: cluePanel.textCol
                            }

                            Row {
                                spacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter

                                Loader {
                                    sourceComponent: clueIconTile
                                    onLoaded: {
                                        item.row = Number(c.bRow)
                                        item.item = cluePanel.itemOfB(c)
                                        item.xbox = false
                                    }
                                }
                                Loader {
                                    sourceComponent: clueIconTile
                                    onLoaded: {
                                        item.row = Number(c.cRow)
                                        item.item = cluePanel.itemOfC(c)
                                        item.xbox = false
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: leftOfComp
                    Item {
                        width: parent ? parent.width : (cluePanel.groupW - Theme.paddingLarge)
                        height: cluePanel.tilePx   // one clue row height

                        Row {
                            anchors.centerIn: parent
                            spacing: 2//Theme.paddingSmall
                            Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
                            Label { text: "⋯"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
//                            Label { text: "→"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
                            Image { source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
                        }
                    }
                }

                Component {
                    id: nextToComp

                    Item {
                        width: parent ? parent.width : (cluePanel.groupW - Theme.paddingLarge)
                        height: cluePanel.tilePx   // one clue row height

                        Row {
                            anchors.centerIn: parent
                            spacing: 2//Theme.paddingSmall

                            Loader { sourceComponent: clueIconTile; onLoaded: { item.row=Number(c.aRow); item.item=cluePanel.itemOfA(c); item.xbox=false } }
                            Label { text: cluePanel.hasC(c) ? "⇄" : "↔"; font.pixelSize: Theme.fontSizeTiny; verticalAlignment: Text.AlignVCenter }
                            Loader { sourceComponent: clueIconTile; onLoaded: { item.row=Number(c.bRow); item.item=cluePanel.itemOfB(c); item.xbox=false } }

                            Loader {
                                visible: cluePanel.hasC(c)
                                sourceComponent: clueIconTile
                                onLoaded: { item.row=Number(c.cRow); item.item=cluePanel.itemOfC(c); item.xbox=false }
                            }
                        }
                    }
                }

                Component {
                    id: notNextToComp

                    Item {
                        width: parent ? parent.width : (cluePanel.groupW - Theme.paddingLarge)
                        height: cluePanel.tilePx   // one clue row height

                        Row {
                            anchors.centerIn: parent
                            spacing: 2//Theme.paddingSmall

                            Loader { sourceComponent: clueIconTile; onLoaded: { item.row=Number(c.aRow); item.item=cluePanel.itemOfA(c); item.xbox=false } }
//                            Label { text: "≠"; font.pixelSize: Theme.fontSizeTiny; verticalAlignment: Text.AlignVCenter }
Label {
    text: "≠"
    width: cluePanel.tilePx
    height: Math.round(cluePanel.tilePx * 0.35)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font.pixelSize: Math.round(cluePanel.tilePx * 0.32)
    font.bold: true
    color: cluePanel.textCol
}
                            Loader { sourceComponent: clueIconTile; onLoaded: { item.row=Number(c.bRow); item.item=cluePanel.itemOfB(c); item.xbox=false } }

                            Loader {
                                visible: cluePanel.hasC(c)
                                sourceComponent: clueIconTile
                                onLoaded: { item.row=Number(c.cRow); item.item=cluePanel.itemOfC(c); item.xbox=cluePanel.cIsXbox(c) }
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
