// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// Панель закреплённых действий, открываемая из ActionsSection.
Item {
    id: root
    signal back()
    signal done()
    signal desktops()
    signal clipboard()
    signal notes()
    readonly property var buttons: ["capture", "desktops", "notes", "clipboard"]
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
            onClicked: rb.clicked()
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        Item {
            width: parent.width
            height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Pinned")
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
        }

        PinnedSection {
            width: parent.width
            buttons: root.buttons
            onDone: root.done()
            onDesktops: root.desktops()
            onClipboard: root.clipboard()
            onNotes: root.notes()
        }
    }
}
