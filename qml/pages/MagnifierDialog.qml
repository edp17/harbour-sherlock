import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: dlg

    // Passed in from GamePage
    property int row: 0
    property int col: 0
    property int focusItem: -1

    readonly property int n: sherlockEngine.size
    readonly property int iconBankN: 6

    function genIconFileName(rr, ii) {
        var baseN = 6
        rr = Number(rr)
        ii = Number(ii)
        if (!isFinite(rr) || !isFinite(ii)) return ""
        rr = Math.max(0, Math.min(baseN - 1, rr))
        ii = Math.max(0, Math.min(baseN - 1, ii))
        var idx = rr * baseN + ii + 1
        var idx2 = (idx < 10 ? "0" : "") + idx
        var rowLetter = String.fromCharCode("A".charCodeAt(0) + rr)
        var colNumber = ii + 1
        return idx2 + "_" + rowLetter + colNumber + ".png"
    }

    function iconSourceFor(rr, ii) {
        rr = Number(rr)
        ii = Number(ii)
        if (!isFinite(rr) || !isFinite(ii)) return ""
        if (sherlockEngine.iconSource === 0) {
            var fn = genIconFileName(rr, ii)
            if (fn === "") return ""
            return Qt.resolvedUrl("../assets/generated_icons/icons_32x32/" + fn) + "?e=" + sherlockEngine.iconEpoch
        }
        // SHI provider uses rX_iY format
        rr = Math.max(0, Math.min(iconBankN - 1, rr))
        ii = Math.max(0, Math.min(iconBankN - 1, ii))
        return "image://sherlock/r" + rr + "_i" + ii + "?e=" + sherlockEngine.iconEpoch
    }

    readonly property int mask: {
        var list = sherlockEngine.boardMasks
        var i = row * n + col
        if (!list || list.length !== n*n) return (1 << n) - 1
        return Number(list[i])
    }

    readonly property bool isCertain: (mask !== 0) && ((mask & (mask - 1)) === 0)

    readonly property int certainItem: {
        for (var i = 0; i < n; ++i) {
            if ((mask & (1 << i)) !== 0) return i
        }
        return 0
    }

    allowedOrientations: Orientation.All

    Column {
        width: parent.width
        spacing: Theme.paddingLarge

        DialogHeader {
            title: "Cell"
            acceptText: "Close"
        }

        Label {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.horizontalPageMargin
            text: "Row " + String.fromCharCode("A".charCodeAt(0) + row) + "  •  Col " + (col + 1)
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
        }

        // Big current choice (if certain)
        Item {
            width: parent.width
            height: Theme.iconSizeLarge + Theme.paddingLarge

            Image {
                anchors.centerIn: parent
                width: Theme.iconSizeLarge
                height: Theme.iconSizeLarge
                fillMode: Image.PreserveAspectFit
                smooth: false
                cache: true
                asynchronous: true
                visible: dlg.isCertain
                source: iconSourceFor(dlg.row, dlg.certainItem)
            }

            Label {
                anchors.centerIn: parent
                visible: !dlg.isCertain
                text: "Not certain"
                color: Theme.secondaryColor
            }
        }

        // Candidate grid (big)
        Grid {
            id: candGrid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.horizontalPageMargin

            readonly property int cols: Math.ceil(dlg.n / 2)
            columns: cols
            rows: 2
            spacing: Theme.paddingSmall

            readonly property real cellSize: Math.floor(Math.min(
                (width - (cols - 1) * spacing) / cols,
                Theme.iconSizeLarge * 0.85
            ))

            Repeater {
                model: dlg.n

                Rectangle {
                    width: candGrid.cellSize
                    height: candGrid.cellSize
                    radius: Theme.paddingSmall / 2

                    readonly property int cand: index
                    readonly property bool isOn: ((dlg.mask & (1 << cand)) !== 0)

                    color: isOn ? Theme.rgba(Theme.highlightColor, 0.18) : Theme.rgba(Theme.primaryColor, 0.00)
                    border.width: 1
                    border.color: isOn ? Theme.rgba(Theme.primaryColor, 0.30) : Theme.rgba(Theme.primaryColor, 0.18)

                    Image {
                        anchors.centerIn: parent
                        width: parent.width * 0.90
                        height: width
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        cache: true
                        asynchronous: true
                        source: dlg.iconSourceFor(dlg.row, cand)
                        opacity: isOn ? 1.0 : 0.18
                    }

                    // Tap = toggle candidate, Hold = set certain
                    BackgroundItem {
                        anchors.fill: parent
                        highlightedColor: Theme.rgba(Theme.highlightColor, 0.10)
                        enabled: !sherlockEngine.fixedAt(dlg.row, dlg.col) && !sherlockEngine.solved

                        onClicked: {
                            sherlockEngine.timerOnUserAction()
                            sherlockEngine.toggleCandidate(dlg.row, dlg.col, cand)
                        }

                        onPressAndHold: {
                            sherlockEngine.timerOnUserAction()
                            sherlockEngine.setCertain(dlg.row, dlg.col, cand)
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            Button {
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                text: "Clear cell"
                enabled: !sherlockEngine.fixedAt(dlg.row, dlg.col) && !sherlockEngine.solved
                onClicked: {
                    sherlockEngine.timerOnUserAction()
                    sherlockEngine.resetCell(dlg.row, dlg.col)
                }
            }
        }

        Item { width: 1; height: Theme.paddingLarge }
    }
}
