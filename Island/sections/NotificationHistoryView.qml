// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// История уведомлений: новые записи сверху, нажатие раскрывает полный текст.
Item {
    id: root
    signal back()
    signal done()
    property int expandedIndex: -1
    property bool armed: false
    implicitHeight: col.implicitHeight

    function reset() { expandedIndex = -1; armed = false }
    function removeAt(index) {
        const item = Notifs.history[index]
        if (item) Notifs.removeHistory(item.id)
        if (expandedIndex >= Notifs.history.length) expandedIndex = -1
    }
    function moveSelection(delta) {
        const n = Notifs.history.length
        if (n === 0) return
        expandedIndex = (expandedIndex + delta + n) % n
        Qt.callLater(ensureVisible)
    }
    function ensureVisible() {
        if (flick.contentHeight <= flick.height) return
        const item = rows.children[expandedIndex]
        if (!item) return
        if (item.y < flick.contentY) flick.contentY = item.y
        else if (item.y + item.height > flick.contentY + flick.height)
            flick.contentY = item.y + item.height - flick.height
    }

    focus: enabled
    function requestFocus() {
        Qt.callLater(function() {
            if (root.enabled && root.visible) root.forceActiveFocus()
        })
    }
    onEnabledChanged: if (enabled) requestFocus()
    Component.onCompleted: requestFocus()

    Keys.onEscapePressed: event => { event.accepted = true; root.done() }
    Keys.onUpPressed: event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onDownPressed: event => { event.accepted = true; root.moveSelection(1) }
    Keys.onDeletePressed: event => { event.accepted = true; root.removeAt(root.expandedIndex) }
    Keys.onReturnPressed: event => {
        event.accepted = true
        if (Notifs.history.length > 0)
            root.expandedIndex = root.expandedIndex < 0 ? 0 : (root.expandedIndex + 1) % Notifs.history.length
    }
    Keys.onEnterPressed: event => {
        event.accepted = true
        if (Notifs.history.length > 0)
            root.expandedIndex = root.expandedIndex < 0 ? 0 : (root.expandedIndex + 1) % Notifs.history.length
    }

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 32
            Rectangle {
                width: 32; height: 32; radius: 16
                color: backMouse.containsMouse ? Theme.hover : Theme.surface
                Icon { anchors.centerIn: parent; name: "back"; size: 18 }
                MouseArea {
                    id: backMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; focus: false
                    onClicked: root.back()
                }
            }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Notifications")
                color: Theme.textPrimary; font.family: Theme.font
                font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                visible: Notifs.history.length > 0
                width: clearLabel.implicitWidth + 24; height: 32; radius: 16
                color: root.armed ? Theme.fill : (clearMouse.containsMouse ? Theme.hover : Theme.surface)
                Text {
                    id: clearLabel; anchors.centerIn: parent
                    text: root.armed ? I18n.tr("Confirm") : I18n.tr("Clear")
                    color: root.armed ? Theme.onAccent : Theme.textPrimary
                    font.family: Theme.font; font.pixelSize: 12
                }
                MouseArea {
                    id: clearMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; focus: false
                    onClicked: {
                        if (!root.armed) { root.armed = true; disarm.restart() }
                        else { root.armed = false; Notifs.clearHistory(); root.expandedIndex = -1 }
                    }
                }
            }
        }

        Flickable {
            id: flick
            width: parent.width
            height: Math.min(rows.implicitHeight, 420)
            contentHeight: rows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: rows
                width: flick.width
                spacing: 3

                Repeater {
                    model: Notifs.history
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: rows.width
                        radius: 12
                        color: (hover.containsMouse || root.expandedIndex === index) ? Theme.hover : "transparent"
                        implicitHeight: content.implicitHeight + 18

                        Column {
                            id: content
                            x: 14; y: 9
                            width: parent.width - 28
                            spacing: 5

                            Row {
                                width: parent.width
                                spacing: 7
                                Text {
                                    width: parent.width - appName.width - 8 - 32
                                    text: row.modelData.summary || I18n.tr("Notification")
                                    color: Theme.textPrimary; font.family: Theme.font
                                    font.pixelSize: 13; font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: appName
                                    width: Math.min(implicitWidth, parent.width * 0.35)
                                    text: row.modelData.appName || ""
                                    color: Theme.textSecondary; font.family: Theme.font
                                    font.pixelSize: 10; elide: Text.ElideRight
                                }
                            }
                            Text {
                                width: parent.width
                                visible: root.expandedIndex === row.index
                                text: row.modelData.body || I18n.tr("No additional text")
                                color: Theme.textSecondary; font.family: Theme.font
                                font.pixelSize: 12; wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                            Text {
                                width: parent.width
                                text: Qt.formatDateTime(new Date(row.modelData.received), "dd.MM.yyyy · HH:mm")
                                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 10
                            }
                        }

                        HoverHandler { id: hover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expandedIndex = root.expandedIndex === row.index ? -1 : row.index
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 5
                            anchors.top: parent.top; anchors.topMargin: 5
                            width: 26; height: 26; radius: 13
                            visible: hover.hovered
                            color: removeMouse.containsMouse ? Theme.field : "transparent"
                            Icon { anchors.centerIn: parent; name: "bell-x"; size: 14 }
                            MouseArea {
                                id: removeMouse; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeAt(row.index)
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: Notifs.history.length === 0
            width: parent.width; topPadding: 24; bottomPadding: 24
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("No notifications yet.")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
        }
    }
}
