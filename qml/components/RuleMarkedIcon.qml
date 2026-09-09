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

    property int row: 0
    property int item: 0
    property int iconSize: Theme.itemSizeMedium

    width: iconSize
    height: iconSize

    RuleIcon {
        anchors.fill: parent
        row: root.row
        item: root.item
        iconSize: root.iconSize
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Math.max(2, Math.round(parent.width * 0.07))
        border.color: "red"
        radius: Theme.paddingSmall

        Rectangle {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.92)
            height: Math.max(2, Math.round(parent.width * 0.05))
            color: "red"
            radius: height / 2
            rotation: 45
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.92)
            height: Math.max(2, Math.round(parent.width * 0.05))
            color: "red"
            radius: height / 2
            rotation: -45
        }
    }
}
