import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: aboutPage
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader { title: qsTr("About") }

            // App title
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Sherlock")
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.highlightColor
            }

            // Subtitle (optional)
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("(Logic puzzles)")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            // App icon (match your installed size)
            Image {
                source: "/usr/share/icons/hicolor/86x86/apps/harbour-sherlock.png"
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.22
                height: width
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            // Version
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Version ") + (Qt.application.version ? Qt.application.version : "1.0")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.secondaryColor
            }

            // Description
            Label {
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("A Sailfish OS logic puzzle game inspired by classic DOS Sherlock.\nIncludes puzzle banks, scoring, undo/redo persistence, and DOS-authentic clue semantics.")
                color: Theme.primaryColor
            }

            // Author
            Label {
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Developed by: edp17")
                color: Theme.secondaryColor
            }

            // License + credits
            Label {
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("This project is licensed under GNU GPL 3.0 or later.\nCopyright (c) 2026 edp17.")
                color: Theme.secondaryColor
            }

            // Source link
            Button {
                text: qsTr("Source code")
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - Theme.paddingLarge * 2, Theme.buttonWidthLarge)
                onClicked: Qt.openUrlExternally("https://github.com/edp17/harbour-sherlock")
            }
        }
    }
}
