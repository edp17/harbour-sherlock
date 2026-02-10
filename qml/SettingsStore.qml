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
