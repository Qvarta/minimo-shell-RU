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
    property string page: "menu"   // "menu" | "clip" | "cal" | "quickactions" | "notes" | "weather" | "radio"
    implicitHeight: (page === "clip" ? clip.implicitHeight : page === "cal" ? cal.implicitHeight : page === "quickactions" ? quickActionsView.implicitHeight : page === "notes" ? notes.implicitHeight : page === "weather" ? weather.implicitHeight : page === "radio" ? radio.implicitHeight : col.implicitHeight) + 40

    function showClipboard() { clip.refresh(); page = "clip" }
    function showQuickActions() { page = "quickactions" }

    // ───────────────────── Навигация с клавиатуры (главная страница) ─────────────────────
    // Подстраницы (radio, quickactions, clipboard, notes) обрабатывают клавиши сами;
    // здесь навигация по элементам главной страницы меню.
    readonly property var menuItems: ["search", "volume", "brightness", "logout", "restart", "poweroff", "quick", "settings"]
    property int currentIndex: 0

    readonly property bool volVisible: vol.ready
    readonly property bool dispVisible: disp.brightness

    function itemsList() {
        var list = []
        for (var i = 0; i < menuItems.length; i++) {
            const id = menuItems[i]
            if (id === "volume" && !volVisible) continue
            if (id === "brightness" && !dispVisible) continue
            list.push(id)
        }
        return list
    }

    function itemAt(index) {
        const list = itemsList()
        if (list.length === 0)
            return ""
        return list[(index % list.length + list.length) % list.length]
    }

    function indexOfItem(id) { return itemsList().indexOf(id) }

    function clampSelection() {
        const n = itemsList().length
        if (n === 0) { currentIndex = 0; return }
        if (currentIndex >= n) currentIndex = n - 1
    }

    function moveSelection(delta) {
        const n = itemsList().length
        if (n === 0)
            return
        currentIndex = (currentIndex + delta + n) % n
    }

    function activateItem(id) {
        if (id === "search") search.focusField()
        else if (id === "volume") vol.increase()
        else if (id === "brightness") disp.increase()
        else if (id === "logout") actions.press("logout")
        else if (id === "restart") actions.press("reboot")
        else if (id === "poweroff") actions.press("poweroff")
        else if (id === "quick") page = "quickactions"
        else if (id === "settings") { actions.reset(); root.done(); SettingsState.show() }
    }

    function adjustCurrent(delta) {
        const id = itemAt(currentIndex)
        if (id === "volume") vol.stepBy(delta)
        else if (id === "brightness") { if (delta > 0) disp.increase(); else disp.decrease() }
        else activateCurrent()
    }

    function activateCurrent() {
        const id = itemAt(currentIndex)
        if (id !== "")
            activateItem(id)
    }

    // IslandMenu está dentro de la píldora, que conserva su propio foco: pedimos
    // el foco cuando esta página está activa para que lleguen las flechas/Enter.
    focus: enabled

    function requestKeyboardFocus() {
        Qt.callLater(function() {
            if (root.enabled && root.visible)
                root.forceActiveFocus()
        })
        // Segundo intento: Island.qml lanza unfocusLater (150 ms), que devuelve
        // el foco a la píldora al abrir la isla.
        refocusTimer.restart()
    }

    Timer {
        id: refocusTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.enabled && root.visible && !root.activeFocus)
                root.forceActiveFocus()
        }
    }

    onEnabledChanged: if (enabled) requestKeyboardFocus()
    Component.onCompleted: requestKeyboardFocus()

    // Esc cierra la isla entera (done); con otra página abierta decide esa página
    // (las subpáginas capturan la tecla antes que el menú).
    Keys.onEscapePressed: event => {
        event.accepted = true
        root.done()
    }
    // Arriba/abajo mueven la selección; izquierda/derecha ajustan el slider enfocado.
    Keys.onUpPressed: event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onDownPressed: event => { event.accepted = true; root.moveSelection(1) }
    Keys.onLeftPressed: event => { event.accepted = true; root.adjustCurrent(-1) }
    Keys.onRightPressed: event => { event.accepted = true; root.adjustCurrent(1) }
    Keys.onReturnPressed: event => { event.accepted = true; root.activateCurrent() }
    Keys.onEnterPressed: event => { event.accepted = true; root.activateCurrent() }
    Keys.onSpacePressed: event => { event.accepted = true; root.activateCurrent() }

    // El buscador no se enfoca solo: se activa al hacerle clic.
    function opened() { search.reset(); clampSelection() }

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
            SearchSection { id: search; width: parent.width; onLaunched: root.done() }
            // Аро выбора клавиатурной навигации (IslandMenu.currentIndex).
            Rectangle {
                anchors.fill: search; anchors.margins: -5; radius: 24
                color: "transparent"; border.width: 2; border.color: Theme.fill
                visible: root.page === "menu" && root.itemAt(root.currentIndex) === "search"
            }
        }
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
                    // Подсветка выбора клавиатурной навигации (IslandMenu.currentIndex).
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -4; radius: height / 2
                        color: "transparent"; border.width: 2; border.color: Theme.fill
                        visible: root.page === "menu" && root.itemAt(root.currentIndex) === "volume"
                    }
                }
                DisplaySection {
                    id: disp
                    width: parent.width
                    visible: brightness
                    y: mainSliders.volFirst ? mainSliders.volH + mainSliders.gap : 0
                    brightness: mainSliders.sliders.indexOf("brightness") >= 0
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -4; radius: height / 2
                        color: "transparent"; border.width: 2; border.color: Theme.fill
                        visible: root.page === "menu" && root.itemAt(root.currentIndex) === "brightness"
                    }
                }
            }
        }
        Reveal { step: 4; width: parent.width; height: actions.implicitHeight
            ActionsSection {
                id: actions
                anchors.horizontalCenter: parent.horizontalCenter
                onDone: root.done()
                onQuickActions: root.page = "quickactions"
            } }
    }

    MenuButton {
        icon: "settings"
        anchors.top: parent.top; anchors.topMargin: 20
        anchors.right: parent.right; anchors.rightMargin: 5
        visible: root.open && root.page === "menu"
        onActivated: { actions.reset(); root.done(); SettingsState.show() }
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
}
