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

    // Пути к возможным файлам с биндами niri (в порядке приоритета).
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri"
    readonly property var configCandidates: [configDir + "/binds.kdl", configDir + "/config.kdl"]

    property var groups: []
    property bool loaded: false

    onShownChanged: if (shown && !loaded) parseConfig(0)

    ShortcutRow {
        id: rowProbe
        visible: false
        width: 0; height: 0
    }

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
            anchors.horizontalCenter: parent.horizontalCenter
            text: Compositor.session === "niri" ? I18n.tr("No se encontraron atajos") : I18n.tr("Se requiere una sesión de Niri")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
            topPadding: 10
        }
    }
}
