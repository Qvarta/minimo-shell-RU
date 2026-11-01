// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Qvarta — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "../../Common"

// Transmission torrent manager for the island.
Item {
    id: root

    signal back()
    signal done()

    property bool daemonRunning: false
    property bool loading: false
    property string errorMessage: ""
    property var listOutput: []
    property var actionCommand: []

    implicitHeight: content.implicitHeight

    ListModel {
        id: torrentModel
    }

    function checkDaemonStatus() {
        if (!statusProcess.running)
            statusProcess.running = true
    }

    function refreshTorrents() {
        if (root.daemonRunning && !listProcess.running) {
            root.listOutput = []
            listProcess.running = true
        }
    }

    function statusName(status) {
        switch (status) {
        case "downloading": return I18n.tr("Downloading")
        case "seeding": return I18n.tr("Seeding")
        case "completed": return I18n.tr("Completed")
        case "stopped": return I18n.tr("Paused")
        case "verifying": return I18n.tr("Verifying")
        case "queued": return I18n.tr("Queued")
        case "idle": return I18n.tr("Idle")
        default: return I18n.tr("Unknown status")
        }
    }

    function parseStatus(code, finished) {
        let status = "unknown"
        switch (code) {
        case 0: status = "stopped"; break
        case 1: status = "queued"; break
        case 2: status = "verifying"; break
        case 3: status = "queued"; break
        case 4: status = "downloading"; break
        case 5: status = "queued"; break
        case 6: status = "seeding"; break
        }
        if (finished && status === "queued")
            status = "completed"
        return status
    }

    function parseTorrent(torrent) {
        if (!torrent || torrent.id === undefined || !torrent.name)
            return null

        let percent = 0
        if (torrent.size_when_done > 0) {
            const left = torrent.left_until_done !== undefined
                ? torrent.left_until_done
                : (torrent.leftUntilDone || 0)
            percent = Math.round(((torrent.size_when_done - left) / torrent.size_when_done) * 100)
        } else if (torrent.percent_done !== undefined) {
            percent = Math.round(torrent.percent_done * 100)
        } else if (torrent.percentDone !== undefined) {
            percent = Math.round(torrent.percentDone * 100)
        }

        percent = Math.max(0, Math.min(100, percent))
        const finished = torrent.is_finished !== undefined ? torrent.is_finished : torrent.isFinished
        return {
            torrentId: Number(torrent.id),
            name: String(torrent.name),
            percent: percent,
            status: torrent.status !== undefined ? parseStatus(torrent.status, finished) : "unknown"
        }
    }

    function parseAndUpdateTorrents(output) {
        try {
            const json = JSON.parse(output)
            const torrents = json.arguments?.torrents ?? json.result?.torrents
            if (!Array.isArray(torrents))
                throw new Error("Transmission returned an unexpected torrent list")

            torrentModel.clear()
            for (const torrent of torrents) {
                const parsed = parseTorrent(torrent)
                if (parsed)
                    torrentModel.append(parsed)
            }
            root.errorMessage = ""
        } catch (error) {
            root.errorMessage = I18n.tr("Couldn't read the torrent list")
            console.warn("Transmission:", error)
        }
    }

    function runTorrentAction(args) {
        if (!root.daemonRunning) {
            root.errorMessage = I18n.tr("Transmission daemon is not running")
            return false
        }
        if (actionProcess.running)
            return false

        root.loading = true
        root.actionCommand = ["transmission-remote"].concat(args)
        actionProcess.running = true
        return true
    }

    function addMagnet() {
        const magnet = magnetInput.text.trim()
        if (!magnet.startsWith("magnet:?")) {
            root.errorMessage = I18n.tr("Enter a valid magnet link")
            return
        }
        if (root.runTorrentAction(["-a", magnet]))
            magnetInput.text = ""
    }

    function addTorrentFile(path) {
        if (!path)
            return
        root.runTorrentAction(["-a", path])
    }

    function startDaemon() {
        if (startProcess.running)
            return
        root.loading = true
        root.errorMessage = ""
        startCheckTimer.attempts = 0
        startCheckTimer.start()
        startProcess.running = true
    }

    function stopDaemon() {
        if (stopProcess.running)
            return
        root.loading = true
        root.errorMessage = ""
        stopProcess.running = true
    }

    onEnabledChanged: {
        if (enabled) {
            root.errorMessage = ""
            root.checkDaemonStatus()
        }
    }

    Component.onCompleted: {
        if (enabled)
            root.checkDaemonStatus()
    }

    Keys.onEscapePressed: event => {
        event.accepted = true
        root.done()
    }

    Timer {
        id: refreshTimer
        interval: 5000
        repeat: true
        running: root.enabled && root.daemonRunning
        onTriggered: root.refreshTorrents()
    }

    Timer {
        id: startCheckTimer
        interval: 1000
        repeat: true
        property int attempts: 0
        onTriggered: {
            if (root.daemonRunning) {
                stop()
                attempts = 0
                return
            }
            if (attempts >= 12) {
                stop()
                root.loading = false
                root.errorMessage = I18n.tr("Could not start Transmission")
                attempts = 0
                return
            }
            attempts++
            root.checkDaemonStatus()
        }
    }

    Timer {
        id: refreshLater
        interval: 500
        onTriggered: root.refreshTorrents()
    }

    Process {
        id: statusProcess
        command: ["transmission-remote", "--session-info"]
        running: false
        onExited: (exitCode, exitStatus) => {
            root.loading = false
            if (exitCode === 0) {
                root.daemonRunning = true
                root.errorMessage = ""
                root.refreshTorrents()
            } else {
                root.daemonRunning = false
                torrentModel.clear()
                if (root.enabled)
                    root.errorMessage = I18n.tr("Transmission daemon is not running")
            }
        }
    }

    Process {
        id: listProcess
        command: ["transmission-remote", "-j", "-l"]
        running: false
        stdout: SplitParser {
            onRead: data => root.listOutput.push(data)
        }
        onStarted: root.listOutput = []
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.parseAndUpdateTorrents(root.listOutput.join("\n"))
                root.daemonRunning = true
            } else {
                root.daemonRunning = false
                torrentModel.clear()
                root.errorMessage = I18n.tr("Couldn't read the torrent list")
            }
            root.loading = false
            root.listOutput = []
        }
    }

    Process {
        id: startProcess
        command: ["transmission-daemon"]
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                startCheckTimer.stop()
                root.loading = false
                root.errorMessage = I18n.tr("Could not start Transmission")
            }
        }
    }

    Process {
        id: stopProcess
        command: ["transmission-remote", "--exit"]
        running: false
        onExited: (exitCode, exitStatus) => {
            root.loading = false
            if (exitCode === 0) {
                refreshTimer.stop()
                root.daemonRunning = false
                torrentModel.clear()
                root.errorMessage = ""
            } else {
                root.errorMessage = I18n.tr("Could not stop Transmission")
            }
        }
    }

    Process {
        id: actionProcess
        command: root.actionCommand
        running: false
        stderr: SplitParser {
            onRead: data => console.warn("Transmission:", data)
        }
        onExited: (exitCode, exitStatus) => {
            root.loading = false
            if (exitCode === 0) {
                root.errorMessage = ""
                refreshLater.restart()
            } else {
                root.errorMessage = I18n.tr("Transmission command failed")
            }
        }
    }

    FileDialog {
        id: torrentFileDialog
        title: I18n.tr("Choose a torrent file")
        fileMode: FileDialog.OpenFile
        nameFilters: ["Torrent files (*.torrent)", "All files (*)"]
        onAccepted: root.addTorrentFile(selectedFile.toLocalFile())
    }

    Column {
        id: content
        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 34

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: backMouse.containsMouse ? Theme.hover : Theme.surface
                Icon { anchors.centerIn: parent; name: "back"; size: 18 }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 92
                text: I18n.tr("Torrents")
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Rectangle {
                anchors.right: parent.right
                width: 32
                height: 32
                radius: 16
                color: daemonMouse.containsMouse ? Theme.hover : Theme.surface
                Icon { anchors.centerIn: parent; name: "power"; size: 17 }
                MouseArea {
                    id: daemonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.daemonRunning ? root.stopDaemon() : root.startDaemon()
                }
            }
        }

        Row {
            width: parent.width
            spacing: 8
            Text {
                width: parent.width - refreshButton.width - 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.daemonRunning
                    ? I18n.tr("Transmission daemon is running") + " · " + I18n.tr("%1 torrents", torrentModel.count)
                    : I18n.tr("Transmission daemon is not running")
                color: root.daemonRunning ? Theme.textSecondary : Theme.danger
                font.family: Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Rectangle {
                id: refreshButton
                width: 28
                height: 28
                radius: 14
                color: refreshMouse.containsMouse ? Theme.hover : Theme.surface
                Text { anchors.centerIn: parent; text: "↻"; color: Theme.textPrimary; font.pixelSize: 18 }
                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.checkDaemonStatus()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: addColumn.implicitHeight + 20
            radius: 16
            color: Theme.surface

            Column {
                id: addColumn
                x: 10
                y: 10
                width: parent.width - 20
                spacing: 8

                Text {
                    text: I18n.tr("Add torrent")
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 12
                    color: Theme.field
                    TextInput {
                        id: magnetInput
                        anchors.fill: parent
                        anchors.margins: 10
                        color: Theme.textPrimary
                        selectionColor: Theme.fill
                        selectedTextColor: Theme.onAccent
                        font.family: Theme.font
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        onAccepted: root.addMagnet()
                    }
                    Text {
                        anchors.fill: magnetInput
                        verticalAlignment: Text.AlignVCenter
                        text: I18n.tr("Paste a magnet link…")
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                        visible: magnetInput.text.length === 0
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 34
                        radius: 17
                        color: addMagnetMouse.containsMouse ? Theme.hover : Theme.fill
                        Text {
                            anchors.centerIn: parent
                            text: I18n.tr("Add magnet")
                            color: Theme.onAccent
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: addMagnetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addMagnet()
                        }
                    }

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 34
                        radius: 17
                        color: fileMouse.containsMouse ? Theme.hover : Theme.field
                        Text {
                            anchors.centerIn: parent
                            text: I18n.tr("Choose .torrent file")
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: fileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: torrentFileDialog.open()
                        }
                    }
                }
            }
        }

        Text {
            visible: root.errorMessage !== ""
            width: parent.width
            text: root.errorMessage
            color: Theme.danger
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Text {
            visible: !root.daemonRunning && root.errorMessage === ""
            width: parent.width
            topPadding: 12
            bottomPadding: 12
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("Start Transmission to see your torrents")
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Text {
            visible: root.daemonRunning && torrentModel.count === 0
            width: parent.width
            topPadding: 16
            bottomPadding: 16
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("No torrents yet")
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 12
        }

        Flickable {
            width: parent.width
            visible: root.daemonRunning && torrentModel.count > 0
            height: visible ? Math.min(torrentRows.implicitHeight, 360) : 0
            contentHeight: torrentRows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: torrentRows
                width: parent.width
                spacing: 8

                Repeater {
                    model: torrentModel
                    delegate: Rectangle {
                        id: torrentCard
                        required property int torrentId
                        required property string name
                        required property int percent
                        required property string status
                        width: torrentRows.width
                        height: 84
                        radius: 14
                        color: Theme.surface

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    width: parent.width - percentLabel.width - 6
                                    text: torrentCard.name
                                    color: Theme.textPrimary
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: percentLabel
                                    text: torrentCard.percent + "%"
                                    color: Theme.textSecondary
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.track
                                Rectangle {
                                    width: parent.width * torrentCard.percent / 100
                                    height: parent.height
                                    radius: 2
                                    color: torrentCard.status === "stopped" ? Theme.danger : Theme.fill
                                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    width: parent.width - actionButtons.width - 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.statusName(torrentCard.status)
                                    color: Theme.textSecondary
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                                Row {
                                    id: actionButtons
                                    spacing: 5
                                    Rectangle {
                                        width: 56
                                        height: 22
                                        radius: 11
                                        color: pauseMouse.containsMouse ? Theme.hover : Theme.field
                                        Text {
                                            anchors.centerIn: parent
                                            text: torrentCard.status === "stopped" ? I18n.tr("Resume") : I18n.tr("Pause")
                                            color: Theme.textPrimary
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                        }
                                        MouseArea {
                                            id: pauseMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.runTorrentAction(["-t", String(torrentCard.torrentId), torrentCard.status === "stopped" ? "--start" : "--stop"])
                                        }
                                    }
                                    Rectangle {
                                        width: 54
                                        height: 22
                                        radius: 11
                                        color: deleteMouse.containsMouse ? Theme.danger : Theme.field
                                        Text {
                                            anchors.centerIn: parent
                                            text: I18n.tr("Delete")
                                            color: deleteMouse.containsMouse ? "#FFFFFF" : Theme.textPrimary
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                        }
                                        MouseArea {
                                            id: deleteMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.runTorrentAction(["-t", String(torrentCard.torrentId), "--remove-and-delete"])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
