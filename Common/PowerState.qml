// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado del panel de energía (ventana independiente, como el lanzador).
// Desde la terminal:
//   qs -c minimo-shell ipc call power open|close|toggle
Singleton {
    id: root
    property bool open: false
    function toggle() { open = !open }
    function show() { open = true }
    function hide() { open = false }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
    }
}
