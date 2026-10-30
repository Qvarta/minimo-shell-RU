// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Layouts
import "../Common"
import "../Character"
import "sections"

Item {
    id: root

    signal done()
    property bool open: false
    readonly property bool searchFocused: search.hasFocus
    property alias character: chr
    property string page: "menu"

    readonly property int navWidth: 48
    readonly property int navItemSize: 40
    readonly property int navItemGap: 4
    readonly property int navPad: 4
    readonly property int navGap: 12
    readonly property int contentX: navWidth + navGap + 8
    readonly property int contentWidth: Math.max(0, width - contentX - 20)
    readonly property int navHeight: tabs.length * navItemSize + (tabs.length - 1) * navItemGap + 2 * navPad

    readonly property real activePageHeight: page === "clip" ? clip.implicitHeight
        : page === "notifications" ? notificationHistory.implicitHeight
        : page === "cal" ? cal.implicitHeight
        : page === "quickactions" ? quickActionsView.implicitHeight
        : page === "notes" ? notes.implicitHeight
        : page === "weather" ? weather.implicitHeight
        : page === "radio" ? radio.implicitHeight
        : page === "power" ? power.implicitHeight
        : col.implicitHeight

    // Reserve enough room for the complete navigation even when the selected page is empty.
    implicitHeight: Math.max(activePageHeight, navHeight) + 40

    readonly property var tabs: ["menu", "clip", "notifications", "cal", "quickactions", "notes", "weather", "radio", "power"]

    readonly property var tabIcons: ({
        "menu":         "home",
        "clip":         "clipboard",
        "notifications": "bell",
        "cal":          "calendar",
        "quickactions": "quickactions",
        "notes":        "note",
        "weather":      "clear-day",
        "radio":        "music",
        "power":        "logout"
    })

    function enterTab(t) {
        if (t === "clip") clip.refresh()
        else if (t === "notifications") notificationHistory.reset()
        else if (t === "cal") cal.reset()
        else if (t === "power") power.reset()
        page = t
    }

    function cyclePage(n) {
        const i = tabs.indexOf(page)
        enterTab(tabs[(i + n + tabs.length) % tabs.length])
    }

    function showClipboard() { clip.refresh(); page = "clip" }
    function showNotifications() { notificationHistory.reset(); page = "notifications" }
    function showQuickActions() { page = "quickactions" }
    function showPower() { power.reset(); page = "power" }

    function opened() { search.reset() }

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
        x: root.page === "menu" ? root.contentX : root.width + 20
        y: 20
        opacity: root.page === "menu" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "menu"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        width: root.contentWidth
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
        anchors.left: parent.left
        anchors.leftMargin: root.contentX + root.contentWidth - width - 5
        visible: root.open && root.page === "menu"
        onActivated: { root.done(); SettingsState.show() }
    }

    ClipboardView {
        id: clip
        x: root.page === "clip" ? root.contentX : root.width + 20
        y: 20
        width: root.contentWidth
        opacity: root.page === "clip" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "clip"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onPicked: root.done()
        onDone: root.done()
    }

    NotificationHistoryView {
        id: notificationHistory
        x: root.page === "notifications" ? root.contentX : root.width + 20
        y: 20
        width: root.contentWidth
        opacity: root.page === "notifications" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "notifications"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onDone: root.done()
    }

    CalendarView {
        id: cal
        x: root.page === "cal" ? root.contentX : root.width + 20
        y: 20
        width: root.contentWidth
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
        x: root.page === "quickactions" ? root.contentX : root.width + 20
        y: 20
        width: root.contentWidth
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
        x: root.page === "power" ? root.contentX : root.width + 20
        y: 20
        width: root.contentWidth
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
        x: root.page === "notes" ? root.contentX : root.width + 20
        y: 20
        width: root.contentWidth
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
        x: root.page === "weather" ? root.contentX : root.width + 20
        y: 20
        width: root.contentWidth
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
        x: root.page === "radio" ? root.contentX : root.width + 20
        y: 20
        width: root.contentWidth
        opacity: root.page === "radio" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "radio"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onDone: root.done()
    }

    component TabButton: Item {
        id: tab
        property string iconName: "home"
        property bool active: false
        signal clicked()

        width: root.navItemSize
        height: root.navItemSize

        Rectangle {
            id: tabBackground
            anchors.centerIn: parent
            width: tab.active ? 40 : 32
            height: tab.active ? 40 : 32
            radius: height / 2

            color: tab.active
                   ? Theme.textPrimary
                   : (tabMouse.containsMouse ? Theme.hover : Theme.track)

            Behavior on width  { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on color  { ColorAnimation  { duration: 180 } }
        }

        Icon {
            anchors.centerIn: parent
            name: tab.iconName
            size: tab.active ? 20 : 16
            tone: tab.active ? "gray" : "dark"
            Behavior on size { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.clicked()
        }
    }

    Item {
        id: tabNav
        visible: root.open
        z: 10
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: root.navHeight
        width: root.navWidth

        Rectangle {
            id: tabBg
            anchors.fill: parent
            radius: height / 2
            color: Theme.track
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.leftMargin: root.navPad
            anchors.rightMargin: root.navPad
            anchors.topMargin: root.navPad
            anchors.bottomMargin: root.navPad
            contentWidth: navRow.implicitWidth
            contentHeight: navRow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: navRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.navItemGap

                Repeater {
                    model: root.tabs
                    delegate: TabButton {
                        required property string modelData
                        iconName: root.tabIcons[modelData] || "home"
                        active: root.page === modelData
                        onClicked: root.enterTab(modelData)
                    }
                }
            }
        }

        MouseArea {
            id: wheelArea
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: w => {
                if (w.angleDelta.y > 0) root.cyclePage(-1)
                else if (w.angleDelta.y < 0) root.cyclePage(1)
                w.accepted = true
            }
        }
    }
}