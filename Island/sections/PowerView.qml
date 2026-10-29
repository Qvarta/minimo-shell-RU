// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import "../../Common/confirm.js" as Confirm
import "../../Services"

// Вкладка питания внутри островка (реализация перенесена из Power/PowerWindow.qml):
// выход из сессии, перезагрузка и выключение с подтверждением повторным нажатием.
// Управление с клавиатуры — как в QuickActionsView.qml / NotesView.qml:
// стрелки/Tab меняют выбор, Enter/Space нажимает выбранный элемент, Esc закрывает островок.
Item {
    id: root
    signal back()
    signal done()

    implicitHeight: col.implicitHeight

    readonly property var commands: ({ reboot: "systemctl reboot", poweroff: "systemctl poweroff" })
    readonly property var logoutCommands: ({
        hyprland: "hyprctl dispatch 'hl.dsp.exit()'",
        niri: "niri msg action quit --skip-confirmation"
    })

    readonly property var items: [
        { id: "logout",   label: I18n.tr("Log out"),   icon: "logout" },
        { id: "reboot",   label: I18n.tr("Restart"),   icon: "restart" },
        { id: "poweroff", label: I18n.tr("Shut down"), icon: "power" },
    ]
    readonly property var buttons: ["logout", "reboot", "poweroff"]
    property int currentIndex: 0

    // Машина состояний подтверждения (Common/confirm.js): первое нажатие «взводит»
    // кнопку, второе в пределах armMs выполняет действие.
    property var st: Confirm.initial()
    readonly property string armed: st.armed

    function press(id) {
        const r = Confirm.press(st, id, Date.now(), 3000, 2000)
        st = r.state
        if (r.state.armed !== "")
            disarm.restart()
        if (r.run !== "") {
            const cmd = r.run === "logout" ? (logoutCommands[Compositor.session] || "") : commands[r.run]
            if (cmd !== "")
                Quickshell.execDetached(["sh", "-c", cmd])
            root.done()
        }
    }
    function disarmAll() {
        disarm.stop()
        st = Confirm.disarm(st)
    }
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.st = Confirm.disarm(root.st)
    }

    function reset() {
        disarmAll()
        currentIndex = 0
    }

    function activate(id) {
        for (let i = 0; i < items.length; ++i) {
            if (items[i].id === id) {
                currentIndex = i
                press(id)
                return
            }
        }
    }

    function moveSelection(delta) {
        const n = buttons.length
        if (n === 0)
            return
        currentIndex = ((currentIndex + delta) % n + n) % n
    }

    // ───────── Фокус (как в QuickActionsView) ─────────
    // IslandMenu передаёт вкладке enabled; забираем фокус при активации страницы,
    // чтобы стрелки/Enter доходили до нас (unfocusLater в Island.qml отбирает фокус
    // через 150 мс — повторная попытка возвращает его).
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

    // ───────── Клавиатура ─────────
    // Esc закрывает островок целиком (done), кнопка «назад» возвращает в меню (back).
    Keys.onEscapePressed: event => {
        event.accepted = true
        root.disarmAll()
        root.done()
    }
    Keys.onUpPressed:    event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onDownPressed:  event => { event.accepted = true; root.moveSelection(1) }
    Keys.onLeftPressed:  event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onRightPressed: event => { event.accepted = true; root.moveSelection(1) }
    Keys.onTabPressed: event => {
        event.accepted = true
        root.moveSelection((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
    }
    Keys.onBacktabPressed: event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onReturnPressed: event => {
        event.accepted = true
        root.activate(buttons[currentIndex])
    }
    Keys.onEnterPressed: event => {
        event.accepted = true
        root.activate(buttons[currentIndex])
    }
    Keys.onSpacePressed: event => {
        event.accepted = true
        root.activate(buttons[currentIndex])
    }

    component RoundButton: Rectangle {
        id: rb
        required property string icon
        signal clicked()
        width: 32; height: 32; radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18 }
        MouseArea {
            id: rbm; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            focus: false
            onClicked: { root.forceActiveFocus(); rb.clicked() }
        }
    }

    component PowerButton: Item {
        id: pb
        required property int index
        required property var modelData
        delegate: PowerButton {
            onActivated: root.press(item.id)
        }
        readonly property bool isArmed: root.armed === item.id

        implicitWidth: 96
        implicitHeight: 104
        width: implicitWidth
        height: implicitHeight

        Rectangle {
            id: circle
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72; height: 72; radius: 36
            color: (pb.isArmed || pb.selected) ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
            scale: mouse.pressed ? 0.92 : 1
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            Icon {
                anchors.centerIn: parent
                name: pb.item.icon
                size: 32
                tone: (pb.isArmed || pb.selected) ? "white" : "dark"
            }
        }
        Text {
            anchors.top: circle.bottom; anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: pb.width - 4
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: pb.isArmed ? I18n.tr("Confirm") : pb.item.label
            color: (pb.isArmed || pb.selected) ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: 13
            font.weight: (pb.isArmed || pb.selected) ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            focus: false
            onClicked: {
                root.currentIndex = pb.index
                root.forceActiveFocus()
                root.press(pb.item.id)
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 18

        Item {
            width: parent.width; height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Power")
                color: Theme.textPrimary; font.family: Theme.font
                font.pixelSize: 15; font.weight: Font.DemiBold
            }
        }

        Row {
            id: btnRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Repeater {
                model: root.items
                delegate: PowerButton { }
            }
        }
    }
}
