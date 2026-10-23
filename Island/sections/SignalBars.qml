// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../../Common"

// Cuatro barritas de señal (0..100), crecientes de izquierda a derecha y
// alineadas por su base. El delegate NUNCA usa `parent`: bajo
// pragma ComponentBehavior: Bound, durante la creación del objeto `parent`
// es null y cada reevaluación dispara "TypeError: Cannot read property
// 'bottom'/'signal' of null". El acceso al padre real se hace vía el id
// explícito `row`, que siempre está definido.
Row {
    id: row
    property int signal: 0
    property color on: Theme.textPrimary
    spacing: 2
    Repeater {
        model: 4
        delegate: Rectangle {
            id: bar
            required property int index
            // Base común: todas las barritas apoyadas sobre el borde inferior
            // de la fila. Como Row centra a sus hijos verticalmente, basta con
            // desplazar cada barra (maxHeight - bar.height)/2 hacia abajo.
            readonly property int maxHeight: 4 + 3 * 3
            anchors.verticalCenter: row.verticalCenter
            anchors.verticalCenterOffset: (maxHeight - bar.height) / 2
            width: 3
            height: 4 + index * 3
            radius: 1.5
            color: row.signal > index * 25 ? row.on : Theme.track
        }
    }
}
