// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"
import "logic/niribinds.js" as NB

// Строка горячих клавиш: слева описание действия, справа — комбинация клавиш.
// keys — строка вида "Super + Shift + 1".
Item {
    id: row
    property string label
    property string keys
    property bool last: false
    implicitHeight: Math.max(44, name.implicitHeight + 22)

    // Буфер для чтения файла конфига niri (смена path перезагружает содержимое).
    FileView {
        id: cfgFile
        onLoadedChanged: {
            if (!loaded) return;
            const content = text();
            // Парсим конфиг чистым JS-парсером и отдаём результат колбэку.
            const categories = content ? NB.parse(content) : [];
            if (categories.length > 0 || !probeProcess.running) finish(categories);
        }
    }

    // Проба существования файла конфига: если файла нет, проба завершает запрос
    // пустым списком — так ShortcutsPage может перейти к следующему кандидату.
    Process {
        id: probeProcess
        running: false
        property bool found: false
        stdout: SplitParser { onRead: data => { probeProcess.found = true; } }
        onExited: (exitCode, exitStatus) => {
            if (!probeProcess.found) finish([]);
        }
    }

    // Колбэк, в который getShortcuts() вернёт распарсенные категории.
    property var onParsed: null

    // Завершает текущий запрос: отдаёт результат колбэку и очищает состояние.
    function finish(categories) {
        const cb = row.onParsed;
        row.onParsed = null;
        if (cb) cb(categories);
    }

    // Метод получения клавиш: читает конфиг niri по пути configPath и вызывает
    // onDone с массивом категорий [{ title, binds: [{ keys, desc }] }].
    // Если файл отсутствует или пуст — onDone получает [].
    function getShortcuts(configPath, onDone) {
        row.onParsed = onDone ?? null;
        const dir = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        const path = configPath || (dir + "/niri/binds.kdl");
        probeProcess.found = false;
        probeProcess.command = ["sh", "-c", "[ -f \"" + path + "\" ] && echo ok"];
        probeProcess.running = true;
        cfgFile.path = path;
    }

    Text {
        id: name
        anchors.left: parent.left; anchors.leftMargin: 18
        anchors.right: keysRow.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        wrapMode: Text.WordWrap
        color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14
    }
    Row {
        id: keysRow
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
            // Разбиваем "Super + A" в список частей ["Super", "A"].
            model: row.keys.split("+").map(s => s.trim()).filter(s => s.length > 0)
            delegate: KeyCap { required property string modelData; text: modelData }
        }
    }
    Rectangle {
        visible: !row.last
        anchors.bottom: parent.bottom
        x: 18; width: parent.width - 18; height: 1
        color: Theme.track
    }
}
