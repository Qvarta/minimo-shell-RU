// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../../Common"
import "../../Services"

Item {
    id: root
    property bool brightness: true
    implicitHeight: slider.height
    // Управление с клавиатуры из IslandMenu (пробрасываем к ползунку яркости).
    function increase() { if (slider.visible) slider.increase() }
    function decrease() { if (slider.visible) slider.decrease() }
    function stepBy(delta) { if (slider.visible) slider.stepBy(delta) }
    MSlider {
        id: slider
        anchors.left: parent.left; anchors.right: parent.right
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
    // Подсветка клавиатурной навигации: рисуется здесь (внутри Item), а не как
    // дочерний элемент в Column на стороне IslandMenu — якоря по вертикали внутри
    // Column недопустимы и ломают раскладку.
    Rectangle {
        anchors.fill: slider; anchors.margins: -4; radius: height / 2
        color: "transparent"; border.width: 2; border.color: Theme.fill
        visible: root.selectionRole === "brightness" && root.brightness
    }
    // Роль текущего элемента клавиатурной навигации из IslandMenu (для подсветки).
    property string selectionRole: ""
}
