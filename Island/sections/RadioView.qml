// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Common"

// Панель «Радио» внутри острова (порт плагина online-radio для Noctalia Shell):
// сетка станций, воспроизведение через cvlc, метаданные (артист/трек) из icy-заголовков.
// Служебная информация пишется и читается из ~/.config/minimo-os/radio.json
// (в плагине для этого использовался pluginSettings).
Item {
    id: root
    signal back()

    // ───────────────────────── Файл состояния ─────────────────────────
    readonly property string dir: Quickshell.env("HOME") + "/.config/minimo-os"
    readonly property string fileUrl: "file://" + dir + "/radio.json"

    property bool loaded: false
    property var stations: []                  // [{ name, url }]
    property string currentPlayingStation: ""
    property string currentPlayingProcessState: ""
    property string currentTrack: ""
    property string currentArtist: ""

    readonly property bool isPlaying: currentPlayingStation !== "" && currentPlayingProcessState === "start"

    function stationAt(name) { return stations.find(s => s.name === name) ?? null }

    // ─────────────────────── Чтение / запись radio.json ───────────────────────
    // Читаем всегда (даже при running: true): файл мог измениться извне.
    Process {
        id: catProc
        running: true
        command: ["sh", "-c", "cat '" + root.dir + "/radio.json' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.applyState(text)
        }
        onExited: {
            if (!root.loaded)
                loadDefaults.restart()
        }
    }

    // Встроенный список станций по умолчанию (копия assets/radio.json):
    // используется только если ~/.config/minimo-os/radio.json отсутствует.
    readonly property string defaultStationsJson: JSON.stringify([
        { name: "Radio Record", url: "https://radiorecord.hostingradio.ru/rr_main96.aacp" },
        { name: "Europa Plus", url: "http://ep2143.eurospica.europaplus.ru/europaplus2143-128.mp3" },
        { name: "DFM", url: "http://dfm.hostingradio.ru/dfm96.aacp" },
        { name: "Retro FM", url: "http://retrofm.streamr.ru/retro96.aacp" },
        { name: "Хит FM", url: "http://hitfm.streamr.ru/hit96.aacp" },
        { name: "Радио Шансон", url: "http://chansons.streamr.ru/chanson96.aacp" },
        { name: "Русское Радио", url: "http://rum96.streamr.ru/rum96.aacp" },
        { name: "Дорожное Радио", url: "http://drtg.streamr.ru/dor96.aacp" },
        { name: "Comedy Radio", url: "http://comedy.streamr.ru/comedy128k" },
        { name: "Like FM", url: "http://likefm.streamr.ru/like96.aacp" },
        { name: "Vox FM", url: "http://vox96.streamr.ru/vox96.aacp" },
        { name: "Best-FM", url: "http://bestfm.streamr.ru/best96.aacp" },
        { name: "Радио JAZZ", url: "http://jazz.streamr.ru/jazz96.aacp" },
        { name: "Energy", url: "http://energy.streamr.ru/energy96.aacp" },
        { name: "Studio", url: "http://studio.streamr.ru/studio96.aacp" },
        { name: "Ultra", url: "http://ultra.streamr.ru/ultra96.aacp" },
        { name: "Korporator", url: "http://korporator.streamr.ru/korp96.aacp" },
        { name: "FRESH", url: "http://fresh.streamr.ru/fresh96.aacp" },
        { name: "Radiomayak", url: "http://radio.mayak.info/radio/mayak.m3u" },
        { name: "Orbit", url: "http://orbit.streamr.ru/orbit96.aacp" },
        { name: "TNT", url: "http://tnt.streamr.ru/tnt96.aacp" },
        { name: "Maximum", url: "http://maximum.streamr.ru/maximum96.aacp" },
        { name: "Nashe Radio", url: "http://nashe.streamr.ru/nashe96.aacp" }
    ])

    Timer {
        id: loadDefaults
        interval: 150
        repeat: false
        onTriggered: {
            if (root.loaded)
                return
            var list = []
            try {
                var j = JSON.parse(root.defaultStationsJson)
                if (Array.isArray(j))
                    list = j.map(s => ({ name: s.name || "", url: s.url || "" })).filter(s => s.name && s.url)
            } catch (e) {
                console.warn("RadioView: не удалось разобрать список станций по умолчанию:", e)
            }
            root.stations = list
            root.loaded = true
            root.save()   // создаём ~/.config/minimo-os/radio.json (только если файла ещё нет)
        }
    }

    function applyState(text) {
        var st = null
        if (text && text.trim() !== "") {
            try {
                st = JSON.parse(text)
            } catch (e) {
                console.warn("RadioView: radio.json inválido:", e)
            }
        }
        if (st && typeof st === "object") {
            root.currentPlayingStation = st.currentPlayingStation || ""
            root.currentPlayingProcessState = st.currentPlayingProcessState || ""
            root.currentTrack = st.currentTrack || ""
            root.currentArtist = st.currentArtist || ""
            if (Array.isArray(st.stations))
                root.stations = st.stations.map(s => ({ name: s.name || "", url: s.url || "" })).filter(s => s.name && s.url)
            root.loaded = true
        } else {
            loadDefaults.restart()
        }
        // При перезапуске оболочки процесс уже не жив — состояние «игралось» сбрасываем.
        if (root.currentPlayingProcessState === "start")
            root.stopPlayback()
    }

    function serialize() {
        return JSON.stringify({
            stations: root.stations,
            currentPlayingStation: root.currentPlayingStation,
            currentPlayingProcessState: root.currentPlayingProcessState,
            currentTrack: root.currentTrack,
            currentArtist: root.currentArtist
        }, null, 2)
    }

    function save() {
        if (!loaded) return                 // никогда не pisar el archivo antes de leerlo
        writeProc.command = ["sh", "-c", "mkdir -p '" + root.dir + "' && cat > '" + root.dir + "/radio.json'", root.serialize()]
        writeProc.running = true
    }
    Process {
        id: writeProc
        running: false
    }

    // ───────────────────────── Воспроизведение (cvlc) ─────────────────────────
    function playStation(name) {
        var st = stationAt(name)
        if (!st)
            return
        stopPlayback()
        currentPlayingStation = name
        currentPlayingProcessState = "start"
        currentTrack = ""
        currentArtist = ""
        save()
        cvlcProcess.running = true
    }

    function stopPlayback() {
        cvlcProcess.running = false
        killProc.command = ["sh", "-c", "kill -9 $(ps aux | grep -E '[c]vlc|[v]lc' | awk '{print $2}') 2>/dev/null || true"]
        killProc.running = true
        currentPlayingStation = ""
        currentPlayingProcessState = ""
        save()
    }
    Process {
        id: killProc
        running: false
    }

    // Команда строится в момент запуска (как binding — иначе перезапускалась бы на каждое событие).
    property var cvlcCommand: []
    Process {
        id: cvlcProcess
        running: false
        command: root.cvlcCommand
        stdout: SplitParser {
            onRead: data => root.parseMetadata(data)
        }
        stderr: SplitParser {
            onRead: data => root.parseMetadata(data)
        }
        onStarted: {
            currentTrack = ""
            currentArtist = ""
            save()
        }
        onExited: {
            if (root.currentPlayingStation !== "")
                root.stopPlayback()
        }
    }

    function toggle(name) {
        if (isPlaying && currentPlayingStation === name) {
            stopPlayback()
        } else if (isPlaying) {
            // Останавливаем и играем новую с паузой, чтобы cvlc успел освободить устройства.
            stopPlayback()
            switchTimer.stationToPlay = name
            switchTimer.restart()
        } else {
            buildCommand(name)
            playStation(name)
        }
    }
    Timer {
        id: switchTimer
        interval: 100
        repeat: false
        property string stationToPlay: ""
        onTriggered: {
            if (stationToPlay) {
                root.buildCommand(stationToPlay)
                root.playStation(stationToPlay)
                stationToPlay = ""
            }
        }
    }

    function buildCommand(name) {
        var st = stationAt(name)
        if (!st) {
            root.cvlcCommand = ["true"]
            return
        }
        root.cvlcCommand = ["sh", "-c", "cvlc -vvv --intf dummy " + st.url.replace(/'/g, "'\"'\"'") + " 2>&1"]
    }

    // ───────────────────────── Метаданные (icy) ─────────────────────────
    function parseMetadata(line) {
        var icyTitleMatch = line.match(/New Icy-Title=(.+)$/i)
        if (icyTitleMatch) {
            parseArtistTitle(icyTitleMatch[1].trim())
            return
        }
        var icyNameMatch = line.match(/Icy-Name:\s*(.+)/i)
        if (icyNameMatch)
            return
    }

    function parseArtistTitle(text) {
        text = text.trim()
        const separators = [" - ", " – ", " — ", ": ", " | ", " / ", " by "]
        for (var i = 0; i < separators.length; i++) {
            const sep = separators[i]
            const index = text.indexOf(sep)
            if (index > 0) {
                currentArtist = text.substring(0, index).trim()
                currentTrack = text.substring(index + sep.length).trim()
                save()
                return
            }
        }
        currentArtist = ""
        currentTrack = text
        save()
    }

    // ───────────────────────── Сетка станций ─────────────────────────
    property int currentIndex: 0
    readonly property int columns: 3
    readonly property real cellSpacing: 8

    function getImageUrl(stationName) {
        return Qt.resolvedUrl("../assets/radio/" + stationName + ".png")
    }

    function getCurrentRow() { return Math.floor(currentIndex / columns) }
    function getCurrentColumn() { return currentIndex % columns }

    // Posicionamiento sin enums de GridView/ListView (no disponibles en quickshell):
    // desplaza el grid para que la celda del índice quede visible.
    function ensureVisible() {
        if (gridView.count <= currentIndex || gridView.contentHeight <= gridView.height) return;
        const row = Math.floor(currentIndex / columns);
        const cellTop = row * gridView.cellHeight;
        const cellBottom = cellTop + gridView.cellHeight;
        if (cellTop < gridView.contentY) {
            gridView.contentY = cellTop;
        } else if (cellBottom > gridView.contentY + gridView.height) {
            gridView.contentY = cellBottom - gridView.height;
        }
    }

    function selectStation(index) {
        if (index >= 0 && index < stations.length) {
            currentIndex = index
            Qt.callLater(ensureVisible)
        }
    }

    function moveSelection(deltaX, deltaY) {
        if (stations.length === 0)
            return
        const currentRow = getCurrentRow()
        const currentCol = getCurrentColumn()
        const newRow = currentRow + deltaY
        var newCol = currentCol + deltaX
        var newIndex = newRow * columns + newCol

        if (deltaY !== 0) {
            if (newRow >= 0 && newRow < Math.ceil(stations.length / columns)) {
                const maxColInNewRow = Math.min(columns - 1, stations.length - 1 - newRow * columns)
                if (maxColInNewRow >= 0) {
                    newCol = Math.min(currentCol, maxColInNewRow)
                    selectStation(newRow * columns + newCol)
                }
            }
        } else if (deltaX !== 0) {
            if (newIndex >= 0 && newIndex < stations.length) {
                if (Math.floor(newIndex / columns) === currentRow)
                    selectStation(newIndex)
            }
        }
    }

    function activateCurrentStation() {
        if (currentIndex >= 0 && currentIndex < stations.length)
            toggle(stations[currentIndex].name)
    }

    // Подсветка ячейки, когда станция начала/закончила играть или сменился индекс.
    Connections {
        target: root
        enabled: true
        function onCurrentPlayingStationChanged() { syncIndex() }
    }
    function syncIndex() {
        if (!currentPlayingStation)
            return
        for (var i = 0; i < stations.length; i++) {
            if (stations[i].name === currentPlayingStation) {
                if (currentIndex !== i) {
                    currentIndex = i
                    Qt.callLater(ensureVisible)
                }
                return
            }
        }
    }

    Keys.onUpPressed: moveSelection(0, -1)
    Keys.onDownPressed: moveSelection(0, 1)
    Keys.onLeftPressed: moveSelection(-1, 0)
    Keys.onRightPressed: moveSelection(1, 0)
    Keys.onReturnPressed: activateCurrentStation()
    Keys.onEnterPressed: activateCurrentStation()

    implicitHeight: col.implicitHeight

    component RoundButton: Rectangle {
        id: rb
        property string icon
        property real iconRotation: 0
        signal clicked()
        width: 32; height: 32; radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18; rotation: rb.iconRotation }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Заголовок: кнопка «назад», название, статус воспроизведения.
        Item {
            width: parent.width
            height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                // При играющей станции заголовок меняется на её название.
                text: root.isPlaying ? root.currentPlayingStation : I18n.tr("Radio")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
                width: parent.width - 80
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }
        }

        GridView {
            id: gridView
            width: parent.width
            height: Math.min(contentHeight, 3 * cellHeight)
            model: root.stations
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
                readonly property bool isNowPlaying: root.isPlaying && root.currentPlayingStation === modelData.name
                readonly property bool isActive: isSelected || isHovered || isNowPlaying

                function updateImageVisibility() {
                    if (stationImageSource.status === Image.Ready)
                        stationImage.visible = !isNowPlaying
                }
                onIsNowPlayingChanged: updateImageVisibility()

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.cellSpacing / 4
                    radius: 14
                    color: delegateContainer.isActive ? Theme.hover : Theme.surface

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onContainsMouseChanged: if (containsMouse) root.currentIndex = delegateContainer.index
                        onClicked: {
                            root.currentIndex = delegateContainer.index
                            root.toggle(modelData.name)
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Rectangle {
                            id: imageSquare
                            width: parent.width
                            height: width
                            color: delegateContainer.isNowPlaying ? "transparent" : Theme.field
                            radius: 12
                            clip: true
                            scale: delegateContainer.isActive ? 1.1 : 1.0
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                            transformOrigin: Item.Center

                            // Плейсхолдер (пока нет картинки)
                            Rectangle {
                                id: iconPlaceholder
                                anchors.fill: parent
                                radius: 12
                                color: Theme.field
                                Icon {
                                    anchors.centerIn: parent
                                    name: "music"
                                    size: Math.min(parent.width * 0.4, 34)
                                    tone: "gray"
                                }
                            }

                            // Скрытый источник: всегда грузает картинку (для шейдера)
                            Image {
                                id: stationImageSource
                                anchors.fill: parent
                                source: root.getImageUrl(modelData.name)
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                cache: true
                                asynchronous: true
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

                            // Обычная картинка (только для неиграющих станций)
                            Image {
                                id: stationImage
                                anchors.fill: parent
                                source: stationImageSource.source
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                visible: false
                            }

                            // Волновой шейдер поверх логотипа играющей станции
                            ShaderEffect {
                                id: playingShader
                                anchors.fill: parent
                                visible: delegateContainer.isNowPlaying && stationImageSource.status === Image.Ready
                                property var source: ShaderEffectSource {
                                    sourceItem: stationImageSource
                                    hideSource: true
                                    live: true
                                }
                                property real time: shaderAnimator.animTime
                                property color bgWidget: Theme.card
                                property vector2d resolution: Qt.vector2d(width, height)
                                property color bgColor1: "#2C7BFF"
                                fragmentShader: Qt.resolvedUrl("../assets/radio/ring.qsb")

                                Item {
                                    id: shaderAnimator
                                    property real animTime: 0
                                    NumberAnimation on animTime {
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 1000
                                        duration: 60000
                                        running: playingShader.visible
                                    }
                                }
                            }

                            // Индикатор «сейчас играет»
                            Rectangle {
                                visible: delegateContainer.isNowPlaying
                                anchors { top: parent.top; right: parent.right; margins: 4 }
                                width: 24; height: 24; radius: 12
                                color: Theme.fill
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

            // Пустое состояние
            Text {
                anchors.centerIn: parent
                visible: gridView.count === 0
                text: I18n.tr("No radio stations")
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
            }
        }
    }

    Component.onCompleted: forceActiveFocus()
}
