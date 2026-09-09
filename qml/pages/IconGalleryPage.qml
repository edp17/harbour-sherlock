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

            PageHeader { title: qsTr("SHI tile gallery") }

            Label
            {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                wrapMode: Text.WordWrap
                text: qsTr("Tiles 1–36 map to row-major order (A–F × 1–6). Tile 0 is normally blank.")
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
