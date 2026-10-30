// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import "../../Services"

Item {
    id: root
    signal back()
    signal done()

    readonly property bool isPlaying: RadioService.isPlaying

    property int currentIndex: 0
    readonly property int columns: 3
    readonly property real cellSpacing: 8

    function getImageUrl(stationName) {
        return Qt.resolvedUrl("../../assets/png/" + stationName + ".png")
    }

    function ensureVisible() {
        if (gridView.count <= currentIndex || gridView.contentHeight <= gridView.height) return
        const row = Math.floor(currentIndex / columns)
        const cellTop = row * gridView.cellHeight
        const cellBottom = cellTop + gridView.cellHeight
        if (cellTop < gridView.contentY) gridView.contentY = cellTop
        else if (cellBottom > gridView.contentY + gridView.height) gridView.contentY = cellBottom - gridView.height
    }

    function selectStation(index) {
        if (index >= 0 && index < RadioService.stations.length) {
            currentIndex = index
            Qt.callLater(ensureVisible)
        }
    }

    function moveSelection(deltaX, deltaY) {
        if (RadioService.stations.length === 0) return
        const currentRow = Math.floor(currentIndex / columns)
        const currentCol = currentIndex % columns
        if (deltaY !== 0) {
            const newRow = currentRow + deltaY
            if (newRow >= 0 && newRow < Math.ceil(RadioService.stations.length / columns)) {
                const maxCol = Math.min(columns - 1, RadioService.stations.length - 1 - newRow * columns)
                if (maxCol >= 0) selectStation(newRow * columns + Math.min(currentCol, maxCol))
            }
        } else if (deltaX !== 0) {
            const newIndex = currentRow * columns + currentCol + deltaX
            if (newIndex >= 0 && newIndex < RadioService.stations.length
                && Math.floor(newIndex / columns) === currentRow)
                selectStation(newIndex)
        }
    }

    function activateCurrentStation() {
        if (currentIndex >= 0 && currentIndex < RadioService.stations.length)
            RadioService.toggle(RadioService.stations[currentIndex].name)
    }

    Connections {
        target: RadioService
        function onStateChanged() { syncIndex() }
    }
    function syncIndex() {
        if (!RadioService.currentPlayingStation) return
        for (var i = 0; i < RadioService.stations.length; i++) {
            if (RadioService.stations[i].name === RadioService.currentPlayingStation) {
                if (currentIndex !== i) { currentIndex = i; Qt.callLater(ensureVisible) }
                return
            }
        }
    }

    focus: enabled

    function requestKeyboardFocus() {
        Qt.callLater(function() {
            if (root.enabled && root.visible) root.forceActiveFocus()
        })
        refocusTimer.restart()
    }

    Timer {
        id: refocusTimer
        interval: 200; repeat: false
        onTriggered: if (root.enabled && root.visible && !root.activeFocus) root.forceActiveFocus()
    }

    onEnabledChanged: if (enabled) requestKeyboardFocus()
    Component.onCompleted: requestKeyboardFocus()

    Keys.onEscapePressed: event => { event.accepted = true; root.done() }
    Keys.onUpPressed: event => { event.accepted = true; moveSelection(0, -1) }
    Keys.onDownPressed: event => { event.accepted = true; moveSelection(0, 1) }
    Keys.onLeftPressed: event => { event.accepted = true; moveSelection(-1, 0) }
    Keys.onRightPressed: event => { event.accepted = true; moveSelection(1, 0) }
    Keys.onReturnPressed: event => { event.accepted = true; activateCurrentStation() }
    Keys.onEnterPressed: event => { event.accepted = true; activateCurrentStation() }

    implicitHeight: col.implicitHeight

    component RoundButton: Rectangle {
        id: rb
        property string icon
        signal clicked()
        width: 32; height: 32; radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18 }
        MouseArea {
            id: rbm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            focus: false
            onClicked: { root.forceActiveFocus(); rb.clicked() }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 14

        Item {
            width: parent.width
            height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                width: parent.width - 80
                text: RadioService.isPlaying ? RadioService.currentPlayingStation : I18n.tr("Radio")
                color: Theme.textPrimary; font.family: Theme.font
                font.pixelSize: 15; font.weight: Font.DemiBold
                elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
            }
        }

        GridView {
            id: gridView
            width: parent.width
            height: Math.min(contentHeight, 3 * cellHeight)
            model: RadioService.stations
            cacheBuffer: 100
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentHeight > height
            cellWidth: Math.floor((width - (root.columns - 1) * root.cellSpacing) / root.columns)
            cellHeight: cellWidth + 44

            delegate: Item {
                id: delegateContainer
                required property int index
                required property var modelData
                width: gridView.cellWidth
                height: gridView.cellHeight

                readonly property bool isSelected: index === root.currentIndex
                readonly property bool isHovered: mouseArea.containsMouse
                readonly property bool isNowPlaying: RadioService.isPlaying && RadioService.currentPlayingStation === modelData.name
                readonly property bool isActive: isSelected || isHovered || isNowPlaying

                Rectangle {
                    width: gridView.cellWidth / 2 + 16
                    height: width - 16 + 56
                    anchors.centerIn: parent
                    radius: 14
                    color: delegateContainer.isActive ? Theme.hover : Theme.surface

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        focus: false
                        onContainsMouseChanged: if (containsMouse) root.currentIndex = delegateContainer.index
                        onClicked: {
                            root.forceActiveFocus()
                            root.currentIndex = delegateContainer.index
                            RadioService.toggle(modelData.name)
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Rectangle {
                            width: parent.width
                            height: width
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: delegateContainer.isNowPlaying ? "transparent" : Theme.field
                            radius: 12; clip: true
                            scale: delegateContainer.isActive ? 1.1 : 1.0
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                            transformOrigin: Item.Center

                            Rectangle {
                                id: iconPlaceholder
                                anchors.fill: parent; radius: 12; color: Theme.field
                                Icon { anchors.centerIn: parent; name: "music"; size: Math.min(parent.width * 0.4, 34); tone: "gray" }
                            }

                            Image {
                                id: stationImageSource
                                anchors.fill: parent
                                source: root.getImageUrl(modelData.name)
                                fillMode: Image.PreserveAspectCrop
                                smooth: true; cache: true; asynchronous: true
                                visible: false
                                onStatusChanged: {
                                    if (status === Image.Ready) {
                                        iconPlaceholder.visible = false
                                        stationImage.visible = !delegateContainer.isNowPlaying
                                    } else if (status === Image.Error) {
                                        iconPlaceholder.visible = true
                                        stationImage.visible = false
                                    }
                                }
                            }
                            Image {
                                id: stationImage
                                anchors.fill: parent
                                source: stationImageSource.source
                                fillMode: Image.PreserveAspectCrop
                                smooth: true; visible: false
                            }
                            ShaderEffect {
                                id: playingShader
                                anchors.fill: parent
                                visible: delegateContainer.isNowPlaying && stationImageSource.status === Image.Ready
                                property var source: ShaderEffectSource { sourceItem: stationImageSource; hideSource: true; live: true }
                                property real time: shaderAnimator.animTime
                                property color bgWidget: Theme.card
                                property vector2d resolution: Qt.vector2d(width, height)
                                property color bgColor1: "#2C7BFF"
                                fragmentShader: Qt.resolvedUrl("../../shaders/ring.qsb")
                                Item {
                                    id: shaderAnimator
                                    property real animTime: 0
                                    NumberAnimation on animTime { loops: Animation.Infinite; from: 0; to: 1000; duration: 60000; running: playingShader.visible }
                                }
                            }
                            Rectangle {
                                visible: delegateContainer.isNowPlaying
                                anchors { top: parent.top; right: parent.right; margins: 4 }
                                width: 24; height: 24; radius: 12; color: Theme.fill
                                Icon { anchors.centerIn: parent; name: "volume"; size: 14; tone: "white" }
                            }
                        }

                        Text {
                            width: parent.width
                            text: modelData.name
                            color: delegateContainer.isNowPlaying ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.font
                            font.pixelSize: delegateContainer.isActive ? 13 : 11
                            font.weight: (delegateContainer.isNowPlaying || delegateContainer.isActive) ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            height: 34
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: gridView.count === 0
                text: I18n.tr("No radio stations")
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
            }
        }
    }
}