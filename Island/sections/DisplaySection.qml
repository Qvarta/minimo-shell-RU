// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../../Common"
import "../../Services"

Column {
    id: root
    property bool brightness: true
    spacing: 8
    // Управление с клавиатуры из IslandMenu (пробрасываем к ползунку яркости).
    function increase() { if (slider.visible) slider.increase() }
    function decrease() { if (slider.visible) slider.decrease() }
    MSlider {
        id: slider
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
