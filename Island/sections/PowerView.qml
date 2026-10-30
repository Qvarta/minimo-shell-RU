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

    // ───────── Данные кнопок  ─────────
    readonly property var builtins: [
        { id: "logout",   label: I18n.tr("Logout"),    icon: "logout" },
        { id: "reboot",   label: I18n.tr("Reboot"),    icon: "restart" },
        { id: "poweroff", label: I18n.tr("Power off"), icon: "power" },
    ]
    readonly property var buttons: ["logout", "reboot", "poweroff"]
    property int currentIndex: 0

    function moveSelection(delta) {
        if (buttons.length === 0)
            return
        currentIndex = (currentIndex + delta + buttons.length) % buttons.length
    }

    function activateCurrent() {
        const id = buttons[currentIndex]
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
    Keys.onReturnPressed: event => { event.accepted = true; root.activateCurrent() }
    Keys.onEnterPressed:  event => { event.accepted = true; root.activateCurrent() }

    implicitHeight: col.implicitHeight

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

    component ActionButton: Item {
        id: btn

        property string bid
        property string icon
        property string label
        property bool active: false
        property bool armed: false

        signal activated()

        implicitWidth: 220
        implicitHeight: 52
        width: implicitWidth
        height: implicitHeight

        Rectangle {
            id: background
            anchors.fill: parent
            radius: 14
            color: btn.armed ? Theme.danger
                 : (btn.active || mouse.containsMouse) ? Theme.hover
                 : Theme.surface
            scale: mouse.pressed ? 0.98 : 1

            Behavior on color {
                ColorAnimation { duration: Theme.durFast }
            }
            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 20
                color: btn.armed ? Theme.danger
                     : (btn.active ? Theme.field : Theme.hover)

                Icon {
                    anchors.centerIn: parent
                    name: btn.icon
                    size: 24
                    tone: btn.armed ? "white" : "dark"
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 62
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: btn.armed ? I18n.tr("Confirm") : btn.label
                color: btn.armed ? Theme.textPrimary : (btn.active ? Theme.textPrimary : Theme.textSecondary)
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: (btn.armed || btn.active) ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            focus: false
            onClicked: {
                root.forceActiveFocus()
                btn.activated()
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        Item {
            width: parent.width
            height: 32
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

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.buttons.length > 0
            columns: 1
            rowSpacing: 4
            Repeater {
                id: actionRepeater
                model: root.buttons
                delegate: ActionButton {
                    id: b
                    required property int index
                    required property string modelData
                    readonly property var item: root.builtins.find(x => x.id === modelData)
                    bid: modelData
                    icon: item ? item.icon : ""
                    label: item ? item.label : ""
                    active: index === root.currentIndex
                    armed: root.armed === modelData
                    onActivated: {
                        root.currentIndex = index
                        root.press(b.modelData)
                    }
                }
            }
        }
    }
}