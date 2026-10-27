// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "qml" as NQ // папка с парсером конфига niri (перенесён из плагина niri-cheatsheet)
import "../Common"

// Строка горячих клавиш: слева описание действия, справа — комбинация клавиш.
// keys — строка вида "Super + Shift + 1" (формат парсера niri-cheatsheet).
Item {
    id: row
    property string label
    property string keys
    property bool last: false
    implicitHeight: Math.max(44, name.implicitHeight + 22)

    // Парсер конфигурации niri (логика плагина niri-cheatsheet).
    NQ.NiriBindsParser { id: parser }

    // Метод получения клавиш: читает конфиг niri (binds.kdl) по пути configPath,
    // парсит его и вызывает onDone с массивом категорий
    // [{ title, binds: [{ keys, desc }] }].
    function getShortcuts(configPath, onDone) {
        var handler = function (categories) {
            parser.parsed.disconnect(handler);
            if (onDone) onDone(categories);
        };
        parser.parsed.connect(handler);
        parser.parseFile(configPath);
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
