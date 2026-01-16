import QtQuick 2.6
import Sailfish.Silica 1.0

Page
{
    id: page
    allowedOrientations: Orientation.All

    SilicaFlickable
    {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge

        Column
        {
            id: col
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader { title: "SHI Tile Gallery" }

            Label
            {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                wrapMode: Text.WordWrap
                text: "Tiles 1..36 map to row-major (A..F × 1..6). Tile 0 is typically blank (shown as empty below)."
                color: Theme.secondaryColor
            }

            // 0..36
            Grid
            {
                id: grid
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                spacing: Theme.paddingSmall

                property int cols: page.isPortrait ? 3 : 6
                columns: cols

                property real cell: Math.floor((width - (cols-1)*spacing) / cols)

                Repeater
                {
                    model: 37

                    Item
                    {
                        width: grid.cell
                        height: grid.cell

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.paddingSmall
                            color: Theme.rgba(Theme.highlightBackgroundColor, 0.08)
                            border.color: Theme.rgba(Theme.primaryColor, 0.12)
                            border.width: 1
                        }

                        // Tile index label
                        Label {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: Theme.paddingSmall
                            font.pixelSize: Theme.fontSizeTiny
                            text: index
                            color: Theme.secondaryColor
                        }

                        // Tile image
                        Image
                        {
                            anchors.centerIn: parent
                            width: parent.width * 0.78
                            height: width
                            smooth: false
                            fillMode: Image.PreserveAspectFit

                            source: {
                                if (index === 0) return "" // show blank
                                var k = index - 1
                                var r = Math.floor(k / 6)
                                var i = k % 6
                                return "image://sherlock/r" + r + "_i" + i
                            }
                        }
                    }
                }
            }
        }
    }
}
