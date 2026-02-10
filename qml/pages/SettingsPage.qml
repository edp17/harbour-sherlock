import QtQuick 2.0
import Sailfish.Silica 1.0

import "../"

Page {
    id: page
    property alias settings: settings

    SettingsStore {
        id: settings
    }

    Component.onCompleted: {
        settings.autoCompleteEnabled = sherlockEngine.autoCompleteEnabled
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: "Settings"
            }

            ComboBox {
                label: "Board size"
                currentIndex: [4,5,6].indexOf(settings.boardSize)
                menu: ContextMenu {
                    MenuItem { text: "4 × 4"; onClicked: settings.boardSize = 4 }
                    MenuItem { text: "5 × 5"; onClicked: settings.boardSize = 5 }
                    MenuItem { text: "6 × 6"; onClicked: settings.boardSize = 6 }
                }
            }

            ComboBox {
                label: "Difficulty"
                currentIndex: Math.max(0, Math.min(2, settings.difficulty))

                menu: ContextMenu {
                    MenuItem { text: "Easy";   onClicked: settings.difficulty = 0 }
                    MenuItem { text: "Medium"; onClicked: settings.difficulty = 1 }
                    MenuItem { text: "Hard";   onClicked: settings.difficulty = 2 }
                }
            }

            TextField {
                label: "Player name"
                text: settings.playerName
                onTextChanged: settings.playerName = text
            }

            TextSwitch {
                text: "Enable magnifier"
                checked: settings.magnifierEnabled
                onCheckedChanged: settings.magnifierEnabled = checked
            }

            TextSwitch {
                text: "Enable autocomplete"
                checked: settings.autoCompleteEnabled

                onCheckedChanged: {
                    settings.autoCompleteEnabled = checked
                    sherlockEngine.setAutoCompleteEnabled(checked)
                }
            }
        }
    }
}
