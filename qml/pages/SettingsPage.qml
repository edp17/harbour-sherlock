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

import "../"

Page {
    id: page
    property alias settings: settings
    allowedOrientations: Orientation.All

    SettingsStore {
        id: settings
    }

    Component.onCompleted: {
        sherlockEngine.refreshIconThemes()
        settings.autoCompleteEnabled = sherlockEngine.autoCompleteEnabled
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Scores")
                onClicked: pageStack.push(Qt.resolvedUrl("ScoresPage.qml"))
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Settings")
            }

            ComboBox {
                label: qsTr("Board size")
                currentIndex: [4,5,6].indexOf(settings.boardSize)
                menu: ContextMenu {
                    MenuItem { text: qsTr("4 × 4"); onClicked: settings.boardSize = 4 }
                    MenuItem { text: qsTr("5 × 5"); onClicked: settings.boardSize = 5 }
                    MenuItem { text: qsTr("6 × 6"); onClicked: settings.boardSize = 6 }
                }
            }

            ComboBox {
                label: qsTr("Difficulty")
                currentIndex: Math.max(0, Math.min(2, settings.difficulty))

                menu: ContextMenu {
                    MenuItem { text: qsTr("Easy");   onClicked: settings.difficulty = 0 }
                    MenuItem { text: qsTr("Medium"); onClicked: settings.difficulty = 1 }
                    MenuItem { text: qsTr("Hard");   onClicked: settings.difficulty = 2 }
                }
            }

            ComboBox {
                label: qsTr("Icon theme")
                enabled: sherlockEngine.availableIconThemes.length > 0
                currentIndex: enabled
                              ? Math.max(0, sherlockEngine.availableIconThemes.indexOf(sherlockEngine.iconTheme))
                              : -1

                menu: ContextMenu {
                    Repeater {
                        model: sherlockEngine.availableIconThemes

                        delegate: MenuItem {
                            text: modelData
                            onClicked: sherlockEngine.setIconTheme(modelData)
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: sherlockEngine.availableIconThemes.length === 0
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("No valid icon themes were found.")
            }

            Image {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: visible ? Math.min(page.height * 0.42, width * 0.78) : 0
                visible: sherlockEngine.iconTheme.length > 0
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                sourceSize.width: width
                source: Qt.resolvedUrl("../assets/generated_icons/"
                                       + encodeURIComponent(sherlockEngine.iconTheme)
                                       + "/theme_preview.png")
            }

            TextField {
                label: qsTr("Player name")
                placeholderText: qsTr("Player")
                text: settings.playerName
                onTextChanged: settings.playerName = text
            }

            TextSwitch {
                text: qsTr("Enable magnifier")
                checked: settings.magnifierEnabled
                onCheckedChanged: settings.magnifierEnabled = checked
            }

            TextSwitch {
                text: qsTr("Enable autocomplete")
                checked: settings.autoCompleteEnabled

                onCheckedChanged: {
                    settings.autoCompleteEnabled = checked
                    sherlockEngine.setAutoCompleteEnabled(checked)
                }
            }
        }
    }
}
