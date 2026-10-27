// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Services"

// Положение курсора: Hyprland использует IPC-скрипт, остальные сессии — MouseArea
// на слое обоев (для пустого рабочего стола).
Singleton {
    id: root
    property int users: 0
    property real x: -1
    property real y: -1
    property bool ok: false
    property real lastMove: 0

    function acquire() { if (users === 0) lastMove = Date.now(); users++ }
    function release() { users = Math.max(0, users - 1) }

    Process {
        id: proc
        running: root.users > 0 && Compositor.session === "hyprland"
        // Перезапуск IPC-скрипта нужен только в сессии Hyprland.
        onExited: if (root.users > 0 && Compositor.session === "hyprland") relaunch.restart()
        command: [Qt.resolvedUrl("../scripts/cursorpos.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^(-?\d+),\s*(-?\d+)/)
                if (!m) return
                const nx = +m[1], ny = +m[2]
                if (nx !== root.x || ny !== root.y) { root.lastMove = Date.now(); root.x = nx; root.y = ny }
                root.ok = true
            }
        }
    }
    Timer {
        id: relaunch
        interval: 2000
        onTriggered: if (root.users > 0 && Compositor.session === "hyprland") { proc.running = false; proc.running = true }
    }
}
