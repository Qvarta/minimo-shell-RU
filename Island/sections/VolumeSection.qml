// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell.Services.Pipewire
import "../../Common"

// Volumen del sink por defecto (Pipewire nativo). Clic en el icono: silenciar.
MSlider {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    visible: ready
    icon: ready && sink.audio.muted ? "mute" : "volume"
    from: 0; to: 1
    value: ready ? (sink.audio.muted ? 0 : sink.audio.volume) : 0
    valueText: ready && sink.audio.muted ? I18n.tr("Mute") : Math.round(value * 100) + "%"
    iconClickable: true
    onIconClicked: if (ready) sink.audio.muted = !sink.audio.muted
    onMoved: v => { if (ready) { sink.audio.volume = v; if (v > 0) sink.audio.muted = false } }

    // Подсветка клавиатурной навигации из IslandMenu: рисуется dentro del propio
    // slider (Item), no como hijo de un Column, donde los anclajes verticales
    // están prohibidos y rompen el layout.
    Rectangle {
        anchors.fill: parent; anchors.margins: -4; radius: height / 2
        color: "transparent"; border.width: 2; border.color: Theme.fill
        visible: root.selectionRole === "volume" && root.visible
    }
    // Rol de la selección de teclado actual (IslandMenu.currentIndex).
    property string selectionRole: ""
}
