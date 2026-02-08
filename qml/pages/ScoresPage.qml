import QtQuick 2.0
import Sailfish.Silica 1.0
import "../"

Page {
    id: page

    function fmtTime(sec) {
        sec = Number(sec)
        if (!isFinite(sec) || sec < 0) sec = 0
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function puzzleLabel(rec) {
        var src = rec.source
        if (src === "bank") {
            var id = Number(rec.puzzle)
            if (!isFinite(id)) id = 0
            return "Bank #" + (id + 1)
        }
        return "Random"
    }

    function top10() {
        var arr = sherlockEngine.scores || []
        var copy = []
        for (var i = 0; i < arr.length; ++i) copy.push(arr[i])

        copy.sort(function(a, b) {
            var ta = Number(a.elapsedSeconds); if (!isFinite(ta)) ta = 1e9
            var tb = Number(b.elapsedSeconds); if (!isFinite(tb)) tb = 1e9
            if (ta !== tb) return ta - tb
            var da = String(a.timestamp || "")
            var db = String(b.timestamp || "")
            return (da < db) ? 1 : (da > db ? -1 : 0)
        })

        if (copy.length > 10) copy.length = 10
        return copy
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: "Clear scores"
                onClicked: sherlockEngine.clearScores()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: "Scores" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: "Top 10 quickest games"
            }

            Repeater {
                model: top10()

                delegate: BackgroundItem {
                    width: parent.width
                    height: row.height + Theme.paddingMedium * 2

                    Row {
                        id: row
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        spacing: Theme.paddingLarge
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width * 0.42
                            elide: Text.ElideRight
                            text: puzzleLabel(modelData) + " (" + modelData.size + "×" + modelData.size + ")"
                        }

                        Label {
                            width: parent.width * 0.22
                            horizontalAlignment: Text.AlignRight
                            text: fmtTime(modelData.elapsedSeconds)
                        }

                        Label {
                            width: parent.width * 0.30
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                            text: (modelData.playerName && modelData.playerName.length > 0) ? modelData.playerName : "-"
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }
    }
}
