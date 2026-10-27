import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root
    property var pluginApi: null
    property string currentPlayingStation: ""
    property string currentPlayingProcessState: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property var currentProcess: null

    Component.onCompleted: {
        if (pluginApi && pluginApi.pluginSettings) {
            currentPlayingStation = pluginApi.pluginSettings.currentPlayingStation || "";
            currentPlayingProcessState = pluginApi.pluginSettings.currentPlayingProcessState || "";
            currentTrack = pluginApi.pluginSettings.currentTrack || "";
            currentArtist = pluginApi.pluginSettings.currentArtist || "";
            root.stopPlayback();
        }
    }

    function loadStationsFromJson(filePath) {
        if (!pluginApi) {
            return;
        }

        if (!filePath || filePath === "") {
            return;
        }

        var file = Qt.createQmlObject('import QtQuick; import Quickshell.Io; FileView { path: ""; blockLoading: false }', root);
        file.path = filePath;

        file.textChanged.connect(function () {
            if (file.text()) {
                try {
                    var jsonData = JSON.parse(file.text());
                    var savedStation = currentPlayingStation || "";
                    var savedState = currentPlayingProcessState || "";

                    var deletedCount = 0;
                    for (var key in pluginApi.pluginSettings) {
                        if (key.startsWith("station_")) {
                            delete pluginApi.pluginSettings[key];
                            deletedCount++;
                        }
                    }

                    if (Array.isArray(jsonData)) {
                        for (var i = 0; i < jsonData.length; i++) {
                            var station = jsonData[i];
                            pluginApi.pluginSettings["station_" + i + "_name"] = station.name || "";
                            pluginApi.pluginSettings["station_" + i + "_url"] = station.url || "";
                        }
                        pluginApi.pluginSettings.station_count = jsonData.length;
                    } else {
                        Logger.e("Online_radio", "JSON data is not an array");
                    }

                    var stationStillExists = false;
                    if (savedStation && Array.isArray(jsonData)) {
                        for (var j = 0; j < jsonData.length; j++) {
                            if (jsonData[j].name === savedStation) {
                                stationStillExists = true;
                                break;
                            }
                        }
                    }

                    if (!stationStillExists && savedStation) {
                        currentPlayingStation = "";
                        currentPlayingProcessState = "";
                        currentTrack = "";
                        currentArtist = "";
                        pluginApi.pluginSettings.currentPlayingStation = "";
                        pluginApi.pluginSettings.currentPlayingProcessState = "";
                        pluginApi.pluginSettings.currentTrack = "";
                        pluginApi.pluginSettings.currentArtist = "";
                    }

                    pluginApi.saveSettings();
                } catch (error) {
                    Logger.e("Online_radio", "Error parsing JSON: " + error);
                }
            } else {
                Logger.e("Online_radio", "FileView text is empty");
            }
            file.destroy();
        });

        if (file.text()) {
            file.textChanged();
        } else {
            file.reload();
        }
    }

    function parseMetadata(line) {
        var icyTitleMatch = line.match(/New Icy-Title=(.+)$/i);

        if (icyTitleMatch) {
            var streamTitle = icyTitleMatch[1].trim();
            parseArtistTitle(streamTitle);
            return;
        }

        var icyNameMatch = line.match(/Icy-Name:\s*(.+)/i);
        if (icyNameMatch) {
            return;
        }
    }

    function parseArtistTitle(text) {
        text = text.trim();

        var separators = [" - ", " – ", " — ", ": ", " | ", " / ", " by "];

        for (var i = 0; i < separators.length; i++) {
            var sep = separators[i];
            var index = text.indexOf(sep);
            if (index > 0) {
                currentArtist = text.substring(0, index).trim();
                currentTrack = text.substring(index + sep.length).trim();

                if (pluginApi) {
                    pluginApi.pluginSettings.currentArtist = currentArtist;
                    pluginApi.pluginSettings.currentTrack = currentTrack;
                    pluginApi.saveSettings();
                }
                return;
            }
        }

        currentArtist = "";
        currentTrack = text;

        if (pluginApi) {
            pluginApi.pluginSettings.currentArtist = currentArtist;
            pluginApi.pluginSettings.currentTrack = currentTrack;
            pluginApi.saveSettings();
        }
    }

    Process {
        id: cvlcProcess

        command: {
            if (root.currentPlayingStation && root.currentPlayingProcessState === "start") {
                var stations = root.getStations();
                var station = stations.find(s => s.name === root.currentPlayingStation);
                if (station) {
                    var cmd = "cvlc -vvv --intf dummy " + station.url.replace(/'/g, "'\"'\"'") + " 2>&1";
                    return ["sh", "-c", cmd];
                }
            }
            return ["true"];
        }

        running: {
            var shouldRun = root.currentPlayingStation !== "" && root.currentPlayingProcessState === "start";
            return shouldRun;
        }

        stdout: SplitParser {
            onRead: data => {
                root.parseMetadata(data);
            }
        }

        stderr: SplitParser {
            onRead: data => {
                root.parseMetadata(data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.currentPlayingStation !== "") {
                root.stopPlayback();
            }
        }

        onStarted: {
            currentTrack = "";
            currentArtist = "";
            if (pluginApi) {
                pluginApi.pluginSettings.currentTrack = "";
                pluginApi.pluginSettings.currentArtist = "";
                pluginApi.saveSettings();
            }
        }
    }

    function playStation(stationName, stationUrl) {
        stopPlayback();

        currentPlayingStation = stationName;
        currentPlayingProcessState = "start";
        currentTrack = "";
        currentArtist = "";

        if (pluginApi) {
            pluginApi.pluginSettings.currentPlayingStation = stationName;
            pluginApi.pluginSettings.currentPlayingProcessState = "start";
            pluginApi.pluginSettings.currentTrack = "";
            pluginApi.pluginSettings.currentArtist = "";
            pluginApi.saveSettings();
        }

        cvlcProcess.running = true;
    }

    function stopPlayback() {
        var killProcess = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root);
        killProcess.command = ["sh", "-c", "kill -9 $(ps aux | grep -E '[c]vlc|[v]lc' | awk '{print $2}') 2>/dev/null || true"];

        killProcess.exited.connect(function () {
            killProcess.destroy();
        });

        killProcess.startDetached();

        currentPlayingStation = "";
        currentPlayingProcessState = "";

        if (pluginApi) {
            pluginApi.pluginSettings.currentPlayingStation = "";
            pluginApi.pluginSettings.currentPlayingProcessState = "";
            pluginApi.saveSettings();
        }
    }

    function getStations() {
        var stations = [];

        if (pluginApi && pluginApi.pluginSettings) {
            var settings = pluginApi.pluginSettings;

            var i = 0;
            while (true) {
                var nameKey = "station_" + i + "_name";
                var urlKey = "station_" + i + "_url";

                if (settings.hasOwnProperty(nameKey) && settings.hasOwnProperty(urlKey)) {
                    var name = settings[nameKey];
                    var url = settings[urlKey];

                    if (name && url) {
                        stations.push({
                            index: i,
                            name: name,
                            url: url
                        });
                    }
                    i++;
                } else {
                    break;
                }
            }
        }

        return stations;
    }

    IpcHandler {
        target: "plugin:online-radio"

        function toggle() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => {
                    pluginApi.openPanel(screen, this);
                });
            }
        }
    }
}
