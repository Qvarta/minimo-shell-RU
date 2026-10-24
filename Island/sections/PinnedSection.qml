// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import "../../Services"
import ".."

Column {
    id: root
    signal done
    signal desktops
    signal clipboard
    signal notes
    spacing: 18

    readonly property var buttons: QuickItems.pinnedButtons
    readonly property string screenshotDirAbs: (Quickshell.env("HOME") || "/tmp") + "/Pictures/Screenshots"

    function takeScreenshot(session) {
        const p = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root);

        if (session === "niri") {
            const nameFormat = "screenshot-%Y-%m-%d_%H-%M-%S";
            p.command = ["sh", "-c", "mkdir -p '" + root.screenshotDirAbs + "' && wayshot -g --silent --file-name-format '" + nameFormat + "' '" + root.screenshotDirAbs + "'"];
        } else {
            // Логика scripts/screenshot.sh: mkdir, выбор области через slurp,
            // захват через grim (отмена выделения не является ошибкой: exit 0),
            // wl-copy как image/png и уведомление только если файл непустой.
            const script = 'd="$1"; mkdir -p "$d" || exit 1; ' + 'f="$d/captura-$(date +%Y%m%d-%H%M%S-%3N).png"; ' + 'g=$(slurp) || exit 0; grim -g "$g" "$f" || exit 1; ' + '[ -s "$f" ] || exit 1; ' + 'wl-copy --type image/png < "$f"; ';
            p.command = ["sh", "-c", script, "screenshot", root.screenshotDirAbs];
        }

        p.running = true;
        p.exited.connect(function (exitCode) {
            p.destroy();
            if (exitCode === 0)
                root.notifyScreenshot();
        });
        root.done();
    }

    function notifyScreenshot() {
        const lang = DisplayState.language;
        const t1 = lang === "en" ? "Screenshot saved" : lang === "ru" ? "Снимок сохранён" : "Captura guardada";
        const t2 = lang === "en" ? "Copied to the clipboard" : lang === "ru" ? "Скопирован в буфер обмена" : "Copiada al portapapeles";
        // Последний созданный .png в каталоге снимков, экранированный для GVariant.
        const script = 'q=$(ls -t "$1"/*.png 2>/dev/null | head -n1); q=$(printf "%s" "$q" | sed "s/\x27/\\\\\x27/g"); ' + 'gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications ' + '--method org.freedesktop.Notifications.Notify "Screenshots" 0 "" "$2" "$3" "[]" ' + '"{\x27image-path\x27: <\x27file://$q\x27>, \x27x-minimo-open\x27: <\x27$q\x27>}" 4000 >/dev/null 2>&1 || true';
        Quickshell.execDetached(["sh", "-c", script, "notify", root.screenshotDirAbs, t1, t2]);
    }

    function activate(id) {
        if (id === "terminal") {
            QuickItems.run("ghostty");
            root.done();
        } else
        // Запись: закрывает остров и запускается через 0,4 с (чтобы не записать открытую панель).
        if (id === "record") {
            if (Recorder.recording)
                Recorder.stop();
            else
                Recorder.start(400);
            root.done();
        } else if (id === "capture") {
            root.takeScreenshot(Compositor.session);
        } else if (id === "desktops")
            root.desktops();
        else if (id === "clipboard")
            root.clipboard();
        else if (id === "notes")
            root.notes();
        else
        // Браузер / файлы: остров закрывается только если приложение запустилось; иначе — сообщение об ошибке.
        if (id === "browser" || id === "nautilus")
            Launch.open(id);
        else {
            const c = QuickItems.custom(id);
            if (c) {
                QuickItems.run(c.cmd);
                root.done();
            }
        }
    }

    Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.buttons.length > 0
        columns: 1
        rowSpacing: 4
        Repeater {
            model: root.buttons
            delegate: MenuButton {
                id: b
                required property string modelData
                readonly property var item: QuickItems.builtins.find(x => x.id === modelData) ?? QuickItems.custom(modelData)
                readonly property bool rec: modelData === "record" && Recorder.recording
                icon: rec ? "stop" : (item && item.icon ? item.icon : "")
                letter: item && !item.icon ? item.label.charAt(0).toUpperCase() : ""
                label: rec ? I18n.tr("Detener") : modelData === "record" ? I18n.tr("Grabar") : (item ? item.label : "")
                active: rec
                onActivated: root.activate(b.modelData)
            }
        }
    }

    Connections {
        target: Launch
        function onLaunched() {
            root.done();
        }
    }

    Text {
        width: parent.width
        visible: Launch.error !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: Launch.error
        color: Theme.danger
        font.family: Theme.font
        font.pixelSize: 12
    }
}
