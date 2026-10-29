// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado del panel de energía. La ventana independiente (Power/PowerWindow.qml)
// fue eliminada: el panel ahora es una pestaña de la isla (Island/sections/PowerView.qml).
// Para abrirla desde la terminal se usa CharacterBus (IpcHandler "power"):
//   qs -c minimo-shell ipc call power toggle
Singleton {
    id: root
}
