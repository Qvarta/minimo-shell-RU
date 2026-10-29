// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../Common"
import "../Common/confirm.js" as Confirm
import "../Services"

PanelWindow {
    id: win
    readonly property bool open: PowerState.open
    property real t: open ? 1 : 0
    Behavior on t { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

    visible: open || t > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "minimo-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    readonly property var commands: ({ reboot: "systemctl reboot", poweroff: "systemctl poweroff" })
    readonly property var logoutCommands: ({
        hyprland: "hyprctl dispatch 'hl.dsp.exit()'",
        niri: "niri msg action quit --skip-confirmation"
    })
    property var st: Confirm.initial()
    readonly property string armed: st.armed

    function press(id) {
        const r = Confirm.press(st, id, Date.now(), 3000, 2000)
        st = r.state
        if (r.state.armed !== "") disarm.restart()
        if (r.run !== "") {
            const cmd = r.run === "logout" ? (logoutCommands[Compositor.session] || "") : commands[r.run]
            if (cmd !== "") Quickshell.execDetached(["sh", "-c", cmd])
            PowerState.hide()
        }
    }
    function disarmAll() { disarm.stop(); st = Confirm.disarm(st) }
    Timer { id: disarm; interval: 3000; onTriggered: win.st = Confirm.disarm(win.st) }

    readonly property var buttons: [btnLogout, btnReboot, btnPoweroff]
    property int focusedIndex: 0
    function focusButton(i) {
        const n = buttons.length
        focusedIndex = ((i % n) + n) % n
        keys.forceActiveFocus()
    }
    function moveFocus(delta) { focusButton(focusedIndex + delta) }

    onOpenChanged: if (open) { disarmAll(); focusLater.restart() }
    Timer { id: focusLater; interval: 60; triggeredOnStart: true; repeat: true
        property int tries: 5
        onTriggered: {
            if (!win.open) { stop(); return }
            win.focusButton(win.focusedIndex)
            if (--tries <= 0) stop()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.05 * win.t)
        opacity: 0
        MouseArea { anchors.fill: parent; onPressed: PowerState.hide() }
    }

    Rectangle {
        id: shadowSrc
        x: card.x; y: card.y; width: card.width; height: card.height
        radius: card.radius; color: Theme.card
        opacity: win.t; scale: card.scale
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: Theme.shadow
            shadowBlur: 1.0; blurMax: 48; shadowVerticalOffset: 12; autoPaddingEnabled: true
        }
    }

    Rectangle {
        id: card
        width: 420
        height: col.implicitHeight + 32
        x: (win.width - width) / 2
        y: win.height * 0.28
        radius: 24
        color: Theme.card
        border.width: 2
        border.color: Theme.textSecondary
        opacity: win.t
        scale: 0.96 + 0.04 * win.t
        clip: true

        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: 16; y: 16
            width: parent.width - 32
            spacing: 18

            Row {
                id: btnRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                component BigButton: Item {
                    id: btn
                    property string icon
                    property string label
                    property bool armed: false
                    readonly property bool focused: win.focusedIndex === win.buttons.indexOf(btn)
                    signal activated()
                    width: 104; height: 112

                    Rectangle {
                        id: circle
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72; height: 72; radius: 36
                        color: (btn.armed || btn.focused) ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
                        scale: mouse.pressed ? 0.92 : 1
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        Icon { anchors.centerIn: parent; name: btn.icon; size: 32; tone: (btn.armed || btn.focused) ? "white" : "dark" }
                    }
                    Text {
                        anchors.top: circle.bottom; anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: btn.width - 4
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: btn.armed ? I18n.tr("Confirm") : btn.label
                        color: (btn.armed || btn.focused) ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.font; font.pixelSize: 13; font.weight: (btn.armed || btn.focused) ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: circle
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.activated()
                    }
                }

                BigButton { id: btnLogout;   icon: "logout";  label: I18n.tr("Log out");   armed: win.armed === "logout";   onActivated: win.press("logout") }
                BigButton { id: btnReboot;   icon: "restart"; label: I18n.tr("Restart");   armed: win.armed === "reboot";   onActivated: win.press("reboot") }
                BigButton { id: btnPoweroff; icon: "power";   label: I18n.tr("Shut down"); armed: win.armed === "poweroff"; onActivated: win.press("poweroff") }
            }
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: PowerState.hide()
        Keys.onLeftPressed:  (event) => { event.accepted = true; win.moveFocus(-1) }
        Keys.onUpPressed:    (event) => { event.accepted = true; win.moveFocus(-1) }
        Keys.onRightPressed: (event) => { event.accepted = true; win.moveFocus(1) }
        Keys.onDownPressed:  (event) => { event.accepted = true; win.moveFocus(1) }
        Keys.onTabPressed:   (event) => { event.accepted = true; win.moveFocus((event.modifiers & Qt.ShiftModifier) ? -1 : 1) }
        Keys.onBacktabPressed: (event) => { event.accepted = true; win.moveFocus(-1) }
        Keys.onReturnPressed: (event) => { event.accepted = true; win.buttons[win.focusedIndex].activated() }
        Keys.onEnterPressed:  (event) => { event.accepted = true; win.buttons[win.focusedIndex].activated() }
        Keys.onSpacePressed:  (event) => { event.accepted = true; win.buttons[win.focusedIndex].activated() }
    }
}