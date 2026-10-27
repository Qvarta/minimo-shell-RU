// SPDX-License-Identifier: MIT

import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"
import "logic/niribinds.js" as NB


Item {
    id: row
    property string label
    property string keys
    property bool last: false
    implicitHeight: Math.max(44, name.implicitHeight + 22)

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


    Process {
        id: probeProcess
        running: false
        property bool found: false
        stdout: SplitParser { onRead: data => { probeProcess.found = true; } }
        onExited: (exitCode, exitStatus) => {
            if (!probeProcess.found) finish([]);
        }
    }

    property var onParsed: null

    function finish(categories) {
        const cb = row.onParsed;
        row.onParsed = null;
        if (cb) cb(categories);
    }

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
            model: row.keys.split("+").map(s => s.trim()).filter(s => s.length > 0)
            delegate: Rectangle {
                id: cap
                required property string modelData
                implicitWidth: Math.max(26, capLabel.implicitWidth + 16)
                implicitHeight: 24
                radius: 7
                color: Theme.raised
                border.width: 1; border.color: Theme.track
                Text {
                    id: capLabel
                    anchors.centerIn: parent
                    text: cap.modelData
                    color: Theme.textPrimary
                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                }
            }
        }
    }
    Rectangle {
        visible: !row.last
        anchors.bottom: parent.bottom
        x: 18; width: parent.width - 18; height: 1
        color: Theme.track
    }
}
