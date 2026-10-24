// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS

import QtQuick
import "../Common"

// Горизонтальная кнопка закреплённого действия: иконка слева, подпись справа.
// Цвета и состояния повторяют MenuButton.
Item {
    id: btn

    property string icon
    property string label
    property string letter: ""
    property bool active: false

    signal activated()

    implicitWidth: 220
    implicitHeight: 52
    width: implicitWidth
    height: implicitHeight
    activeFocusOnTab: true

    Keys.onReturnPressed: mouse.fire()
    Keys.onSpacePressed: mouse.fire()

    Rectangle {
        id: background
        anchors.fill: parent
        radius: 14
        color: btn.active ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
        scale: mouse.pressed ? 0.98 : 1

        Behavior on color {
            ColorAnimation { duration: Theme.durFast }
        }
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: Theme.fill
            visible: btn.activeFocus
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 17
            color: btn.active ? Theme.fill : Theme.hover

            Icon {
                anchors.centerIn: parent
                name: btn.icon
                visible: btn.letter === ""
                size: 19
                tone: btn.active ? "white" : "dark"
            }

            Text {
                anchors.centerIn: parent
                visible: btn.letter !== ""
                text: btn.letter
                color: btn.active ? Theme.onAccent : Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.Medium
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 56
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: btn.label
            color: btn.active ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: btn.active ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function fire() {
            btn.activated()
        }
        onClicked: fire()
    }
}
