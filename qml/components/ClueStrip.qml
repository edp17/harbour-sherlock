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

Item {
    id: root

    // Expected clue shape: { type:int, row:int, col:int, item:int }
    property var clue: ({})
    property bool use16px: false
    property int orient: 1   // 0=Vertical, 1=Horizontal

    property bool showArrow: true
    property bool showPosition: true

    readonly property int iconBankN: 6

    readonly property int posRow: Number(clue && clue.row !== undefined ? clue.row : 0)
    readonly property int posCol: Number(clue && clue.col !== undefined ? clue.col : 0)

    readonly property int iconRow: Number(clue && clue.row !== undefined ? clue.row : 0)
    readonly property int iconItem: Number(clue && clue.item !== undefined ? clue.item : 0)

    readonly property int iconOneBasedIndex: (iconRow * iconBankN + iconItem + 1)

    readonly property string posText: {
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + posRow)
        return rowLetter + (posCol + 1)
    }

    readonly property int iconDisplayPx: Math.max(Theme.iconSizeSmall, 32)
    readonly property int tilePx: Math.max(Theme.iconSizeSmall, 32)

    implicitHeight: Math.max(iconDisplayPx, tilePx) + Theme.paddingSmall * 2
    implicitWidth: row.implicitWidth

    function genFileName(row, item) {
        var idx = row * iconBankN + item + 1
        var idx2 = (idx < 10 ? "0" : "") + idx
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + row)
        var colNumber = item + 1
        return idx2 + "_" + rowLetter + colNumber + ".png"
    }

    readonly property string genIconPath:
        "../assets/generated_icons/" + encodeURIComponent(sherlockEngine.iconTheme) + "/icons_32x32/"
        + genFileName(iconRow, iconItem)
        + "?e=" + sherlockEngine.iconEpoch

    readonly property string shiIconPath:
        ("image://sherlock/" + (use16px ? "16" : "32") + "/" + iconOneBasedIndex
         + "?e=" + sherlockEngine.iconEpoch)
    // Semantics flags (Phase A2): type==0 => given/fixed; type!=0 => derived
    readonly property bool fixed: (clue && clue.type !== undefined) ? (Number(clue.type) === 0) : true
    readonly property bool isCertain: true
    readonly property bool hinted: false
    readonly property bool conflicted: false


    Rectangle {
        anchors.fill: parent
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.primaryColor, 0.06)
        border.width: 1
        border.color: Theme.rgba(Theme.primaryColor, 0.12)
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: Theme.paddingSmall
        spacing: Theme.paddingSmall

        // Icon tile
        Rectangle {
            id: iconTile
            width: iconDisplayPx + Theme.paddingSmall * 2
            height: iconDisplayPx + Theme.paddingSmall * 2
            radius: Theme.paddingSmall / 2
            color: Theme.rgba(Theme.primaryColor, 0.02)
            border.width: root.conflicted ? 3
                       : (root.hinted ? 5
                       : (root.isCertain ? (root.fixed ? 3 : 2) : 1))

            border.color: root.conflicted ? Theme.errorColor
                        : (root.hinted ? Theme.highlightColor
                        : (root.isCertain
                ? (root.fixed ? Theme.highlightColor
                              : Theme.rgba(Theme.highlightColor, 0.65))
                : Theme.rgba(Theme.primaryColor, 0.25)))

            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.centerIn: parent
                width: iconDisplayPx
                height: iconDisplayPx
                smooth: false
                cache: true
                asynchronous: true
                fillMode: Image.PreserveAspectFit

                source: (sherlockEngine.iconSource === 0)
                        ? Qt.resolvedUrl(genIconPath)
                        : shiIconPath
            }
        }

        // Arrow
        Label {
            visible: showArrow
            anchors.verticalCenter: parent.verticalCenter
            text: "\u2192" // →
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.primaryColor
            rotation: (orient === 0) ? 90 : 0
            transformOrigin: Item.Center
        }

        // Position tile (A1)
        Rectangle {
            id: posTile
            visible: showPosition
            width: tilePx + Theme.paddingSmall * 2
            height: tilePx + Theme.paddingSmall * 2
            radius: Theme.paddingSmall / 2
            color: Theme.rgba(Theme.primaryColor, 0.02)
            border.width: 1
            border.color: Theme.rgba(Theme.primaryColor, 0.25)

            anchors.verticalCenter: parent.verticalCenter

            Label {
                anchors.centerIn: parent
                text: posText
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
    }
}
