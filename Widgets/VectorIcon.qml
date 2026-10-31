// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.VectorImage
import "../Common"

Item {
    id: root
    property string name
    property int size: 32
    property color iconColor: Theme.textPrimary
    width: size
    height: size

    VectorImage {
        id: vectorSource
        anchors.fill: parent
        source: root.name ? Qt.resolvedUrl("../assets/icons/animated/" + root.name + ".svg") : ""
        fillMode: VectorImage.PreserveAspectFit
        animations.loops: Animation.Infinite
        visible: false
    }

    ShaderEffectSource {
        id: sourceItem
        sourceItem: vectorSource
        hideSource: true
        live: true          // обязательно для анимации
        recursive: false
        smooth: true
        anchors.fill: parent
    }

    ShaderEffect {
        anchors.fill: parent
        property variant src: sourceItem
        property color tint: root.iconColor
        fragmentShader: Qt.resolvedUrl("../shaders/tint.frag.qsb")
    }
}
