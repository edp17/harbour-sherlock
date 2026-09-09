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
import QtQuick 2.0
import Nemo.Configuration 1.0

ConfigurationGroup {
    id: settings
    path: "/harbour-sherlock"

    property int boardSize: 6
    property string playerName: ""
    property bool magnifierEnabled: false
    property bool autoCompleteEnabled: false

    // 0=Easy, 1=Medium, 2=Hard
    property int difficulty: 1
}
