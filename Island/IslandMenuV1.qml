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
    property string page: "menu"   // "menu" | "clip" | "cal" | "quickactions" | "notes" | "weather" | "radio" | "power"

    // Высота панели навигации по вкладкам и зазор под ней.
    readonly property int navHeight: 32
    readonly property int navMargin: 8

    implicitHeight: (page === "clip" ? clip.implicitHeight : page === "cal" ? cal.implicitHeight : page === "quickactions" ? quickActionsView.implicitHeight : page === "notes" ? notes.implicitHeight : page === "weather" ? weather.implicitHeight : page === "radio" ? radio.implicitHeight : page === "power" ? power.implicitHeight : col.implicitHeight) + 40 + navHeight + navMargin

    // Вкладки для циклической навигации стрелками внизу.
    readonly property var tabs: ["menu", "clip", "cal", "quickactions", "notes", "weather", "radio", "power"]

    function enterTab(t) {
        if (t === "clip") clip.refresh()
        else if (t === "cal") cal.reset()
        else if (t === "power") power.reset()
        page = t
    }

    // Циклический переход по вкладкам: n = -1 назад, n = +1 вперёд.
    function cyclePage(n) {
        const i = tabs.indexOf(page)
        enterTab(tabs[(i + n + tabs.length) % tabs.length])
    }

    function showClipboard() { clip.refresh(); page = "clip" }
    function showQuickActions() { page = "quickactions" }
    function showPower() { power.reset(); page = "power" }

    // El buscador no se enfoca solo: se activa al hacerle clic.
    function opened() { search.reset() }

    // Entrada escalonada: stage sube de a uno cada 45 ms al abrir.
    property int stage: 0
    Timer {
        id: stagger; interval: 45; repeat: true
        running: root.open && root.stage < 6
        onTriggered: root.stage++
    }
    onOpenChanged: if (!open) { stage = 0; page = "menu"; notes.reset() }

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

            MediaSection {
                id: media
                width: parent.width

            }
        }
        Reveal {
            step: 3
            width: parent.width
            height: mainSliders.visible ? mainSliders.height : 0
            Item {
                id: mainSliders
                width: parent.width
                readonly property var sliders: ["volume", "brightness"]
                visible: sliders.length > 0
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
    }

    MenuButton {
        icon: "settings"
        anchors.top: parent.top; anchors.topMargin: 20
        anchors.right: parent.right; anchors.rightMargin: 5
        visible: root.open && root.page === "menu"
        onActivated: { root.done(); SettingsState.show() }
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
        onDone: root.done()
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


    QuickActionsView {
        id: quickActionsView
        x: root.page === "quickactions" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "quickactions" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "quickactions"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onDone: root.done()
        onClipboard: root.showClipboard()
        onNotes: root.page = "notes"
        onRadio: root.page = "radio"
        onPower: root.showPower()
    }

    PowerView {
        id: power
        x: root.page === "power" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "power" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "power"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onDone: root.done()
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
        onDone: root.done()
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

    RadioView {
        id: radio
        x: root.page === "radio" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "radio" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "radio"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onDone: root.done()
    }

    component TabArrow: Rectangle {
        id: arrow
        property string iconName: "chevron"
        property real iconRotation: 0
        signal clicked()
        width: 32; height: 32; radius: 16
        color: am.containsMouse ? Theme.textPrimary : Theme.hover
        Icon {
            anchors.centerIn: parent
            name: arrow.iconName
            size: 18
            rotation: arrow.iconRotation
            tone: am.containsMouse ? "gray" : "dark"
        }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked() }
    }

    // Панель навигации по вкладкам:
    // [←]  • • • • • • • •  [→]
    // Точки показывают текущую вкладку и позволяют перейти на любую кликом.
    Item {
        id: tabNav
        visible: root.open
        z: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.navMargin
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.navHeight
        width: navRow.implicitWidth

        Row {
            id: navRow
            anchors.centerIn: parent
            spacing: 10

            TabArrow {
                anchors.verticalCenter: parent.verticalCenter
                iconRotation: 90   // стрелка <-
                onClicked: root.cyclePage(-1)
            }

            // Точки-индикаторы вкладок.
            Row {
                id: dotsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.tabs
                    delegate: Rectangle {
                        id: dot
                        required property int index
                        required property string modelData

                        readonly property bool active: root.page === modelData

                        width: active ? 18 : 6
                        height: 6
                        radius: 3
                        color: active
                               ? Theme.textPrimary
                               : (dotMouse.containsMouse ? Theme.textPrimary : Theme.hover)

                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            id: dotMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.enterTab(dot.modelData)
                        }
                    }
                }
            }

            TabArrow {
                anchors.verticalCenter: parent.verticalCenter
                iconRotation: -90    // стрелка ->
                onClicked: root.cyclePage(1)
            }
        }
    }
}