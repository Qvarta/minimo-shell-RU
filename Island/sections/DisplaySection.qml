// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../../Common"
import "../../Services"

Column {
    id: root
    property bool brightness: true
    property bool vibrance: true
    spacing: 8
    MSlider {
        width: parent.width
        visible: root.brightness
        icon: "sun"
        from: Brightness.minBrightnessValue
        to: 1.0
        // Значение синхронизировано с синглтоном Brightness (backlight/DDC/Apple);
        // любое внешнее изменение (горячие клавиши, brightnessctl) двигает ползунок само.
        value: Brightness.brightness
        valueText: Math.round(value * 100) + "%"
        onMoved: v => Brightness.setBrightness(v)
    }
}
