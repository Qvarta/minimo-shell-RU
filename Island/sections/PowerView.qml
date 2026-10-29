// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import "../../Common/confirm.js" as Confirm
import "../../Services"


Item {
    id: root
    signal back()
    signal done()

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
            root.done()
        }
    }
    function reset() { disarm.stop(); st = Confirm.disarm(st) }
    Timer { id: disarm; interval: 3000; onTriggered: root.st = Confirm.disarm(root.st) }

    // ───────── Навигация с клавиатуры ─────────
    readonly property var buttonIds: ["logout", "reboot", "poweroff"]
    property int currentIndex: 0

    function moveSelection(delta) {
        const n = buttonIds.length
        if (n === 0)
            return
        currentIndex = ((currentIndex + delta) % n + n) % n
    }

    function activateCurrent() {
        const id = buttonIds[currentIndex]
        if (id !== undefined)
            root.press(id)
    }

    focus: enabled

    function requestKeyboardFocus() {
        Qt.callLater(function() {
            if (root.enabled && root.visible)
                root.forceActiveFocus()
        })
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

    Keys.onEscapePressed: event => {
        event.accepted = true
        root.reset()
        root.done()
    }
    Keys.onUpPressed:    event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onDownPressed:  event => { event.accepted = true; root.moveSelection(1) }
    Keys.onLeftPressed:  event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onRightPressed: event => { event.accepted = true; root.moveSelection(1) }
    Keys.onTabPressed:   event => { event.accepted = true; root.moveSelection((event.modifiers & Qt.ShiftModifier) ? -1 : 1) }
    Keys.onBacktabPressed: event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onReturnPressed: event => { event.accepted = true; root.activateCurrent() }
    Keys.onEnterPressed:  event => { event.accepted = true; root.activateCurrent() }
    Keys.onSpacePressed:  event => { event.accepted = true; root.activateCurrent() }

    implicitHeight: 32 + 16 + 112

    component RoundButton: Rectangle {
        id: rb
        property string icon
        signal clicked()
        width: 32
        height: 32
        radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18 }
        MouseArea {
            id: rbm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            focus: false
            onClicked: {
                root.forceActiveFocus()
                rb.clicked()
            }
        }
    }

    component BigButton: Item {
        id: btn
        required property string bid
        required property int index
        property string icon
        property string label
        readonly property bool isArmed: root.armed === bid
        readonly property bool focused: index === root.currentIndex
        signal activated()
        width: 104; height: 112

        Rectangle {
            id: circle
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72; height: 72; radius: 36
            color: isArmed ? Theme.danger : (focused || mouse.containsMouse) ? Theme.fill : Theme.surface
            scale: mouse.pressed ? 0.92 : 1
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            Icon { anchors.centerIn: parent; name: btn.icon; size: 32; tone: (isArmed || focused) ? "white" : "dark" }
        }
        Text {
            anchors.top: circle.bottom; anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: btn.width - 4
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: isArmed ? I18n.tr("Confirm") : btn.label
            color: isArmed ? Theme.danger : (focused ? Theme.textPrimary : Theme.textSecondary)
            font.family: Theme.font; font.pixelSize: 13; font.weight: (isArmed || focused) ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: mouse
            anchors.fill: circle
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            focus: false
            onClicked: {
                root.currentIndex = btn.index
                root.forceActiveFocus()
                btn.activated()
            }
        }
        onActivated: root.press(bid)
    }

    Item {
        id: header
        width: parent.width
        height: 32
        anchors.top: parent.top

        RoundButton { icon: "back"; onClicked: { root.reset(); root.back() } }
        Text {
            anchors.centerIn: parent
            text: I18n.tr("Energy")
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
    }

    Item {
        id: btnArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Row {
            id: btnRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 20 
            spacing: 16

            BigButton { bid: "logout";   index: 0; icon: "logout";}
            BigButton { bid: "reboot";   index: 1; icon: "restart";}
            BigButton { bid: "poweroff"; index: 2; icon: "power";}
        }
    }
}