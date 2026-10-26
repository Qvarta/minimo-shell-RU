// SPDX-License-Identifier: MIT

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    property bool enabled: false           
    property bool discovering: false       
    property string state: ""              
    property string error: ""              
    property string connectingPath: ""     
    property var devices: []               
    property bool watch: false             

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    readonly property bool available: adapter !== null
    readonly property int connectedCount: devices.filter(d => d.connected).length
    readonly property string connectedName: {
        const c = devices.find(d => d.connected);
        return c ? (c.name || c.address) : "";
    }

    function _deviceArray() {
        if (!adapter || !adapter.devices) return [];
        try {
            if (adapter.devices.values !== undefined && adapter.devices.values !== null)
                return adapter.devices.values;
        } catch (e) {}
        try {
            const m = adapter.devices;
            const out = [];
            for (let i = 0; i < m.length; i++) out.push(m.at(i));
            return out;
        } catch (e) { return []; }
    }

    // ------------------------------------------------------------------
    // Подключение/отключение сигналов адаптера
    // ------------------------------------------------------------------
    property var _adapterConns: []

    function _disconnectAdapter() {
        for (let i = 0; i < _adapterConns.length; i++) {
            try { _adapterConns[i]() } catch (e) {}
        }
        _adapterConns = [];
    }

    function _connectAdapter(a) {
        _disconnectAdapter();
        if (!a) return;
        try { a.enabledChanged.connect(refresh) } catch (e) {}
        try { a.discoveringChanged.connect(refresh) } catch (e) {}
        try { a.stateChanged.connect(refresh) } catch (e) {}
        try { a.addressChanged.connect(refresh) } catch (e) {}   // на случай поздней инициализации
        try { a.pathChanged.connect(refresh) } catch (e) {}
        _adapterConns = [
            () => { try { a.enabledChanged.disconnect(refresh) } catch (e) {} },
            () => { try { a.discoveringChanged.disconnect(refresh) } catch (e) {} },
            () => { try { a.stateChanged.disconnect(refresh) } catch (e) {} },
            () => { try { a.addressChanged.disconnect(refresh) } catch (e) {} },
            () => { try { a.pathChanged.disconnect(refresh) } catch (e) {} }
        ];
        const m = a.devices;
        if (m) {
            try { m.modelUpdated.connect(rebuild) } catch (e) {}
            try { m.rowsInserted.connect(rebuild) } catch (e) {}
            try { m.rowsRemoved.connect(rebuild) } catch (e) {}
            _adapterConns.push(() => { try { m.modelUpdated.disconnect(rebuild) } catch (e) {} });
            _adapterConns.push(() => { try { m.rowsInserted.disconnect(rebuild) } catch (e) {} });
            _adapterConns.push(() => { try { m.rowsRemoved.disconnect(rebuild) } catch (e) {} });
            hookDevices(m);
        }
    }

    onAdapterChanged: {
        if (adapter) {
            _connectAdapter(adapter);
            refresh();
            // Даём BlueZ/Quickshell время заполнить свойства адаптера.
            Qt.callLater(rebuild);
            _initialDelay.start();
        } else {
            _disconnectAdapter();
            refresh();
        }
    }

    property Timer _initialDelay: Timer {
        interval: 1000
        repeat: false
        onTriggered: refresh()
    }

    // ------------------------------------------------------------------
    // Подключение сигналов по устройствам 
    // ------------------------------------------------------------------
    property var hookedPaths: []
    function hookDevices(m) {
        const src = _deviceArray();
        for (let i = 0; i < src.length; i++) {
            const d = src[i];
            if (!d || !d.path || hookedPaths.indexOf(d.path) >= 0) continue;
            hookedPaths.push(d.path);
            try { d.pairedChanged.connect(rebuild) } catch (e) {}
            try { d.trustedChanged.connect(rebuild) } catch (e) {}
            try { d.connectingChanged.connect(rebuild) } catch (e) {}
            try { d.connectedChanged.connect(rebuild) } catch (e) {}
            try { d.nameChanged.connect(rebuild) } catch (e) {}
            try { d.batteryChanged.connect(rebuild) } catch (e) {}
        }
    }

    // ------------------------------------------------------------------
    // Обновление / перестройка
    // ------------------------------------------------------------------
    function refresh() {
        if (!adapter) {
            enabled = false;
            discovering = false;
            state = "";
            devices = [];
            connectingPath = "";
            return;
        }
        try {
            const e = adapter.enabled;
            enabled = (e === true) || (typeof e === "number" && e > 0) ||
                      String(e).toLowerCase().indexOf("on") >= 0;
            discovering = !!adapter.discovering;
            state = String(adapter.state);
        } catch (err) {}
        rebuild();
    }

    function rebuild() {
        if (!adapter) { devices = []; connectingPath = ""; return }
        const src = _deviceArray();
        const out = [];
        for (let i = 0; i < src.length; i++) {
            const d = src[i];
            if (!d) continue;
            try {
                out.push({
                    id: d.address || String(i),
                    path: d.path,
                    name: d.name || "",
                    address: d.address || "",
                    alias: d.alias || "",
                    icon: d.icon || "",
                    battery: typeof d.battery === "number" ? d.battery : -1,
                    trusted: !!d.trusted,
                    paired: !!d.paired,
                    connected: !!d.connected,
                    connecting: !!d.connecting,
                    rssi: typeof d.rssi === "number" ? d.rssi : 0,
                });
            } catch (e) { /* транзитное устройство без данных: игнорируем */ }
        }
        out.sort((a, b) => {
            const rank = x => x.connected ? 0 : (x.paired ? 1 : 2);
            const ra = rank(a), rb = rank(b);
            if (ra !== rb) return ra - rb;
            return (a.name || a.address).localeCompare(b.name || b.address);
        });
        const key = arr => arr.map(d => [d.path, d.name, d.alias, d.battery,
            d.trusted ? 1 : 0, d.paired ? 1 : 0, d.connected ? 1 : 0,
            d.connecting ? 1 : 0].join("|")).join(",");
        if (key(out) !== key(devices)) devices = out;
        const c = out.find(x => x.connecting);
        connectingPath = c ? c.path : "";
    }

    Connections {
        target: root.watch && root.adapter ? root.adapter.devices : null
        ignoreUnknownSignals: true
        function onModelUpdated() { root.rebuild() }
        function onRowsInserted() { root.rebuild() }
        function onRowsRemoved() { root.rebuild() }
    }

    Component.onCompleted: {
        console.info("[Bluetooth] The service is running");
        _connectAdapter(adapter);
        refresh();
    }

    function setWatch(on) { watch = on; if (on) refresh() }

    // ------------------------------------------------------------------
    // Действия
    // ------------------------------------------------------------------
    function findDevice(path) {
        const src = _deviceArray();
        for (let i = 0; i < src.length; i++) {
            const d = src[i];
            if (d && d.path === path) return d;
        }
        return null;
    }

    function setEnabled(on) {
        if (!adapter) return;
        error = "";
        try {
            adapter.enabled = on;
        } catch (e) { error = String(e) }
        refresh();
    }

    function scan() {
        if (!adapter) return;
        error = "";
        try {
            if (!enabled) adapter.enabled = true;
            // В Quickshell discovering — это записываемое свойство, а не метод.
            adapter.discovering = true;
            discovering = true;
        } catch (e) { error = String(e) }
    }

    function stopScan() {
        if (!adapter) return;
        try {
            adapter.discovering = false;
        } catch (e) {}
        discovering = false;
    }

    function connect(path) {
        const d = findDevice(path);
        if (!d) return;
        error = "";
        connectingPath = path;
        try { d.requestConnect() } catch (e) { error = String(e) }
        rebuild();
    }

    function disconnect(path) {
        const d = findDevice(path);
        if (!d) return;
        error = "";
        try { d.requestDisconnect() } catch (e) { error = String(e) }
        rebuild();
    }

    function toggle(path) {
        const d = findDevice(path);
        if (!d) return;
        if (d.connected) disconnect(path);
        else if (d.paired) connect(path);
        else pair(path);
    }

    function pair(path) {
        const d = findDevice(path);
        if (!d) return;
        error = "";
        try { d.pair() } catch (e) { error = String(e) }
        rebuild();
    }

    function forget(path) {
        const d = findDevice(path);
        if (!d) return;
        error = "";
        try { d.unpair() } catch (e) { error = String(e) }
        rebuild();
    }
}
