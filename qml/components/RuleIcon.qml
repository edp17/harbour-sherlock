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

    function bundledIconSource() {
        var rr = Math.max(0, Math.min(5, Number(root.row)))
        var ii = Math.max(0, Math.min(5, Number(root.item)))
        var index = rr * 6 + ii + 1
        var prefix = index < 10 ? "0" : ""
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + rr)
        return Qt.resolvedUrl("../assets/generated_icons/" + encodeURIComponent(sherlockEngine.iconTheme)
                              + "/icons_32x32/" + prefix + index + "_"
                              + rowLetter + (ii + 1) + ".png")
    }

    width: iconSize
    height: iconSize

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.primaryColor, 0.06)
        border.width: 1
        border.color: Theme.rgba(Theme.primaryColor, 0.28)
        radius: Theme.paddingSmall
    }

    Image {
        anchors.fill: parent
        anchors.margins: Theme.paddingSmall
        fillMode: Image.PreserveAspectFit
        smooth: false
        sourceSize.width: 32
        sourceSize.height: 32
        // Rules always use the selected built-in artwork, even when no
        // optional SHI art has been imported.
        source: root.bundledIconSource()
    }
}
