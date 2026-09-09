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

Page {
    id: page
    allowedOrientations: Orientation.All

    property int n: sherlockEngine.size

    property var entries: []
    function refreshEntries() { entries = sherlockEngine.bankPuzzleEntries() }

    property int currentId: -1
    property int jumpId: -1
    function jumpToId(oneBased) {
        var id = Number(oneBased) - 1
        if (!isFinite(id)) return
        id = Math.max(0, Math.min(id, entries.length - 1))
        grid.positionViewAtIndex(id, GridView.Beginning)
        jumpId = id
        flashTimer.restart()
    }

    Timer {
        id: flashTimer
        interval: 900
        repeat: false
        onTriggered: jumpId = -1
    }

    Timer {
        id: scrollToCurrentTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (page.currentId >= 0 && page.currentId < page.entries.length) {
                grid.positionViewAtIndex(page.currentId, GridView.Center)
            }
        }
    }

    Component.onCompleted: {
        refreshEntries()
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            currentId = sherlockEngine.currentBankPuzzleId()
            jumpId = -1
            refreshEntries()
            scrollToCurrentTimer.restart()
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Clear solved marks for this size")
                onClicked: {
                    sherlockEngine.clearSolvedBankPuzzles()
                    refreshEntries()
                }
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader { title: qsTr("Select puzzle (%1×%1)").arg(n) }

            Row {
                id: jumpRow
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                TextField {
                    id: jumpField
                    width: parent.width - goButton.width - Theme.paddingMedium
                    placeholderText: qsTr("Go to puzzle number (1–%1)").arg(entries.length)
                    label: qsTr("Puzzle number")
                    inputMethodHints: Qt.ImhDigitsOnly
                }

                Button {
                    id: goButton
                    text: qsTr("Go")
                    onClicked: jumpToId(jumpField.text)
                }
            }

            // 5 columns × 200 rows (1000 tiles)
            Item {
                id: gridHost
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Math.max(Theme.itemSizeExtraLarge * 6, page.height - gridHost.y - Theme.paddingLarge)

                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true

                    cellWidth: Math.floor(width / 5)
                    cellHeight: Theme.itemSizeMedium

                    model: entries

                    delegate: BackgroundItem {
                        width: grid.cellWidth
                        height: grid.cellHeight

                        readonly property int pid: modelData.id
                        readonly property bool solved: modelData.solved

                        onClicked: {
                            sherlockEngine.startBankPuzzle(pid)
                            pageStack.pop()
                        }

                        Rectangle {
                            anchors.fill: parent
                            // Priority: jump > current > solved > normal
                            color: (pid === page.jumpId)
                                   ? Theme.rgba(Theme.highlightColor, 0.35)
                                   : (pid === page.currentId)
                                     ? Theme.rgba(Theme.highlightColor, 0.22)
                                     : (solved
                                        ? Theme.rgba(Theme.highlightColor, 0.50)   // "light blue-ish"
                                        : Theme.rgba(Theme.primaryColor, 0.06))
                            border.width: solved ? 2 : 1
                            border.color: (pid === page.currentId)
                                          ? Theme.rgba(Theme.highlightColor, 0.70)
                                          : (solved
                                             ? Theme.rgba(Theme.highlightColor, 0.55)
                                             : Theme.rgba(Theme.primaryColor, 0.18))
                        }

                        Label {
                            anchors.centerIn: parent
                            text: (pid + 1)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primaryColor
                        }
                    }
                }
            }
        }
    }
}
