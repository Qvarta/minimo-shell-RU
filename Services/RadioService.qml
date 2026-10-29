// SPDX-License-Identifier: MIT

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/minimo-os"
    readonly property string statePath: dir + "/radio.json"
    readonly property string defaultStationsPath: dir + "/radio-stations.json"
    readonly property string bundledStationsPath: Qt.resolvedUrl("../assets/radio-stations.json").toString().replace("file://", "")

    property bool loaded: false
    property var stations: []
    property string currentPlayingStation: ""
    property string currentPlayingProcessState: ""
    property string currentTrack: ""
    property string currentArtist: ""

    readonly property bool isPlaying: currentPlayingStation !== "" && currentPlayingProcessState === "start"

    property bool _switching: false

    signal stateChanged()

    Component.onCompleted: console.log("[Radio] The service is running")

    function stationAt(name) {
        if (!Array.isArray(stations)) return null
        return stations.find(s => s.name === name) ?? null
    }

    Process {
        id: catProc
        running: true
        command: ["sh", "-c", "cat '" + root.statePath + "' 2>/dev/null || true"]
        stdout: StdioCollector { onStreamFinished: root.applyState(text) }
        onExited: (code) => {
            if (!root.loaded) {
                root.loadDefaultsFromBundled(function() {
                    root.loaded = true
                    root.save()
                })
            }
        }
    }

    function loadDefaultsFromBundled(callback) {
        if (!loadDefaultsProc) { if (callback) callback(); return }
        loadDefaultsProc.callback = callback
        loadDefaultsProc.command = ["sh", "-c",
            "mkdir -p '" + root.dir + "' && " +
            "if [ ! -f '" + root.defaultStationsPath + "' ]; then " +
            "  cp '" + root.bundledStationsPath + "' '" + root.defaultStationsPath + "' 2>/dev/null || true; " +
            "fi && " +
            "cat '" + root.defaultStationsPath + "' 2>/dev/null || true"
        ]
        loadDefaultsProc.running = true
    }

    Process {
        id: loadDefaultsProc
        running: false
        property var callback: null
        stdout: StdioCollector {
            onStreamFinished: {
                var list = []
                try {
                    if (text && text.trim() !== "") {
                        var j = JSON.parse(text)
                        var arr = Array.isArray(j) ? j : (j && Array.isArray(j.stations) ? j.stations : [])
                        list = arr.map(s => ({ name: s.name || "", url: s.url || "" })).filter(s => s.name && s.url)
                    }
                } catch (e) {
                    console.warn("[Radio] loadDefaultsProc parse error:", e)
                }
                root.stations = list
            }
        }
        onExited: (code) => {
            if (callback) callback()
            callback = null
        }
    }

    function applyState(text) {
        var st = null
        if (text && text.trim() !== "") {
            try { st = JSON.parse(text) } catch (e) { console.warn("[Radio] radio.json inválido:", e) }
        }
        if (st && typeof st === "object") {
            root.currentPlayingStation = st.currentPlayingStation || ""
            root.currentPlayingProcessState = st.currentPlayingProcessState || ""
            root.currentTrack = st.currentTrack || ""
            root.currentArtist = st.currentArtist || ""
            if (Array.isArray(st.stations) && st.stations.length > 0)
                root.stations = st.stations.map(s => ({ name: s.name || "", url: s.url || "" })).filter(s => s.name && s.url)
            root.loaded = true
            root.save()
        }
        if (root.currentPlayingProcessState === "start")
            root.stop()
        root.stateChanged()
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
        if (!loaded) return
        if (!writeProc) return
        var body = serialize()
        var escaped = body.replace(/'/g, "'\\''")
        writeProc.command = ["sh", "-c",
            "mkdir -p '" + root.dir + "' && printf '%s' '" + escaped + "' > '" + root.statePath + "'"]
        writeProc.running = true
    }
    Process { id: writeProc; running: false }

    function playStation(name) {
        var st = stationAt(name)
        if (!st) return

        root._switching = true

        cvlcProcess.running = false
        killProc.command = ["sh", "-c", "kill -9 $(ps aux | grep -E '[c]vlc|[v]lc' | awk '{print $2}') 2>/dev/null || true"]
        killProc.running = true

        root.currentPlayingStation = name
        root.currentPlayingProcessState = "start"
        root.currentTrack = ""
        root.currentArtist = ""
        root.save()
        root.stateChanged()

        restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 150
        repeat: false
        onTriggered: {
            var st = root.stationAt(root.currentPlayingStation)
            if (!st) { root._switching = false; return }
            cvlcProcess.command = ["sh", "-c", "cvlc -vvv --intf dummy " + st.url.replace(/'/g, "'\"'\"'") + " 2>&1"]
            cvlcProcess.running = true
            root._switching = false
        }
    }

    function stop() {
        root._switching = true
        cvlcProcess.running = false
        killProc.command = ["sh", "-c", "kill -9 $(ps aux | grep -E '[c]vlc|[v]lc' | awk '{print $2}') 2>/dev/null || true"]
        killProc.running = true

        root.currentPlayingStation = ""
        root.currentPlayingProcessState = ""
        root.currentTrack = ""
        root.currentArtist = ""
        root.save()
        root.stateChanged()
        root._switching = false
        console.log("[Radio] The service is stopped")
    }
    Process { id: killProc; running: false }

    Process {
        id: cvlcProcess
        running: false
        command: []
        stdout: SplitParser { onRead: data => root.parseMetadata(data) }
        stderr: SplitParser { onRead: data => root.parseMetadata(data) }
        onStarted: { root.currentTrack = ""; root.currentArtist = ""; root.save(); root.stateChanged() }
        onExited: (code) => {
            if (root._switching) return
            if (root.currentPlayingStation !== "") root.stop()
        }
    }

    function toggle(name) {
        if (isPlaying && currentPlayingStation === name) stop()
        else if (isPlaying) { stop(); Qt.callLater(function() { playStation(name) }) }
        else playStation(name)
    }

    function toggleCurrent() {
        if (isPlaying) stop()
        else if (currentPlayingStation !== "") playStation(currentPlayingStation)
    }

    function currentIndex() {
        if (!Array.isArray(stations)) return -1
        for (var i = 0; i < stations.length; i++)
            if (stations[i].name === currentPlayingStation) return i
        return -1
    }

    function prev() {
        if (!Array.isArray(stations) || stations.length === 0) return
        var idx = currentIndex()
        if (idx < 0) { playStation(stations[0].name); return }
        playStation(stations[(idx - 1 + stations.length) % stations.length].name)
    }

    function next() {
        if (!Array.isArray(stations) || stations.length === 0) return
        var idx = currentIndex()
        if (idx < 0) { playStation(stations[0].name); return }
        playStation(stations[(idx + 1) % stations.length].name)
    }

    function parseMetadata(line) {
        var m = line.match(/New Icy-Title=(.+)$/i)
        if (m) parseArtistTitle(m[1].trim())
    }

    function parseArtistTitle(text) {
        text = text.trim()
        const separators = [" - ", " – ", " — ", ": ", " | ", " / ", " by "]
        for (var i = 0; i < separators.length; i++) {
            const sep = separators[i]
            const idx = text.indexOf(sep)
            if (idx > 0) {
                root.currentArtist = text.substring(0, idx).trim()
                root.currentTrack = text.substring(idx + sep.length).trim()
                root.save(); root.stateChanged()
                return
            }
        }
        root.currentArtist = ""
        root.currentTrack = text
        root.save(); root.stateChanged()
    }
}