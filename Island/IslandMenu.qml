// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Layouts
import "../Common"
import "../Character"
import "sections"

// Menú de la isla expandida: compone las secciones con entrada escalonada.
Item {
    id: root
    signal done()
    property bool open: false
    readonly property bool searchFocused: search.hasFocus
    property alias character: chr
    property string page: "menu"   // "menu" | "desks" | "clip" | "cal" | "pinned" | "notes" | "weather"
    implicitHeight: (page === "desks" ? desks.implicitHeight : page === "clip" ? clip.implicitHeight : page === "cal" ? cal.implicitHeight : page === "pinned" ? pinnedView.implicitHeight : page === "notes" ? notes.implicitHeight : page === "weather" ? weather.implicitHeight : col.implicitHeight) + 40

    function showClipboard() { clip.refresh(); page = "clip" }

    // El buscador no se enfoca solo: se activa al hacerle clic.
    function opened() { search.reset() }

    // Entrada escalonada: stage sube de a uno cada 45 ms al abrir.
    property int stage: 0
    Timer {
        id: stagger; interval: 45; repeat: true
        running: root.open && root.stage < 6
        onTriggered: root.stage++
    }
    onOpenChanged: if (!open) { stage = 0; page = "menu"; actions.reset(); notes.reset() }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    component Reveal: Item {
        property int step: 0
        opacity: root.stage > step ? 1 : 0
        transform: Translate { y: root.stage > step ? 0 : 8; Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } } }
        Behavior on opacity { NumberAnimation { duration: 260 } }
    }

    Column {
        id: col
        x: root.page === "menu" ? 20 : -root.width * 0.3
        y: 20
        opacity: root.page === "menu" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "menu"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        width: parent.width - 40
        spacing: 22

        Reveal {
            step: 0; width: parent.width; height: 48
            RowLayout {
                anchors.fill: parent
                spacing: 15  
                Character {
                    id: chr; size: 44; active: root.open && DisplayState.characterAnimated; Layout.alignment: Qt.AlignVCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: m => chr.clicked((m.x - width / 2) / (width / 2)) }
                }
                Column {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.textPrimary; font.family: Theme.font
                        font.pixelSize: 26; font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                    // Clic en la fecha → calendario.
                    Text {
                        text: I18n.longDate(clock.date)
                        color: dateMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                        MouseArea { id: dateMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { cal.reset(); root.page = "cal" } }
                    }
                    WeatherSection { font.family: Theme.font; font.pixelSize: 12
                        onClicked: root.page = "weather" }
                }
            }
        }
        Reveal { step: 1; width: parent.width; height: search.implicitHeight
            SearchSection { id: search; width: parent.width; onLaunched: root.done() } }
        Reveal {
            id: mediaReveal
            step: 2
            width: parent.width
            height: media.implicitHeight
            visible: media.player !== null
            onVisibleChanged: console.log("[MediaDebug] IslandMenu media Reveal visibility:",
                                          "visible=", visible, "opacity=", opacity,
                                          "stage=", root.stage, "open=", root.open,
                                          "page=", root.page, "height=", height,
                                          "media.visible=", media.visible,
                                          "media.player=", media.player ? media.player.identity : "<none>")
            Component.onCompleted: {
                console.log("[MediaDebug] IslandMenu media Reveal created:",
                            "visible=", visible, "opacity=", opacity,
                            "stage=", root.stage, "open=", root.open,
                            "page=", root.page, "height=", height,
                            "media.visible=", media.visible,
                            "media.player=", media.player ? media.player.identity : "<none>")
            }
            MediaSection {
                id: media
                width: parent.width
                onPlayerChanged: console.log("[MediaDebug] IslandMenu observed media.player:",
                                             player ? player.identity : "<none>",
                                             "media.visible=", visible,
                                             "reveal.visible=", mediaReveal.visible,
                                             "reveal.height=", mediaReveal.height)
            }
        }
        Reveal {
            step: 3
            width: parent.width
            height: mainSliders.visible ? mainSliders.height : 0
            Item {
                id: mainSliders
                width: parent.width
                visible: QuickItems.pinnedSliders.length > 0
                readonly property var sliders: QuickItems.pinnedSliders
                readonly property int volAt: sliders.indexOf("volume")
                readonly property bool volFirst: volAt === 0
                readonly property real volH: vol.visible ? vol.height : 0
                readonly property real dispH: disp.visible ? disp.height : 0
                readonly property real gap: vol.visible && disp.visible ? 8 : 0
                height: volH + dispH + gap
                VolumeSection {
                    id: vol
                    width: parent.width
                    visible: ready && mainSliders.volAt >= 0
                    y: mainSliders.volFirst ? 0 : mainSliders.dispH + mainSliders.gap
                }
                DisplaySection {
                    id: disp
                    width: parent.width
                    visible: brightness
                    y: mainSliders.volFirst ? mainSliders.volH + mainSliders.gap : 0
                    brightness: mainSliders.sliders.indexOf("brightness") >= 0
                }
            }
        }
        Reveal { step: 4; width: parent.width; height: actions.implicitHeight
            ActionsSection {
                id: actions
                anchors.horizontalCenter: parent.horizontalCenter
                onDone: root.done()
                onPinned: root.page = "pinned"
            } }
    }

    MenuButton {
        icon: "settings"
        anchors.top: parent.top; anchors.topMargin: 20
        anchors.right: parent.right; anchors.rightMargin: 5
        visible: root.open && root.page === "menu"
        onActivated: { actions.reset(); root.done(); SettingsState.show() }
    }

    WorkspacesView {
        id: desks
        x: root.page === "desks" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "desks" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "desks"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onPicked: root.done()
    }

    ClipboardView {
        id: clip
        x: root.page === "clip" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "clip" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "clip"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onPicked: root.done()
    }

    CalendarView {
        id: cal
        x: root.page === "cal" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        today: clock.date
        locale: I18n.locale
        opacity: root.page === "cal" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "cal"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
    }

    PinnedView {
        id: pinnedView
        x: root.page === "pinned" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "pinned" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "pinned"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onDone: root.done()
        onDesktops: { desks.refresh(); root.page = "desks" }
        onClipboard: root.showClipboard()
        onNotes: root.page = "notes"
    }

    NotesView {
        id: notes
        x: root.page === "notes" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "notes" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "notes"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
    }

    WeatherView {
        id: weather
        x: root.page === "weather" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        locale: I18n.locale
        opacity: root.page === "weather" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "weather"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
    }
}
