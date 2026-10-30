// SPDX-License-Identifier: MIT
// System information for the Island status panel.
// Reads Linux procfs/sysfs directly and uses Quickshell's native services.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property int users: 0
    function acquire() {
        users++;
        if (users === 1) {
            refreshAll();
            resourceTimer.start();
            diskTimer.start();
            connectivityTimer.start();
        }
    }
    function release() {
        users = Math.max(0, users - 1);
        if (users === 0) {
            resourceTimer.stop();
            diskTimer.stop();
            connectivityTimer.stop();
        }
    }

    // Keep the data shape used by StatusPanel stable.
    property var res: ({
        cpu: 0, memUsed: 0, memTotal: 0,
        diskUsed: 0, diskTotal: 0, temp: null, battery: null
    })
    property var net: ({ type: "", name: "", device: "", signal: 0, connectivity: "unknown" })
    property var dev: ({ keyboards: [], mice: [], audio: "", bluetooth: [], usb: [] })
    property var gpu: null

    property string connectivity: "unknown"
    readonly property bool known: connectivity !== "unknown" && connectivity !== ""
    readonly property bool online: connectivity === "full"

    property var previousCpu: null

    function gib(bytes) {
        return (Math.max(0, Number(bytes) || 0) / 1073741824).toFixed(1).replace(".", ",");
    }

    function refreshAll() {
        cpuStat.reload();
        memInfo.reload();
        thermalType.reload();
        thermalTemp.reload();
        refreshDisk();
        refreshNetwork();
        refreshDevices();
        refreshBattery();
        refreshGpu();
        if (Networking.canCheckConnectivity)
            Networking.checkConnectivity();
    }

    function parseCpu() {
        const fields = cpuStat.text().trim().split(/\s+/);
        if (fields.length < 5 || fields[0] !== "cpu") return;
        const values = fields.slice(1).map(Number);
        const total = values.reduce((sum, value) => sum + value, 0);
        const idle = (values[3] || 0) + (values[4] || 0);
        if (previousCpu !== null) {
            const totalDelta = total - previousCpu.total;
            const idleDelta = idle - previousCpu.idle;
            if (totalDelta > 0) {
                const cpu = Math.max(0, Math.min(100, Math.round(100 * (totalDelta - idleDelta) / totalDelta)));
                res = Object.assign({}, res, { cpu: cpu });
            }
        }
        previousCpu = { total: total, idle: idle };
    }

    function parseMemory() {
        const values = {};
        const lines = memInfo.text().split("\n");
        for (const line of lines) {
            const match = line.match(/^([^:]+):\s+(\d+)/);
            if (match) values[match[1]] = Number(match[2]) * 1024;
        }
        const total = values.MemTotal || 0;
        const available = values.MemAvailable || values.MemFree || 0;
        if (total > 0)
            res = Object.assign({}, res, { memTotal: total, memUsed: Math.max(0, total - available) });
    }

    function parseTemperature() {
        const type = thermalType.text().trim().toLowerCase();
        const raw = Number(thermalTemp.text().trim());
        if (!Number.isFinite(raw) || raw <= 0) return;
        // thermal_zone0 is not guaranteed to be the CPU on every machine.
        if (type.includes("cpu") || type.includes("x86_pkg") || type.includes("pkg") || type.includes("soc"))
            res = Object.assign({}, res, { temp: Math.round(raw / 1000) });
    }

    function refreshDisk() {
        if (!diskProcess.running) diskProcess.running = true;
    }

    function parseDisk(output) {
        const lines = output.trim().split("\n");
        if (lines.length < 2) return;
        const fields = lines[1].trim().split(/\s+/).map(Number);
        if (fields.length < 2 || !Number.isFinite(fields[0]) || !Number.isFinite(fields[1])) return;
        res = Object.assign({}, res, { diskUsed: fields[0], diskTotal: fields[1] });
    }

    function refreshNetwork() {
        const raw = NetworkConnectivity.toString(Networking.connectivity).toLowerCase();
        let state = "unknown";
        if (raw.includes("full")) state = "full";
        else if (raw.includes("portal")) state = "portal";
        else if (raw.includes("partial") || raw.includes("limited")) state = "limited";
        else if (raw.includes("not connected") || raw === "none") state = "none";
        connectivity = state;

        const type = Network.wired ? "ethernet" : (Network.ssid ? "wifi" : "");
        net = {
            type: type,
            name: type === "wifi" ? Network.ssid : (type === "ethernet" ? "Ethernet" : ""),
            device: "",
            signal: type === "wifi" ? Network.signal : 0,
            connectivity: state
        };
    }

    function refreshDevices() {
        const sink = Pipewire.defaultAudioSink;
        const audio = sink ? (sink.description || sink.nickname || sink.name || "") : "";
        const bluetoothDevices = (Bluetooth.devices || [])
            .filter(device => device && device.connected)
            .map(device => device.name || device.address)
            .filter(name => !!name);

        // Quickshell has no compositor-independent public API for enumerating
        // physical keyboards, mice or USB block devices. Keep these arrays empty
        // rather than querying Hyprland or presenting guessed device information.
        dev = {
            keyboards: [],
            mice: [],
            audio: audio,
            bluetooth: bluetoothDevices,
            usb: []
        };
    }

    function batteryStatus(device) {
        const state = UPowerDeviceState.toString(device.state);
        if (state === "Charging" || state === "PendingCharge") return "Charging";
        if (state === "Discharging" || state === "PendingDischarge") return "Discharging";
        if (state === "FullyCharged") return "Full";
        if (state === "Empty") return "Discharging";
        return "Not charging";
    }

    function refreshBattery() {
        const devices = UPower.devices.values;
        let battery = null;
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];
            if (device && device.isLaptopBattery && device.isPresent !== false && device.ready) {
                battery = device;
                break;
            }
        }
        if (!battery && UPower.displayDevice && UPower.displayDevice.ready)
            battery = UPower.displayDevice;

        if (!battery) {
            res = Object.assign({}, res, { battery: null });
            return;
        }

        const status = batteryStatus(battery);
        const seconds = status === "Discharging" ? battery.timeToEmpty : battery.timeToFull;
        res = Object.assign({}, res, {
            battery: {
                pct: Math.round(battery.percentage),
                status: status,
                mins: seconds > 0 ? Math.round(seconds / 60) : null
            }
        });
    }

    function refreshGpu() {
        if (!gpuProcess.running) gpuProcess.running = true;
    }

    function parseGpu(output) {
        const fields = output.trim().split("\n")[0].split(",").map(value => value.trim());
        if (fields.length < 3 || !fields[0]) {
            gpu = null;
            return;
        }
        const util = Number(fields[1]);
        const temp = Number(fields[2]);
        gpu = {
            name: fields[0].replace("NVIDIA ", "").replace("GeForce ", ""),
            util: Number.isFinite(util) ? util : 0,
            temp: Number.isFinite(temp) ? temp : 0
        };
    }

    FileView {
        id: cpuStat
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.parseCpu()
    }
    FileView {
        id: memInfo
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.parseMemory()
    }
    FileView {
        id: thermalType
        path: "/sys/class/thermal/thermal_zone0/type"
        printErrors: false
    }
    FileView {
        id: thermalTemp
        path: "/sys/class/thermal/thermal_zone0/temp"
        printErrors: false
        onLoaded: root.parseTemperature()
    }

    Process {
        id: diskProcess
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDisk(text)
        }
    }
    Process {
        id: gpuProcess
        command: ["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: root.parseGpu(text)
        }
    }

    Timer {
        id: resourceTimer
        interval: 2000
        repeat: true
        onTriggered: {
            cpuStat.reload();
            memInfo.reload();
            thermalType.reload();
            thermalTemp.reload();
            root.refreshBattery();
            root.refreshDevices();
        }
    }
    Timer {
        id: diskTimer
        interval: 30000
        repeat: true
        onTriggered: root.refreshDisk()
    }
    Timer {
        id: connectivityTimer
        interval: 10000
        repeat: true
        onTriggered: {
            if (Networking.canCheckConnectivity)
                Networking.checkConnectivity();
            root.refreshNetwork();
        }
    }

    Connections {
        target: Networking
        function onConnectivityChanged() { root.refreshNetwork() }
    }
    Connections {
        target: Network
        function onWiredChanged() { root.refreshNetwork() }
        function onSsidChanged() { root.refreshNetwork() }
        function onSignalChanged() { root.refreshNetwork() }
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { root.refreshDevices() }
    }
    Connections {
        target: Bluetooth
        function onDevicesChanged() { root.refreshDevices() }
    }
    Connections {
        target: UPower
        function onDevicesChanged() { root.refreshBattery() }
        function onDisplayDeviceChanged() { root.refreshBattery() }
    }

    Component.onCompleted: {
        refreshNetwork();
        refreshDevices();
        refreshBattery();
        console.info("[SystemInfo] Quickshell system information service is running");
    }
}
