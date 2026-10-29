// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick

// Монохромная SVG-иконка из единственного исходного набора assets/icons/src/.
// tone сохраняет прежнюю семантику вызовов: dark, gray или white.
// Цвет применяется шейдером, поэтому копии SVG для разных тем не нужны.
Item {
    id: root

    property string name
    property string tone: "dark" // dark | gray | white
    property int size: 20

    width: size
    height: size

    readonly property color resolvedColor: {
        if (tone === "white")
            return Theme.dark ? "#0A0A0B" : "#FFFFFF"
        if (tone === "gray")
            return Theme.dark ? "#AEAEB2" : "#6E6E73"
        return Theme.dark ? "#FFFFFF" : "#0A0A0B"
    }

    Image {
        id: sourceImage
        anchors.fill: parent
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        source: root.name ? Qt.resolvedUrl("../assets/icons/src/" + root.name + ".svg") : ""
        smooth: true
        visible: false
    }

    ShaderEffectSource {
        id: iconTexture
        anchors.fill: parent
        sourceItem: sourceImage
        hideSource: true
        live: true
        smooth: true
    }

    ShaderEffect {
        anchors.fill: parent
        property variant src: iconTexture
        property color tint: root.resolvedColor
        fragmentShader: Qt.resolvedUrl("../shaders/tint.frag.qsb")
    }
}
