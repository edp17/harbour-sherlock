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
            spacing: Theme.paddingSmall

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
                spacing: Theme.paddingSmall

                readonly property int clueStripH: (iconPx + clueGap) * (sherlockEngine.size - 1) + Theme.paddingLarge

                // Bigger icons for clues (separate from board cell rendering)
                property int iconPx: Math.max(22, Math.floor(Theme.iconSizeMedium * 0.7))
                readonly property int clueGap: Math.max(1, Math.floor(Theme.paddingSmall * 0.45))

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
                    if (!isFinite(rr) || !isFinite(ii))
                        return ""

                    if (sherlockEngine.iconSource === 0) {
                        var fn = genIconFileName(rr, ii)
                        if (fn === "") return ""
                        return Qt.resolvedUrl("../assets/generated_icons/icons_32x32/" + fn) + "?e=" + sherlockEngine.iconEpoch
                    }

                    return "image://sherlock/r" + rr + "_i" + ii + "?e=" + sherlockEngine.iconEpoch
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
                    // update numeric ids to your enum values
                    // recommended mapping:
                    // SameCol=20, NotSameCol=21, SameColXor=22, LeftOf=1, NextTo=23, NotNextTo=24
                    if (tt === 20) return sameColComp
                    if (tt === 21) return notSameColComp
                    if (tt === 22) return sameColXorComp
                    if (tt === 1)  return leftOfComp
                    if (tt === 23) return nextToComp
                    if (tt === 24) return notNextToComp
                    // fallback: old pair view
                    return pairComp
                }

                // Top: vertical semantic clues
                Flickable {
                    id: verticalClues
                    width: parent.width
                    height: cluePanel.clueStripH
                    clip: true
                    contentWidth: vRow.width
                    contentHeight: vRow.height

                    Row {
                        id: vRow
                        spacing: Theme.paddingSmall

                        Repeater {
                            model: sherlockEngine.dosClueGroups ? sherlockEngine.dosClueGroups.concat([]) : []
                            delegate: Rectangle {
                                visible: (Number(modelData.orient) === 0)
                                width: cluePanel.iconPx * 3 + Theme.paddingLarge// * 2
                                height: cluePanel.clueStripH
                                radius: 0
                                color: (modelData.index % 2 === 0) ? cluePanel.stripBg : cluePanel.stripBgAlt
                                border.width: 1
                                border.color: cluePanel.stripBorder

                                Column {
                                    anchors.centerIn: parent
                                    spacing: cluePanel.clueGap

                                    Repeater {
                                        model: visible ? modelData.clues : []
                                        delegate: Loader {
                                            width: parent.width
                                            sourceComponent: cluePanel.componentForType(Number(modelData.type))
                                            property var c: modelData
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
                    contentWidth: hRow.width
                    contentHeight: hRow.height

                    Row {
                        id: hRow
                        spacing: cluePanel.clueGap

                        Repeater {
                            model: sherlockEngine.dosClueGroups ? sherlockEngine.dosClueGroups.concat([]) : []
                            delegate: Rectangle {
                                visible: (Number(modelData.orient) === 1)
                                width: cluePanel.iconPx * 3 + Theme.paddingLarge// * 2
                                height: cluePanel.clueStripH
                                radius: 0
                                color: (modelData.index % 2 === 0) ? cluePanel.stripBg : cluePanel.stripBgAlt
                                border.width: 1
                                border.color: cluePanel.stripBorder

                                Column {
                                    anchors.centerIn: parent
                                    spacing: cluePanel.clueGap

                                    Repeater {
                                        model: visible ? modelData.clues : []
                                        delegate: Loader {
                                            width: parent.width
                                            sourceComponent: cluePanel.componentForType(Number(modelData.type))
                                            property var c: modelData
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
    Row {
        spacing: Theme.paddingSmall
        // Loader provides property 'c'
        Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
        Label { text: cluePanel.midTextForClue(c, 0); font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
        Image { visible: true; source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
    }
}

Component {
    id: sameColComp
    Row {
        spacing: Theme.paddingSmall
        Column {
            spacing: Theme.paddingSmall
            Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
            Label { text: "↕"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; horizontalAlignment: Text.AlignHCenter; width: cluePanel.iconPx }
            Image { source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
        }
        // optional third icon (3 images in same column)
        Item {
            visible: cluePanel.hasC(c)
            width: visible ? (cluePanel.iconPx + Theme.paddingSmall) : 0
            height: cluePanel.iconPx
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: cluePanel.iconSourceFor(c.cRow, c.c)
                width: cluePanel.iconPx
                height: cluePanel.iconPx
                sourceSize.width: cluePanel.iconPx
                sourceSize.height: cluePanel.iconPx
                fillMode: Image.PreserveAspectFit
                smooth: false
            }
        }
    }
}

Component {
    id: notSameColComp
    Row {
        spacing: Theme.paddingSmall

        // Two icons that are NOT in same column (or: two same-column + third excluded)
        Column {
            spacing: Theme.paddingSmall
            Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
            Label { text: "✖"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: Theme.errorColor; horizontalAlignment: Text.AlignHCenter; width: cluePanel.iconPx }
            Image { source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
        }

        // optional third icon (the red-X boxed one)
        Item {
            visible: cluePanel.hasC(c)
            width: visible ? (cluePanel.iconPx + Theme.paddingSmall) : 0
            height: cluePanel.iconPx
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: cluePanel.iconPx
                height: cluePanel.iconPx
                color: "transparent"
                border.width: cluePanel.cIsXbox(c) ? 2 : 0
                border.color: Theme.errorColor
                Image {
                    anchors.centerIn: parent
                    source: cluePanel.iconSourceFor(c.cRow, c.c)
                    width: cluePanel.iconPx
                    height: cluePanel.iconPx
                    sourceSize.width: cluePanel.iconPx
                    sourceSize.height: cluePanel.iconPx
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                }
                Label {
                    visible: cluePanel.cIsXbox(c)
                    anchors.centerIn: parent
                    text: "✖"
                    color: Theme.errorColor
                    font.pixelSize: Theme.fontSizeTiny
                    font.bold: true
                }
            }
        }
    }
}

Component {
    id: sameColXorComp
    Column {
        spacing: Theme.paddingSmall
        // top: A
        Row {
            spacing: Theme.paddingSmall
            Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
            Label { text: "↕"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
            Label { text: "OR"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
        }
        // bottom: B and C
        Row {
            spacing: Theme.paddingSmall
            Image { source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
            Label { text: " / "; font.pixelSize: Theme.fontSizeTiny; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
            Image { source: cluePanel.iconSourceFor(c.cRow, c.c); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
        }
    }
}

Component {
    id: leftOfComp
    Row {
        spacing: Theme.paddingSmall
        Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
        Label { text: "⋯"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
        Label { text: "→"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
        Image { source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
    }
}

Component {
    id: nextToComp
    Row {
        spacing: Theme.paddingSmall
        Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
        Label { text: "↔"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
        Image { source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
    }
}

Component {
    id: notNextToComp
    Row {
        spacing: Theme.paddingSmall
        Image { source: cluePanel.iconSourceFor(c.aRow, c.a); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
        Label { text: "✖"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: Theme.errorColor; verticalAlignment: Text.AlignVCenter }
        Label { text: "↔"; font.pixelSize: Theme.fontSizeTiny; font.bold: true; color: cluePanel.textCol; verticalAlignment: Text.AlignVCenter }
        Image { source: cluePanel.iconSourceFor(c.bRow, c.b); width: cluePanel.iconPx; height: cluePanel.iconPx; sourceSize.width: cluePanel.iconPx; sourceSize.height: cluePanel.iconPx; fillMode: Image.PreserveAspectFit; smooth: false }
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
