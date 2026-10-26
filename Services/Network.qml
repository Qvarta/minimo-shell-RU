// SPDX-License-Identifier: MIT

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    property int users: 0
    function acquire() {
        users++;
        if (users === 1) {
            enableScanners();
            refresh();
        }
    }
    function release() {
        users = Math.max(0, users - 1);
        if (users === 0) {
            disableScanners();
        }
    }

    readonly property bool hasNmcli: Networking !== undefined && Networking !== null


    property bool hasWifi: false          
    property bool wired: false            
    property bool wifiEnabled: false      
    property string ssid: ""              
    property int signal: 0               
    property var networks: []            
    property var known: []                
    readonly property bool showWifi: hasNmcli && hasWifi && !wired

    property bool scanning: false
    property string connecting: ""        
    property string error: ""             // последняя ошибка (краткий текст)

    // ------------------------------------------------------------------
    // Кэш известных сетей
    // ------------------------------------------------------------------
    readonly property string cacheDir: {
        const home = Quickshell.env("HOME") || "";
        return home ? home + "/.config/minimo-os/" : "";
    }

    property string cacheFile: cacheDir ? cacheDir + "network.json" : ""

    readonly property var cachedKnownNetworks: cacheAdapter.knownNetworks
    readonly property string cachedLastConnected: cacheAdapter.lastConnected

    FileView {
        id: cacheFileView
        path: root.cacheFile
        printErrors: false
        JsonAdapter {
            id: cacheAdapter
            property var knownNetworks: ({})
            property string lastConnected: ""
        }
        onLoadFailed: {
            cacheAdapter.knownNetworks = ({});
            cacheAdapter.lastConnected = "";
        }
    }

    Timer {
        id: saveDebounce
        interval: 1000
        onTriggered: {
            if (root.cacheFile)
                cacheFileView.writeAdapter();
        }
    }

    function saveCache() {
        if (root.cacheFile)
            saveDebounce.restart();
    }

    // ------------------------------------------------------------------
    // Вспомогательные функции 
    // ------------------------------------------------------------------
    function wifiDevices() {
        const out = [];
        if (!root.hasNmcli)
            return out;
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                out.push(devices[i]);
        }
        return out;
    }

    function findNetwork(ssid) {
        const devs = wifiDevices();
        for (let i = 0; i < devs.length; i++) {
            const nets = devs[i].networks.values;
            for (let j = 0; j < nets.length; j++) {
                if (nets[j].name === ssid)
                    return nets[j];
            }
        }
        return null;
    }

    function enableScanners() {
        const devs = wifiDevices();
        for (let i = 0; i < devs.length; i++) {
            if (!devs[i].scannerEnabled) {
                devs[i].scannerEnabled = true;
            }
        }
    }

    function disableScanners() {
        const devs = wifiDevices();
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].scannerEnabled) {
                devs[i].scannerEnabled = false;
            }
        }
    }

    function securityString(securityType) {
        switch (securityType) {
        case WifiSecurityType.WpaPsk:
            return "WPA1";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.WpaEap:
            return "WPA-EAP";
        case WifiSecurityType.Wpa2Eap:
            return "WPA2-EAP";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3-Enterprise";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Owe:
            return "OWE";
        case WifiSecurityType.Leap:
            return "LEAP";
        case WifiSecurityType.Open:
        case WifiSecurityType.Unknown:
        default:
            return "--";
        }
    }

    function mapConnectionFailReason(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
        case ConnectionFailReason.InvalidPassword:
            return I18n.tr("Password incorrect");
        case ConnectionFailReason.Timeout:
            return I18n.tr("Connection timed out");
        case ConnectionFailReason.NotFound:
            return I18n.tr("Network not found");
        default:
            return I18n.tr("Couldn't connect");
        }
    }

    // ------------------------------------------------------------------
    // Периодическое обновление
    // ------------------------------------------------------------------
    function refresh() {
        readDeviceState();
    }

    function scan() {
        if (!root.hasNmcli)
            return;
        if (root.scanning)
            return;
        root.scanning = true;
        enableScanners();
        scanWaitTimer.restart();
    }

    Timer {
        id: scanWaitTimer
        interval: 3000
        repeat: false
        onTriggered: {
            readWifiNetworks(true);
            root.scanning = false;
        }
    }

    Timer {
        running: root.users > 0
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: readDeviceState()
    }

    function readDeviceState() {
        if (!root.hasNmcli)
            return;

        let wifi = false;
        let wired = false;

        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];
            if (device.type === DeviceType.Wifi) {
                wifi = true;
            } else if (device.type === DeviceType.Wired && device.connected) {
                wired = true;
            }
        }
        root.hasWifi = wifi;
        root.wired = wired;

        // Сохранённые Wi-Fi-подключения (известные профили).
        const knownList = [];
        const devs = wifiDevices();
        for (let i = 0; i < devs.length; i++) {
            const nets = devs[i].networks.values;
            for (let j = 0; j < nets.length; j++) {
                if (nets[j].known && knownList.indexOf(nets[j].name) < 0) {
                    knownList.push(nets[j].name);
                }
            }
        }
        root.known = knownList;

        readWifiNetworks(true);

        if (root.users > 0 && root.wifiEnabled && !root.scanning) {
            scan();
        }
    }

    // ------------------------------------------------------------------
    // Чтение списка сетей 
    // ------------------------------------------------------------------
    function readWifiNetworks(updateCurrent) {
        if (!root.hasNmcli)
            return;

        const best = {};
        let cur = "";
        let sig = 0;

        const knownNames = (cacheAdapter.knownNetworks && typeof cacheAdapter.knownNetworks === "object") ? Object.keys(cacheAdapter.knownNetworks) : [];

        const devs = wifiDevices();
        for (let i = 0; i < devs.length; i++) {
            const nets = devs[i].networks.values;
            for (let j = 0; j < nets.length; j++) {
                const net = nets[j];
                const name = net.name;
                if (!name)
                    continue;

                const isKnown = net.known || knownNames.indexOf(name) >= 0;
                const n = {
                    ssid: name,
                    signal: Math.round(net.signalStrength * 100),
                    secure: root.securityString(net.security) !== "--",
                    active: net.connected,
                    known: isKnown
                };

                if (n.active) {
                    cur = name;
                    sig = n.signal;
                }

                if (!best[name] || best[name].signal < n.signal || n.active) {
                    best[name] = n;
                }
            }
        }

        if (updateCurrent !== false) {
            root.ssid = cur;
            root.signal = sig;

            if (cur) {
                if (cacheAdapter.lastConnected !== cur) {
                    cacheAdapter.lastConnected = cur;
                    saveCache();
                }
            }
        }

        root.networks = Object.values(best).sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
    }

    function setEnabled(on) {
        root.wifiEnabled = on;

        // Синхронизируем с настройками, если они доступны.
        if (typeof Settings !== "undefined" && Settings.data && Settings.data.network) {
            Settings.data.network.wifiEnabled = on;
        }

        if (on) {
            enableScanners();
            scanWaitTimer.restart();
        } else {
            disableScanners();
            root.networks = [];
            root.ssid = "";
            root.signal = 0;
        }

        later.restart();
    }

    Timer {
        id: later
        interval: 1500
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        console.info("[Network] The service is running");
        if (!root.hasNmcli)
            return;
        if (typeof Settings !== "undefined" && Settings.data && Settings.data.network) {
            root.wifiEnabled = !!Settings.data.network.wifiEnabled;
        } else {
            root.wifiEnabled = true;
        }
        refresh();
    }

    Connections {
        target: (typeof Settings !== "undefined" && Settings.data) ? Settings.data.network : null
        function onWifiEnabledChanged() {
            if (root.wifiEnabled !== Settings.data.network.wifiEnabled) {
                root.wifiEnabled = Settings.data.network.wifiEnabled;
            }
            if (root.wifiEnabled) {
                if (root.users > 0) {
                    enableScanners();
                    scanWaitTimer.restart();
                }
            } else {
                disableScanners();
                root.networks = [];
                root.ssid = "";
                root.signal = 0;
            }
        }
    }

    // ------------------------------------------------------------------
    // Подключение / отключение / забыть
    // ------------------------------------------------------------------
    function connect(ssid, password) {
        if (connecting)
            return;
        error = "";

        const network = findNetwork(ssid);
        if (!network) {
            error = I18n.tr("Network not found");
            return;
        }
        connecting = ssid;

        var failHandler = null;
        var successHandler = null;

        successHandler = function () {
            if (network.connected) {
                try {
                    network.connectedChanged.disconnect(successHandler);
                } catch (e) {
                    void 0;
                }
                try {
                    network.connectionFailed.disconnect(failHandler);
                } catch (e) {
                    void 0;
                }
                handleConnectionSuccess(ssid);
            }
        };

        failHandler = function (reason) {
            try {
                network.connectionFailed.disconnect(failHandler);
            } catch (e) {
                void 0;
            }
            try {
                network.connectedChanged.disconnect(successHandler);
            } catch (e) {
                void 0;
            }
            connectionTimeoutTimer.stop();
            root.connecting = "";
            root.error = mapConnectionFailReason(reason);
            if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.InvalidPassword) {
                forget(ssid);
            }
            root.refresh();
        };

        network.connectionFailed.connect(failHandler);
        network.connectedChanged.connect(successHandler);

        connectionTimeoutTimer.ssid = ssid;
        connectionTimeoutTimer.failHandler = failHandler;
        connectionTimeoutTimer.successHandler = successHandler;
        connectionTimeoutTimer.network = network;
        connectionTimeoutTimer.restart();

        const needsPassword = password !== "" && !network.known;
        if (needsPassword)
            network.connectWithPsk(password);
        else
            network.connect();
    }

    function handleConnectionSuccess(ssid) {
        connectionTimeoutTimer.stop();
        connecting = "";

        const knownMap = cacheAdapter.knownNetworks || {};
        knownMap[ssid] = {
            "profileName": ssid,
            "lastConnected": Date.now()
        };
        cacheAdapter.knownNetworks = knownMap;
        cacheAdapter.lastConnected = ssid;
        saveCache();

        readWifiNetworks(true);
        refresh();
    }

    Timer {
        id: connectionTimeoutTimer
        interval: 30000
        property string ssid: ""
        property var failHandler: null
        property var successHandler: null
        property var network: null
        onTriggered: {
            if (network && failHandler) {
                try {
                    network.connectionFailed.disconnect(failHandler);
                } catch (e) {
                    void 0;
                }
            }
            if (network && successHandler) {
                try {
                    network.connectedChanged.disconnect(successHandler);
                } catch (e) {
                    void 0;
                }
            }
            root.connecting = "";
            root.error = I18n.tr("Connection timed out");
        }
    }

    function disconnect() {
        error = "";
        const devs = wifiDevices();
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) {
                devs[i].disconnect();
            }
        }
        later.restart();
    }

    function forget(ssid) {
        const network = findNetwork(ssid);
        if (network) {
            network.forget();
        }

        const knownMap = cacheAdapter.knownNetworks || {};
        if (knownMap[ssid] !== undefined) {
            delete knownMap[ssid];
            cacheAdapter.knownNetworks = knownMap;
        }
        if (cacheAdapter.lastConnected === ssid) {
            cacheAdapter.lastConnected = "";
        }
        saveCache();

        const k = known.slice();
        const idx = k.indexOf(ssid);
        if (idx >= 0) {
            k.splice(idx, 1);
            known = k;
        }
        readWifiNetworks(true);
    }
}
