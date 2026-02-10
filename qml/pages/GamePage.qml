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
            if (sherlockEngine.solved) solvedPopup.open()
        }
    }

    Component.onCompleted: {
        sherlockEngine.setPlayerName(appSettings.playerName)
        sherlockEngine.setSize(appSettings.boardSize)
        sherlockEngine.setDifficulty(appSettings.difficulty)
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
                onClicked: sherlockEngine.restartCurrentPuzzle()
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

        // Solved popup
        Item {
            id: solvedOverlay
            anchors.fill: parent
            visible: false
            z: 9999

            function open()  { visible = true }
            function close() { visible = false }

            // Dim background
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.55
            }

            // Block clicks to underlying UI
            MouseArea {
                anchors.fill: parent
                onClicked: solvedOverlay.close()
            }

            // Center card
            Rectangle {
                id: solvedCard
                width: Math.min(parent.width - 2*Theme.horizontalPageMargin, Theme.itemSizeHuge * 3)
                radius: Theme.paddingMedium
                color: Theme.highlightBackgroundColor
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    width: parent.width
                    spacing: Theme.paddingLarge
                    anchors.margins: Theme.paddingLarge

                    Label {
                        text: "Solved!"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: Theme.primaryColor
                    }

                    Label {
                        text: "Time: " + (sherlockEngine.timerText || "")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        text: "Player: " + (sherlockEngine.playerName || "")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        // If you don’t have difficultyText yet, replace with your mapping from int
                        text: "Difficulty: " + (sherlockEngine.difficultyText || sherlockEngine.difficulty)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Button {
                            text: "Next puzzle"
                            width: (parent.width - Theme.paddingMedium) / 2
                            onClicked: {
                                solvedOverlay.close()
                                sherlockEngine.nextPuzzleAccordingToMode()
                            }
                        }

                        Button {
                            text: "Scores"
                            width: (parent.width - Theme.paddingMedium) / 2
                            onClicked: {
                                solvedOverlay.close()
                                pageStack.push(Qt.resolvedUrl("ScoresPage.qml"))
                            }
                        }
                    }
                }
            }
        }

        Column
        {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            // First row - header
            Item {
                width: parent.width
                height: Theme.itemSizeLarge

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
            Row {
                width: parent.width
                height: Theme.itemSizeMedium
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                IconButton {
                    id: leftBtn
                    icon.source: "image://theme/icon-m-left"
                    enabled: sherlockEngine.puzzleSource === sherlockEngine.PUZZLE_BANK() && sherlockEngine.puzzleId > 0
                    onClicked: sherlockEngine.previousBankPuzzle()
                }

                Label {
                    width: parent.width - leftBtn.width - rightBtn.width - Theme.paddingLarge
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: (sherlockEngine.puzzleSource === sherlockEngine.PUZZLE_BANK()
                           ? ("Bank #" + (sherlockEngine.puzzleId + 1) + "/" + sherlockEngine.bankCount()
                              + "  (" + sherlockEngine.size + "×" + sherlockEngine.size + ")")
                           : ("Seed " + sherlockEngine.puzzleSeed
                              + "  (" + sherlockEngine.size + "×" + sherlockEngine.size + ")"))
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                IconButton {
                    id: rightBtn
                    icon.source: "image://theme/icon-m-right"
                    enabled: !sherlockEngine.randomSelected
                    onClicked: sherlockEngine.nextBankPuzzle()
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
                                        delegate: Row {
                                            spacing: Theme.paddingSmall

                                            Image {
                                                width: cluePanel.iconPx
                                                height: cluePanel.iconPx
                                                sourceSize.width: cluePanel.iconPx
                                                sourceSize.height: cluePanel.iconPx
                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true
                                                smooth: false
                                                visible: source !== ""
                                                source: cluePanel.iconSourceFor(modelData.aRow, modelData.a)
                                            }

                                            Label {
                                                text: cluePanel.midTextForClue(modelData, 0)
                                                font.pixelSize: Theme.fontSizeTiny
                                                font.bold: true
                                                color: cluePanel.textCol
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            // Second icon only for pairwise clues (LeftOf / Above).
                                            Image {
                                                width: cluePanel.iconPx
                                                height: cluePanel.iconPx
                                                sourceSize.width: cluePanel.iconPx
                                                sourceSize.height: cluePanel.iconPx
                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true
                                                smooth: false
                                                visible: cluePanel.isPairwiseClue(modelData) && source !== ""
                                                source: cluePanel.iconSourceFor(modelData.bRow, modelData.b)
                                            }
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
                                        delegate: Row {
                                            spacing: cluePanel.clueGap

                                            Image {
                                                width: cluePanel.iconPx
                                                height: cluePanel.iconPx
                                                sourceSize.width: cluePanel.iconPx
                                                sourceSize.height: cluePanel.iconPx
                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true
                                                smooth: false
                                                visible: source !== ""
                                                source: cluePanel.iconSourceFor(modelData.aRow, modelData.a)
                                            }

                                            Label {
                                                text: cluePanel.midTextForClue(modelData, 1)
                                                font.pixelSize: Theme.fontSizeTiny
                                                font.bold: true
                                                color: cluePanel.textCol
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Image {
                                                width: cluePanel.iconPx
                                                height: cluePanel.iconPx
                                                sourceSize.width: cluePanel.iconPx
                                                sourceSize.height: cluePanel.iconPx
                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true
                                                smooth: false
                                                visible: cluePanel.isPairwiseClue(modelData) && source !== ""
                                                source: cluePanel.iconSourceFor(modelData.bRow, modelData.b)
                                            }
                                        }
                                    }
                                }
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
