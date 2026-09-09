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

    property string symbol: "?"
    property string text: ""
    signal clicked()

    height: Theme.itemSizeMedium
    opacity: enabled ? 1.0 : 0.35
    Accessible.name: text
    Accessible.role: Accessible.Button

    BackgroundItem {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 0

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.symbol
                font.pixelSize: Theme.fontSizeLarge
                color: parent.parent.highlighted ? Theme.highlightColor : Theme.primaryColor
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.text
                font.pixelSize: Theme.fontSizeExtraSmall
                color: parent.parent.highlighted ? Theme.highlightColor : Theme.secondaryColor
                truncationMode: TruncationMode.Fade
            }
        }
    }
}
