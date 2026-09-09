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

Item
{
    id: root

    property int rowIndex: 0
    property int itemIndex: 0
    property bool present: true

    signal toggle()
    signal setCertain()

    opacity: present ? 1.0 : 0.25

    Rectangle
    {
        anchors.fill: parent
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.primaryColor, 0.04)
        border.color: Theme.rgba(Theme.primaryColor, 0.12)
        border.width: 1
    }

    Image
    {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        source: "image://sherlock/r" + rowIndex + "_i" + itemIndex
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    MouseArea
    {
        anchors.fill: parent
        onClicked: root.toggle()
        onPressAndHold: root.setCertain()
    }
}
