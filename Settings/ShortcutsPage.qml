// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../Common"
import "../Services"

// Горячие клавиши: список биндов, прочитанных из конфигурации niri.
// Получением и парсингом клавиш занимается ShortcutRow.getShortcuts() —
// самостоятельный парсер (logic/niribinds.js), не зависящий от внешних плагинов.
Rectangle {
    id: root
    radius: Theme.radiusCard
    color: Theme.cardSolid
    border.width: 1; border.color: Theme.track
    implicitHeight: contentCol.implicitHeight + 32
    property bool shown: false

    // Пути к возможным файлам с биндами niri (в порядке приоритета).
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri"
    readonly property var configCandidates: [configDir + "/binds.kdl", configDir + "/config.kdl"]

    property var groups: []
    property bool loaded: false

    // При открытии вкладки один раз загружаем список клавиш.
    onShownChanged: if (shown && !loaded) parseConfig(0)

    // Невидимая строка-«пробник»: используется только ради метода getShortcuts().
    ShortcutRow {
        id: rowProbe
        visible: false
        width: 0; height: 0
    }

    // Пробуем кандидаты конфига по очереди; результат приходит через onDone.
    function parseConfig(index) {
        if (index >= configCandidates.length) { loaded = true; return; }
        rowProbe.getShortcuts(configCandidates[index], categories => {
            if (categories && categories.length > 0) {
                root.groups = categories;
                root.loaded = true;
            } else {
                parseConfig(index + 1);
            }
        });
    }

    Column {
        id: contentCol
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.topMargin: 16
        spacing: 0

        Repeater {
            model: root.groups
            delegate: Column {
                id: group
                required property var modelData
                required property int index
                width: contentCol.width
                spacing: 0

                SectionTitle {
                    text: group.modelData.title.toUpperCase()
                    leftPadding: 18
                    topPadding: group.index === 0 ? 0 : 14
                    bottomPadding: 6
                }

                Repeater {
                    model: group.modelData.binds
                    delegate: ShortcutRow {
                        id: bind
                        required property var modelData
                        required property int index
                        required property int count
                        width: group.width
                        label: bind.modelData.desc
                        keys: bind.modelData.keys
                        last: bind.index === bind.count - 1 && group.index === root.groups.length - 1
                    }
                }
            }
        }

        // Сообщение, если бинды не найдены (например, сессия не niri).
        Text {
            visible: root.loaded && root.groups.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: Compositor.session === "niri" ? I18n.tr("No se encontraron atajos") : I18n.tr("Se requiere una sesión de Niri")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
            topPadding: 10
        }
    }
}
