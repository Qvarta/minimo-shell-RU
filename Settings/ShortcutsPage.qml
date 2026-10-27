// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../Common"

// Atajos de teclado: página en construcción (la generación desde la configuración
// de Hyprland con scripts/atajos.py se retiró). Por ahora muestra una lista vacía.
Column {
    id: root
    spacing: 20
    property bool shown: false
    property var groups: [] // TODO: reimplementar la lectura de atajos.

    onShownChanged: if (shown) groups = [] // TODO: cargar los atajos aquí.
}
