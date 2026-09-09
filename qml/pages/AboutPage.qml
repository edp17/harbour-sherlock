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
import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: aboutPage
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Game rules")
                onClicked: pageStack.push(Qt.resolvedUrl("RulesPage.qml"))
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("About") }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(aboutPage.width * (aboutPage.isPortrait ? 0.28 : 0.16),
                                    Theme.itemSizeExtraLarge * 1.5)
                    height: width
                    source: Qt.resolvedUrl("../cover/icon.png")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Sherlock")
                    font.pixelSize: Theme.fontSizeExtraLarge
                    font.bold: true
                    color: Theme.highlightColor
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Classic logic puzzles for Sailfish OS")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Version %1").arg(Qt.application.version
                                                 ? Qt.application.version : "0.2.0")
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryHighlightColor
                }
            }

            Separator {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                color: Theme.highlightColor
            }

            SectionHeader { text: qsTr("About the game") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: Theme.primaryColor
                text: qsTr("Place every icon in its unique column by combining the vertical and horizontal clues. Each puzzle can be solved by logic alone—no guessing is required.")
            }

            SectionHeader { text: qsTr("Highlights") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("• 4×4, 5×5 and 6×6 puzzle boards\n• Easy, medium and hard clue sets\n• Puzzle banks and randomly generated games\n• Scores, undo and redo with saved progress\n• Automatically discovered artwork themes")
            }

            SectionHeader { text: qsTr("Credits") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Developed by: edp17")
                color: Theme.primaryColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeTiny
                text: qsTr("Licensed under GNU GPL 3.0 or later.\nCopyright © 2026 edp17.")
                color: Theme.secondaryColor
            }

            Button {
                text: qsTr("Source code")
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 2 * Theme.horizontalPageMargin,
                                Theme.buttonWidthLarge)
                onClicked: Qt.openUrlExternally("https://github.com/edp17/harbour-sherlock")
            }

            Item { width: 1; height: Theme.paddingLarge }
        }
    }
}
