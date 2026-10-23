// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Qvatra — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Управление яркостью по оборудованию (внутренний backlight, внешний DDC/CI и Apple).
// Синглтон запускается вместе с оболочкой: обнаруживает мониторы при завершении и
// предоставляет Brightness.brightness (0..1) для синхронизации ползунков.
Singleton {
    id: root

    property list<var> ddcMonitors: []
    readonly property list<Monitor> monitors: variants.instances
    property bool appleDisplayPresent: false

    // Текущая глобальная яркость (среднее по мониторам) в диапазоне ползунка.
    // Искусственный нижний предел убран: значение должно совпадать с тем, что
    // реально записывается в монитор (enforceMinBrightness), иначе ползунок
    // «залипает» и дёргается.
    readonly property real minBrightnessValue: 0.01
    readonly property real brightness: monitors.length > 0
                                       ? monitors.reduce((a, m) => a + m.brightness, 0) / monitors.length
                                       : 1.0

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.modelData === screen);
    }

    // Сигнал, испускаемый при изменении яркости конкретного монитора,
    // с контекстом монитора
    signal monitorBrightnessChanged(var monitor, real newBrightness)

    // Глобальные помощники для IPC и горячих клавиш
    function increaseBrightness(): void {
        monitors.forEach(m => m.increaseBrightness());
    }

    function decreaseBrightness(): void {
        monitors.forEach(m => m.decreaseBrightness());
    }

    // Немедленно обновляем внутреннее состояние монитора (чтобы ползунок шёл
    // плавно), а запись в железо оставляем с debounce, чтобы не спамить
    // ddcutil/brightnessctl.
    function setBrightness(value: real): void {
        monitors.forEach(m => {
            m.brightness = Math.max(m.enforceMinBrightness, Math.min(1, value));
            m.brightnessUpdated(m.brightness);
            m.setBrightnessDebounced(value);
        });
    }

    reloadableId: "brightness"

    // Проверка установлен ли ddcutil (через which). Пока результат неизвестен
    // или утилита отсутствует — никакие команды ddcutil не запускаются.
    readonly property bool ddcutilInstalled: ddcCheckProc.found

    Process {
        id: ddcCheckProc
        property bool found: false
        running: true
        command: ["sh", "-c", "which ddcutil >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: ddcCheckProc.found = text.trim() === "yes"
        }
    }

    Component.onCompleted: {
        if (ddcEnabled) {
            ddcProc.running = true;
        }
    }

    onDdcutilInstalledChanged: {
        if (ddcEnabled && ddcutilInstalled) {
            ddcProc.running = true;
        }
    }

    onMonitorsChanged: {
        ddcMonitors = [];
        if (ddcEnabled && ddcutilInstalled) {
            ddcProc.running = true;
        }
    }

    // DDC включён, если есть поддержка чтения/записи яркости внешних мониторов
    // и установлен бинарник ddcutil.
    readonly property bool ddcEnabled: {
        const p = Quickshell.env("MINIMO_ENABLE_DDC");
        return p !== "0" && root.ddcutilInstalled;
    }

    Variants {
        id: variants
        model: Quickshell.screens
        Monitor {}
    }

    // Проверка поддержки Apple Display
    Process {
        running: true
        command: ["sh", "-c", "which asdbctl >/dev/null 2>&1 && asdbctl get || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: root.appleDisplayPresent = text.trim().length > 0
        }
    }

    // Обнаружение DDC-мониторов
    Process {
        id: ddcProc
        property list<var> ddcMonitors: []
        command: ["ddcutil", "detect", "--sleep-multiplier=0.5"]
        stdout: StdioCollector {
            onStreamFinished: {
                var displays = text.trim().split("\n\n");
                ddcProc.ddcMonitors = displays.map(d => {
                    var ddcModelMatch = d.match(/(This monitor does not support DDC\/CI|Invalid display)/);
                    var modelMatch = d.match(/Model:\s*(.*)/);
                    var busMatch = d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/);
                    var connectorMatch = d.match(/DRM[_ ]connector:\s*card\d+-(.+)/);
                    var ddcModel = ddcModelMatch ? ddcModelMatch.length > 0 : false;
                    var model = modelMatch ? modelMatch[1] : "Unknown";
                    var bus = busMatch ? busMatch[1] : "Unknown";
                    var connector = connectorMatch ? connectorMatch[1].trim() : "";
                    return {
                        "model": model,
                        "busNum": bus,
                        "connector": connector,
                        "isDdc": !ddcModel
                    };
                });
                root.ddcMonitors = ddcProc.ddcMonitors.filter(m => m.isDdc);
            }
        }
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property bool isDdc: root.ddcEnabled && root.ddcMonitors.some(m => m.connector === modelData.name)
        readonly property string busNum: root.ddcMonitors.find(m => m.connector === modelData.name)?.busNum ?? ""
        readonly property bool isAppleDisplay: root.appleDisplayPresent && modelData.model.startsWith("StudioDisplay")
        readonly property string method: isAppleDisplay ? "apple" : (isDdc ? "ddcutil" : "internal")

        // Проверяем, доступно ли управление яркостью для этого монитора
        readonly property bool brightnessControlAvailable: {
            if (isAppleDisplay)
                return true;
            if (isDdc)
                return true;
            // Для внутренних дисплеев проверяем наличие пути к яркости
            return brightnessPath !== "";
        }

        property real brightness
        property real lastBrightness: 0
        property real queuedBrightness: NaN
        property bool commandRunning: false

        // Для внутренних дисплеев — храним путь к устройству подсветки
        property string backlightDevice: ""
        property string brightnessPath: ""
        property string maxBrightnessPath: ""
        property int maxBrightness: 100
        property bool ignoreNextChange: false

        // Сигнал об изменении яркости
        signal brightnessUpdated(real newBrightness)

        // Выполняет системную команду для прямого получения текущего значения яркости
        readonly property Process refreshProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    var dataText = text.trim();
                    if (dataText === "") {
                        return;
                    }

                    var newBrightness = NaN;

                    if (monitor.isAppleDisplay) {
                        // Формат Apple display: одно целое число (0–101)
                        var val = parseInt(dataText);
                        if (!isNaN(val)) {
                            newBrightness = val / 101;
                        }
                    } else if (monitor.isDdc) {
                        // Формат DDC: "VCP 10 C 100 100" (через пробел)
                        var parts = dataText.split(" ");
                        if (parts.length >= 4) {
                            var current = parseInt(parts[3]);
                            var max = parseInt(parts[4]);
                            if (!isNaN(current) && !isNaN(max) && max > 0) {
                                monitor.maxBrightness = max;
                                newBrightness = current / max;
                            }
                        }
                    } else {
                        // Формат внутреннего дисплея: две строки (current\nmax)
                        var lines = dataText.split("\n");
                        if (lines.length >= 2) {
                            var current = parseInt(lines[0].trim());
                            var max = parseInt(lines[1].trim());
                            if (!isNaN(current) && !isNaN(max) && max > 0) {
                                newBrightness = current / max;
                            }
                        }
                    }

                    // Обновляем, если получили корректное значение яркости
                    if (!isNaN(newBrightness) && (Math.abs(newBrightness - monitor.brightness) > 0.001 || monitor.brightness === 0)) {
                        monitor.brightness = newBrightness;
                        monitor.brightnessUpdated(monitor.brightness);
                        root.monitorBrightnessChanged(monitor, monitor.brightness);
                    }
                }
            }
        }

        readonly property Process setBrightnessProc: Process {
            stdout: StdioCollector {}
            onExited: (exitCode, exitStatus) => {
                monitor.commandRunning = false;
                // Если есть отложенное изменение яркости — обрабатываем его сейчас
                if (!isNaN(monitor.queuedBrightness)) {
                    Qt.callLater(() => {
                        monitor.setBrightness(monitor.queuedBrightness);
                        monitor.queuedBrightness = NaN;
                    });
                }
            }
        }

        // Функция для активного обновления яркости из системы
        function refreshBrightnessFromSystem() {
            if (!monitor.isDdc && !monitor.isAppleDisplay) {
                // Для внутренних дисплеев запрашиваем систему напрямую
                refreshProc.command = ["sh", "-c", "cat " + monitor.brightnessPath + " && " + "cat " + monitor.maxBrightnessPath];
                refreshProc.running = true;
            } else if (monitor.isDdc && monitor.busNum !== "") {
                // Для DDC-дисплеев получаем текущее значение
                refreshProc.command = ["ddcutil", "-b", monitor.busNum, "--sleep-multiplier=0.05", "getvcp", "10", "--brief"];
                refreshProc.running = true;
            } else if (monitor.isAppleDisplay) {
                // Для Apple-дисплеев получаем текущее значение
                refreshProc.command = ["asdbctl", "get"];
                refreshProc.running = true;
            }
        }

        // FileView для отслеживания внешних изменений яркости (только внутренние дисплеи)
        readonly property FileView brightnessWatcher: FileView {
            id: brightnessWatcher
            // Путь задаём только для внутренних дисплеев с корректным путём яркости
            path: (!monitor.isDdc && !monitor.isAppleDisplay && monitor.brightnessPath !== "") ? monitor.brightnessPath : ""
            watchChanges: path !== ""
            onFileChanged: {
                // При обнаружении изменения файла активно обновляем значение из системы,
                // чтобы гарантированно получить самое актуальное значение
                Qt.callLater(() => {
                    monitor.refreshBrightnessFromSystem();
                });
            }
        }

        // Инициализация яркости
        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    var dataText = text.trim();
                    if (dataText === "") {
                        return;
                    }

                    if (monitor.isAppleDisplay) {
                        var val = parseInt(dataText);
                        if (!isNaN(val)) {
                            monitor.brightness = val / 101;
                        }
                    } else if (monitor.isDdc) {
                        var parts = dataText.split(" ");
                        if (parts.length >= 4) {
                            var current = parseInt(parts[3]);
                            var max = parseInt(parts[4]);
                            if (!isNaN(current) && !isNaN(max) && max > 0) {
                                monitor.maxBrightness = max;
                                monitor.brightness = current / max;
                            }
                        }
                    } else {
                        // Внутренняя подсветка — разбираем ответ, включающий путь к устройству
                        var lines = dataText.split("\n");
                        if (lines.length >= 3) {
                            monitor.backlightDevice = lines[0];
                            monitor.brightnessPath = monitor.backlightDevice + "/brightness";
                            monitor.maxBrightnessPath = monitor.backlightDevice + "/max_brightness";

                            var current = parseInt(lines[1]);
                            var max = parseInt(lines[2]);
                            if (!isNaN(current) && !isNaN(max) && max > 0) {
                                monitor.maxBrightness = max;
                                monitor.brightness = current / max;
                            }
                        }
                    }

                    // Обновляем всегда
                    monitor.brightnessUpdated(monitor.brightness);
                    root.monitorBrightnessChanged(monitor, monitor.brightness);
                }
            }
        }

        readonly property real stepSize: 0.05
        readonly property real enforceMinBrightness: 0.01

        // Таймер для подавления дребезга при быстрых изменениях
        readonly property Timer timer: Timer {
            interval: 250
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    monitor.setBrightness(monitor.queuedBrightness);
                    monitor.queuedBrightness = NaN;
                }
            }
        }

        function setBrightnessDebounced(value: real): void {
            monitor.queuedBrightness = value;
            timer.start();
        }

        function increaseBrightness(): void {
            const value = !isNaN(monitor.queuedBrightness) ? monitor.queuedBrightness : monitor.brightness;
            if (value < enforceMinBrightness) {
                setBrightnessDebounced(Math.max(stepSize, enforceMinBrightness));
            } else {
                setBrightnessDebounced(value + stepSize);
            }
        }

        function decreaseBrightness(): void {
            const value = !isNaN(monitor.queuedBrightness) ? monitor.queuedBrightness : monitor.brightness;
            setBrightnessDebounced(value - stepSize);
        }

        function setBrightness(value: real): void {
            value = Math.max(enforceMinBrightness, Math.min(1, value));
            var rounded = Math.round(value * 100);

            // Всегда обновляем внутреннее значение и сразу даём обратную связь в UI
            monitor.brightness = value;
            monitor.brightnessUpdated(value);
            root.monitorBrightnessChanged(monitor, monitor.brightness);

            if (timer.running) {
                monitor.queuedBrightness = value;
                return;
            }

            // Если команда уже выполняется — ставим значение в очередь
            if (monitor.commandRunning) {
                monitor.queuedBrightness = value;
                return;
            }

            // Выполняем команду изменения яркости
            if (isAppleDisplay) {
                monitor.commandRunning = true;
                monitor.ignoreNextChange = true;
                setBrightnessProc.command = ["asdbctl", "set", rounded];
                setBrightnessProc.running = true;
            } else if (isDdc && busNum !== "") {
                monitor.commandRunning = true;
                monitor.ignoreNextChange = true;
                var ddcValue = Math.round(value * monitor.maxBrightness);
                var ddcBus = busNum;
                Qt.callLater(() => {
                    setBrightnessProc.command = ["ddcutil", "-b", ddcBus, "--noverify", "--async", "--sleep-multiplier=0.05", "setvcp", "10", ddcValue];
                    setBrightnessProc.running = true;
                });
            } else if (!isDdc) {
                monitor.commandRunning = true;
                monitor.ignoreNextChange = true;
                setBrightnessProc.command = ["brightnessctl", "s", rounded + "%"];
                setBrightnessProc.running = true;
            }
        }

        function initBrightness(): void {
            if (isAppleDisplay) {
                initProc.command = ["asdbctl", "get"];
                initProc.running = true;
            } else if (isDdc && busNum !== "") {
                initProc.command = ["ddcutil", "-b", busNum, "--sleep-multiplier=0.05", "getvcp", "10", "--brief"];
                initProc.running = true;
            } else if (!isDdc) {
                // Внутренняя подсветка — находим первое доступное устройство подсветки и получаем его данные
                initProc.command = ["sh", "-c", "for dev in /sys/class/backlight/*; do " +
                                    "  if [ -f \"$dev/brightness\" ] && [ -f \"$dev/max_brightness\" ]; then " +
                                    "    echo \"$dev\"; " +
                                    "    cat \"$dev/brightness\"; " +
                                    "    cat \"$dev/max_brightness\"; " +
                                    "    break; " +
                                    "  fi; " +
                                    "done"];
                initProc.running = true;
            }
        }

        onBusNumChanged: initBrightness()
        onIsDdcChanged: if (isDdc) initBrightness()
        Component.onCompleted: initBrightness()
    }
}