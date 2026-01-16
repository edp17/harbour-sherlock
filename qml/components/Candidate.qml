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
