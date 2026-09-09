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

Page {
    id: page
    allowedOrientations: Orientation.All

    readonly property real exampleIconSize: Math.min(
        Theme.itemSizeMedium,
        (width - 4 * Theme.horizontalPageMargin) / 3.4)

    Component {
        id: bulletDelegate

        Item {
            width: parent ? parent.width : page.width
            height: bulletText.implicitHeight + Theme.paddingSmall

            Label {
                id: bullet
                x: Theme.horizontalPageMargin
                text: "•"
                color: Theme.highlightColor
            }

            Label {
                id: bulletText
                anchors.left: bullet.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: modelData
                color: Theme.primaryColor
            }
        }
    }

    Component {
        id: dotsTile

        Item {
            width: page.exampleIconSize
            height: page.exampleIconSize

            Rectangle {
                anchors.fill: parent
                color: "#d6c84b"
                border.width: 2
                border.color: "#6a6a6a"
                radius: Theme.paddingSmall
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.paddingSmall

                Repeater {
                    model: 3
                    Rectangle {
                        width: Math.max(4, page.exampleIconSize * 0.12)
                        height: width
                        radius: width / 2
                        color: "#2d61ff"
                    }
                }
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        VerticalScrollDecorator { }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("Game rules") }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("Place each row's icons into their correct columns. Every icon occurs exactly once in its row; icons in different rows are separate categories and may share the same column.")
            }

            SectionHeader { text: qsTr("Using the board") }

            Repeater {
                model: [
                    qsTr("Tap a small candidate to remove or restore it."),
                    qsTr("Press and hold a candidate to make it certain. If the magnifier is enabled, press and hold to open the larger editor instead."),
                    qsTr("Given cells have a highlighted border and cannot be changed."),
                    qsTr("Use Clear cell in the magnifier to restore every candidate in that cell.")
                ]
                delegate: bulletDelegate
            }

            SectionHeader { text: qsTr("Vertical clues") }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                text: qsTr("Vertical cards compare icons from different rows. Their vertical arrangement refers to columns, not to rows on the board.")
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Same column")
            }

            Item {
                width: parent.width
                height: page.exampleIconSize * 3 + 2 * Theme.paddingSmall

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingLarge

                    Column {
                        spacing: Theme.paddingSmall
                        Components.RuleIcon { row: 0; item: 0; iconSize: page.exampleIconSize }
                        Components.RuleIcon { row: 1; item: 2; iconSize: page.exampleIconSize }
                    }

                    Column {
                        spacing: Theme.paddingSmall
                        Components.RuleIcon { row: 0; item: 4; iconSize: page.exampleIconSize }
                        Components.RuleIcon { row: 2; item: 1; iconSize: page.exampleIconSize }
                        Components.RuleIcon { row: 4; item: 3; iconSize: page.exampleIconSize }
                    }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Two or three icons stacked vertically are all in the same column.")
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Not in the same column")
            }

            Item {
                width: parent.width
                height: page.exampleIconSize * 3 + 2 * Theme.paddingSmall

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingLarge

                    Column {
                        spacing: Theme.paddingSmall
                        Components.RuleIcon { row: 0; item: 1; iconSize: page.exampleIconSize }
                        Components.RuleMarkedIcon { row: 3; item: 2; iconSize: page.exampleIconSize }
                    }

                    Column {
                        spacing: Theme.paddingSmall
                        Components.RuleIcon { row: 0; item: 3; iconSize: page.exampleIconSize }
                        Components.RuleIcon { row: 2; item: 4; iconSize: page.exampleIconSize }
                        Components.RuleMarkedIcon { row: 5; item: 1; iconSize: page.exampleIconSize }
                    }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("A red X means that icon is not in the same column as the other icon, or as the aligned pair above it.")
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Either/or column")
            }

            Item {
                width: parent.width
                height: page.exampleIconSize * 3.5 + 2 * Theme.paddingSmall

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall
                    Components.RuleIcon { row: 0; item: 5; iconSize: page.exampleIconSize }
                    Components.RuleIcon { row: 1; item: 1; iconSize: page.exampleIconSize }
                    Label {
                        width: page.exampleIconSize
                        horizontalAlignment: Text.AlignHCenter
                        text: "↕"
                        color: "yellow"
                        font.bold: true
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    Components.RuleIcon { row: 4; item: 0; iconSize: page.exampleIconSize }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("The first icon shares a column with exactly one of the other two icons.")
            }

            SectionHeader { text: qsTr("Horizontal clues") }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Somewhere to the left")
            }

            Item {
                width: parent.width
                height: page.exampleIconSize

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall
                    Components.RuleIcon { row: 2; item: 1; iconSize: page.exampleIconSize }
                    Loader { sourceComponent: dotsTile }
                    Components.RuleIcon { row: 2; item: 3; iconSize: page.exampleIconSize }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Two icons separated by dots mean the first is somewhere to the left of the second.")
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Next to / between")
            }

            Item {
                width: parent.width
                height: page.exampleIconSize * 2 + Theme.paddingSmall

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0
                        Components.RuleIcon { row: 3; item: 1; iconSize: page.exampleIconSize }
                        Components.RuleIcon { row: 3; item: 2; iconSize: page.exampleIconSize }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0
                        Components.RuleIcon { row: 4; item: 1; iconSize: page.exampleIconSize }
                        Components.RuleIcon { row: 4; item: 2; iconSize: page.exampleIconSize }
                        Components.RuleIcon { row: 4; item: 3; iconSize: page.exampleIconSize }
                    }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Touching icons are in neighbouring columns. With three icons, the middle picture is between the outer pair in three consecutive columns.")
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Not next to / not between")
            }

            Item {
                width: parent.width
                height: page.exampleIconSize * 2 + Theme.paddingSmall

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0
                        Components.RuleIcon { row: 5; item: 0; iconSize: page.exampleIconSize }
                        Components.RuleMarkedIcon { row: 5; item: 3; iconSize: page.exampleIconSize }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0
                        Components.RuleIcon { row: 1; item: 0; iconSize: page.exampleIconSize }
                        Components.RuleMarkedIcon { row: 1; item: 3; iconSize: page.exampleIconSize }
                        Components.RuleIcon { row: 1; item: 5; iconSize: page.exampleIconSize }
                    }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("The crossed icon is not next to the other icon. In the three-icon form, the outer pictures are two columns apart and the crossed picture is not between them.")
            }

            SectionHeader { text: qsTr("Game actions") }

            Repeater {
                model: [
                    qsTr("Restart clears the current puzzle after a brief confirmation delay."),
                    qsTr("Undo and Redo move through your recent board states."),
                    qsTr("Verify highlights cells where the correct candidate has been removed."),
                    qsTr("Hint highlights a clue, a cell and the candidate to change. A check mark means make it certain; a cross means remove it. Tap Apply hint to perform the move."),
                    qsTr("Tap a clue to dim it in greyscale. Tap it again to restore its colours."),
                    qsTr("The timer starts with your first board action. Completed times appear on the Scores page.")
                ]
                delegate: bulletDelegate
            }
        }
    }
}
