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

CoverBackground {
    id: cover

    readonly property int totalTiles: sherlockEngine.size * sherlockEngine.size
    readonly property int certainTiles: {
        var masks = sherlockEngine.boardMasks || []
        var count = 0
        for (var i = 0; i < masks.length; ++i) {
            var mask = Number(masks[i])
            if (mask !== 0 && (mask & (mask - 1)) === 0)
                ++count
        }
        return count
    }

    function formatTime(seconds) {
        var value = Math.max(0, Number(seconds))
        var minutes = Math.floor(value / 60)
        var remainder = Math.floor(value % 60)
        return (minutes < 10 ? "0" : "") + minutes + ":"
             + (remainder < 10 ? "0" : "") + remainder
    }

    function puzzleText() {
        if (sherlockEngine.puzzleSource === 0)
            return qsTr("Bank #%1").arg(sherlockEngine.puzzleId + 1)
        return qsTr("Random puzzle")
    }

    function difficultyText() {
        if (sherlockEngine.difficulty === 0) return qsTr("Easy")
        if (sherlockEngine.difficulty === 2) return qsTr("Hard")
        return qsTr("Medium")
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.08)
    }

    Column {
        anchors.top: parent.top
        anchors.topMargin: Theme.paddingLarge
        width: parent.width
        spacing: Theme.paddingSmall

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(cover.width * 0.34, cover.height * 0.22)
            height: width
            source: "icon.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Sherlock")
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: puzzleText() + "  •  " + sherlockEngine.size + "×" + sherlockEngine.size
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: difficultyText()
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeTiny
        }

        Item {
            x: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            height: Theme.paddingMedium

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.rgba(Theme.primaryColor, 0.16)
            }

            Rectangle {
                width: parent.width * Math.min(1, cover.certainTiles / Math.max(1, cover.totalTiles))
                height: parent.height
                radius: height / 2
                color: Theme.highlightColor
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("%1 of %2 tiles placed").arg(cover.certainTiles).arg(cover.totalTiles)
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeTiny
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: formatTime(sherlockEngine.elapsedSeconds)
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
        }
    }
}
