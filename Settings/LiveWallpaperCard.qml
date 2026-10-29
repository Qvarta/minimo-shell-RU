// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"
import "../Services"

// Fondo animado: video o GIF en bucle con mpvpaper (opcional). Se elige con el selector
// de archivos; mientras está activo reemplaza al fondo estático (que vuelve al quitarlo).
Rectangle {
    id: root
    signal pickerOpened()
    readonly property string file: DisplayState.liveWallpaper
    readonly property string fileName: file.substring(file.lastIndexOf("/") + 1)
    height: col.implicitHeight
    radius: 20
    color: Theme.surface

    Process {
        id: picker
        command: ["zenity", "--file-selection", "--title=" + I18n.tr("Choose animated wallpaper"),
                  "--filename=" + Quickshell.env("HOME") + "/Vídeos/",
                  "--file-filter=" + I18n.tr("Videos and GIFs") + " | *.mp4 *.webm *.mkv *.mov *.gif *.MP4 *.WEBM *.GIF"]
        stdout: SplitParser { onRead: line => { const p = line.trim(); if (p !== "" && LiveWallpaper.isAnimated(p)) DisplayState.setLiveWallpaper(p) } }
    }

    Column {
        id: col
        width: parent.width
        Item {
            width: parent.width; height: 64
            Column {
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.right: buttons.left; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { text: I18n.tr("Animated wallpaper"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
                Text {
                    width: parent.width; elide: Text.ElideMiddle
                    text: !LiveWallpaper.available ? I18n.tr("Needs mpvpaper (AUR): yay -S mpvpaper")
                        : root.file !== "" ? root.fileName + (LiveWallpaper.paused ? I18n.tr(" · paused") : "")
                        : I18n.tr("A looping video or GIF, without sound.")
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                }
            }
            Row {
                id: buttons
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                PillButton {
                    visible: root.file !== ""
                    text: I18n.tr("Remove"); outlined: true
                    border.color: Theme.dot
                    onClicked: DisplayState.setLiveWallpaper("")
                }
                PillButton {
                    text: root.file !== "" ? I18n.tr("Change…") : I18n.tr("Choose…")
                    opacity: LiveWallpaper.available ? 1 : 0.4
                    enabled: LiveWallpaper.available
                    onClicked: if (!picker.running) { root.pickerOpened(); picker.running = true }
                }
            }
        }
        Rectangle { visible: root.file !== ""; x: 18; width: parent.width - 36; height: 1; color: Theme.track }
        SwitchRow {
            visible: root.file !== ""
            width: parent.width
            text: I18n.tr("Pause when windows are open")
            detail: I18n.tr("Saves GPU and battery: it only moves when the desktop is clear. Always pauses when idle.")
            checked: DisplayState.livePauseCovered
            onToggled: v => DisplayState.setLivePauseCovered(v)
        }
    }
}
