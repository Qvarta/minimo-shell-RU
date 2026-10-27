// SPDX-License-Identifier: MIT

import QtQuick
import Quickshell
import "../Common"
import "../Services"

Rectangle {
    id: root
    radius: Theme.radiusCard
    color: Theme.cardSolid
    border.width: 1; border.color: Theme.track
    implicitHeight: contentCol.implicitHeight + 32
    property bool shown: false

    // Файл с биндами Niri.
    readonly property string configPath: Quickshell.env("HOME") + "/.config/niri/binds.kdl"

    property var groups: []
    property bool loaded: false

    onShownChanged: if (shown && !loaded) loadConfig()

    ShortcutRow {
        id: rowProbe
        visible: false
        width: 0; height: 0
    }

    function loadConfig() {
        rowProbe.getShortcuts(configPath, categories => {
            root.groups = categories || [];
            root.loaded = true;
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

                // Заголовок категории
                Rectangle {
                    id: catHeader
                    width: group.width - 36
                    x: 18
                    height: catHeaderText.implicitHeight + 2 * vPad
                    radius: 8
                    color: Theme.field

                    readonly property int vPad: group.index === 0 ? 8 : 14

                    Text {
                        id: catHeaderText
                        anchors.centerIn: parent
                        width: parent.width - 24
                        text: group.modelData.title.toUpperCase()
                        color: Theme.textSecondary
                        font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                Repeater {
                    id: innerRep
                    model: group.modelData.binds
                    delegate: ShortcutRow {
                        id: bind
                        required property var modelData
                        required property int index
                        width: group.width
                        label: bind.modelData.desc
                        keys: bind.modelData.keys
                        last: bind.index === (group.modelData.binds.length ?? innerRep.itemCount) - 1
                              && group.index === root.groups.length - 1
                    }
                }
            }
        }

        // если бинды не найдены
        Text {
            visible: root.loaded && root.groups.length === 0
            width: parent.width - 36
            anchors.horizontalCenter: parent.horizontalCenter
            text: Compositor.session !== "niri"
                  ? I18n.tr("Se requiere una sesión de Niri")
                  : I18n.tr("Не удалось найти бинды Niri. Проверьте файл ~/.config/niri/binds.kdl.\n\nФормат: отдельный комментарий // Категория, затем каждый бинд на одной строке: Mod+M { spawn \"spotify\"; } // Описание. Название бинда указывается после закрывающей фигурной скобки }.")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
            topPadding: 10
        }
    }
}
