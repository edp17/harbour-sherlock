import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: pop
    anchors.fill: parent
    visible: false
    z: 10000

    // Inputs (set from GamePage when opening)
    property int elapsedSeconds: 0
    property string playerName: ""
    property int difficulty: 1    // 0 Easy, 1 Medium, 2 Hard

    // Optional: allow GamePage to decide what Next does
    signal nextPuzzleRequested()
    signal scoresRequested()

    function open()  { visible = true }
    function close() { visible = false }

    function formatTime(sec) {
        sec = Number(sec)
        if (!isFinite(sec) || sec < 0) sec = 0
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function difficultyName(d) {
        d = Number(d)
        if (d === 0) return "Easy"
        if (d === 1) return "Medium"
        if (d === 2) return "Hard"
        return "" + d
    }

    // Dim background (same as magnifier popup)
    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.highlightDimmerColor, 0.60)
    }

    // Tap outside closes
    MouseArea {
        anchors.fill: parent
        onClicked: pop.close()
    }

    Rectangle {
        id: card
        width: Math.min(parent.width - 2*Theme.horizontalPageMargin,
                        Theme.itemSizeExtraLarge * 5.5)
        height: content.implicitHeight + 2*Theme.paddingLarge
        radius: Theme.paddingLarge
        color: Theme.rgba(Theme.highlightDimmerColor, 0.92)
        border.width: 2
        border.color: Theme.rgba(Theme.primaryColor, 0.35)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        // Swallow clicks inside so outside-tap-close doesn't trigger
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            width: parent.width - 2*Theme.paddingLarge
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            spacing: Theme.paddingLarge

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Label {
                    text: "Solved!"
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    width: parent.width - closeBtn.width - Theme.paddingMedium
                    truncationMode: TruncationMode.Fade
                }

                IconButton {
                    id: closeBtn
                    icon.source: "image://theme/icon-m-close"
                    onClicked: pop.close()
                }
            }

            Label {
                text: "Time: " + formatTime(pop.elapsedSeconds)
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
            }

            Label {
                text: "Player: " + (pop.playerName && pop.playerName.length ? pop.playerName : "—")
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
            }

            Label {
                text: "Difficulty: " + difficultyName(pop.difficulty)
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    text: "Next puzzle"
                    width: (parent.width - Theme.paddingMedium) / 2
                    onClicked: {
                        pop.close()
                        pop.nextPuzzleRequested()
                    }
                }

                Button {
                    text: "Scores"
                    width: (parent.width - Theme.paddingMedium) / 2
                    onClicked: {
                        pop.close()
                        pop.scoresRequested()
                    }
                }
            }
        }
    }
}
