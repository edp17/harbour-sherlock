import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: pop
    anchors.fill: parent
    visible: false
    z: 10000

    property int row: 0
    property int col: 0
    property real gx: 0
    property real gy: 0
    property real gw: 0
    property real gh: 0
    property int focusItem: -1

    readonly property int n: sherlockEngine.size
    readonly property int iconBankN: 6

    function close() { visible = false }

    function reposition() {
        var margin = Theme.horizontalPageMargin
        var px = gx + gw/2 - card.width/2
        px = Math.max(margin, Math.min(px, width - margin - card.width))

        // prefer above the cell; if not enough room, place below
        var aboveY = gy - Theme.paddingLarge - card.height
        var belowY = gy + gh + Theme.paddingLarge

        var py = aboveY
        if (py < margin) py = belowY
        py = Math.max(margin, Math.min(py, height - margin - card.height))

        card.x = px
        card.y = py
    }

    onVisibleChanged: {
        if (visible) reposition()
    }
    onWidthChanged: if (visible) reposition()
    onHeightChanged: if (visible) reposition()

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

    // Dim background, still lets user see clues behind
    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.highlightDimmerColor, 0.60)
    }

    // Tap outside closes
    MouseArea {
        anchors.fill: parent
        onClicked: pop.close()
    }

    Rectangle {
        id: card
        width: Math.min(parent.width - 2*Theme.horizontalPageMargin, Theme.itemSizeExtraLarge * 5.5)
        height: content.implicitHeight + 2*Theme.paddingLarge
        radius: Theme.paddingLarge
        color: Theme.rgba(Theme.highlightDimmerColor, 0.92)
        border.width: 2
        border.color: Theme.rgba(Theme.primaryColor, 0.35)

        // Swallow clicks inside so outside-tap-close doesn't trigger
        MouseArea { anchors.fill: parent }
        Column {
            id: content
            width: parent.width - 2*Theme.paddingLarge
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            spacing: Theme.paddingLarge

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Label {
                    text: "Row " + String.fromCharCode("A".charCodeAt(0) + pop.row) + " • Col " + (pop.col + 1)
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    width: parent.width - closeBtn.width - Theme.paddingMedium
                    truncationMode: TruncationMode.Fade
                }

                IconButton {
                    id: closeBtn
                    icon.source: "image://theme/icon-m-close"
                    onClicked: pop.close()
                }
            }

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
                    visible: pop.isCertain
                    source: pop.iconSourceFor(pop.row, pop.certainItem)
                }

                Label {
                    anchors.centerIn: parent
                    visible: !pop.isCertain
                    text: "Not certain"
                    color: Theme.secondaryColor
                }
            }

            Grid {
                id: candGrid
                width: parent.width
                readonly property int cols: Math.ceil(pop.n / 2)
                columns: cols
                rows: 2
                spacing: Theme.paddingSmall

                readonly property real cellSize: Math.floor(Math.min(
                    (width - (cols - 1) * spacing) / cols,
                    Theme.iconSizeLarge * 0.90
                ))

                Repeater {
                    model: pop.n

                    Rectangle {
                        width: candGrid.cellSize
                        height: candGrid.cellSize
                        radius: Theme.paddingSmall / 2

                        readonly property int cand: index
                        readonly property bool isOn: ((pop.mask & (1 << cand)) !== 0)

                        color: isOn ? Theme.rgba(Theme.highlightColor, 0.18) : "transparent"
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
                            source: pop.iconSourceFor(pop.row, cand)
                            opacity: isOn ? 1.0 : 0.18
                        }

                        BackgroundItem {
                            anchors.fill: parent
                            highlightedColor: Theme.rgba(Theme.highlightColor, 0.10)
                            enabled: !sherlockEngine.fixedAt(pop.row, pop.col) && !sherlockEngine.solved

                            onClicked: {
                                sherlockEngine.timerOnUserAction()
                                sherlockEngine.toggleCandidate(pop.row, pop.col, cand)
                            }

                            onPressAndHold: {
                                sherlockEngine.timerOnUserAction()
                                sherlockEngine.setCertain(pop.row, pop.col, cand)
                            }
                        }
                    }
                }
            }

            Button {
                text: "Clear cell"
                enabled: !sherlockEngine.fixedAt(pop.row, pop.col) && !sherlockEngine.solved
                onClicked: {
                    sherlockEngine.timerOnUserAction()
                    sherlockEngine.resetCell(pop.row, pop.col)
                }
            }
        }
    }
}
