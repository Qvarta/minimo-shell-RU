// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// Notas dentro de la isla: lista (título = primera línea) и editor.
// Se guardan solas (Notes, ~/.config/minimo-os/notes.json); "Eliminar" pide confirmación.
Item {
    id: root
    signal back()
    signal done()
    property string editing: ""        // id de la nota abierta ("" = lista)
    property bool armed: false
    implicitHeight: col.implicitHeight

    // Индекс выбранной заметки в списке (когда editing === "").
    property int currentIndex: 0

    function reset() { close(); currentIndex = 0; }
    function open(id) {
        armed = false
        const idx = Notes.notes.findIndex(n => n.id === id)
        if (idx >= 0)
            currentIndex = idx
        editing = id
        editor.text = Notes.get(id)?.text ?? ""
        editor.forceActiveFocus()
        editor.cursorPosition = editor.text.length
    }
    function close() { if (editing !== "") Notes.flush(); editing = ""; armed = false; editor.focus = false; root.forceActiveFocus() }
    function goBack() { if (editing !== "") close(); else root.back() }
    function stamp(ms) {
        const d = new Date(ms), now = new Date()
        return d.toDateString() === now.toDateString() ? Qt.formatTime(d, "HH:mm") : d.toLocaleDateString(I18n.locale, I18n.lang === "en" ? "MMM d" : "d MMM")
    }

    // ───────── Навигация с клавиатуры ─────────
    function moveSelection(delta) {
        if (root.editing !== "")
            return
        const n = Notes.notes.length
        if (n === 0)
            return
        currentIndex = (currentIndex + delta + n) % n
        Qt.callLater(root.ensureVisible)
    }

    function openCurrent() {
        if (root.editing !== "")
            return
        const n = Notes.notes.length
        if (n === 0)
            return
        if (currentIndex >= n)
            currentIndex = n - 1
        root.open(Notes.notes[currentIndex].id)
    }

    function removeCurrent() {
        if (root.editing === "")
            return
        const id = root.editing
        root.editing = ""
        root.armed = false
        Notes.remove(id)
        const n = Notes.notes.length
        if (n > 0 && currentIndex >= n)
            currentIndex = n - 1
        root.forceActiveFocus()
    }

    function ensureVisible() {
        if (!listFlick || listFlick.contentHeight <= listFlick.height)
            return
        const item = notesCol.children[root.currentIndex]
        if (!item)
            return
        const top = item.y
        const bottom = item.y + item.height
        if (top < listFlick.contentY)
            listFlick.contentY = top
        else if (bottom > listFlick.contentY + listFlick.height)
            listFlick.contentY = bottom - listFlick.height
    }

    // ───────── Фокус ─────────
    focus: enabled

    function requestKeyboardFocus() {
        Qt.callLater(function() {
            if (root.enabled && root.visible && root.editing === "")
                root.forceActiveFocus()
        })
        refocusTimer.restart()
    }

    Timer {
        id: refocusTimer
        interval: 200
        repeat: false
        onTriggered: {
            // Не отбираем фокус у редактора, пока он открыт.
            if (root.enabled && root.visible && !root.activeFocus && root.editing === "")
                root.forceActiveFocus()
        }
    }

    onEnabledChanged: if (enabled) requestKeyboardFocus()
    Component.onCompleted: {
        requestKeyboardFocus()
        if (currentIndex >= Notes.notes.length)
            currentIndex = Math.max(0, Notes.notes.length - 1)
    }

    // Esc: если открыт редактор — закрыть редактор (вернуться к списку),
    // иначе — закрыть островок целиком. Кнопка «назад» всегда ведёт в меню.
    Keys.onEscapePressed: event => {
        event.accepted = true
        if (root.editing !== "")
            root.close()
        else
            root.done()
    }
    Keys.onUpPressed:     event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onDownPressed:   event => { event.accepted = true; root.moveSelection(1)  }
    Keys.onLeftPressed:   event => { event.accepted = true; root.moveSelection(-1) }
    Keys.onRightPressed:  event => { event.accepted = true; root.moveSelection(1)  }
    Keys.onReturnPressed: event => { event.accepted = true; root.openCurrent() }
    Keys.onEnterPressed:  event => { event.accepted = true; root.openCurrent() }

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

    component RoundButton: Rectangle {
        id: rb
        property string icon
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

    Column {
        id: col
        width: parent.width
        spacing: 12

        Item {
            width: parent.width; height: 32
            RoundButton { icon: "back"; onClicked: root.goBack() }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Notes")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            RoundButton { anchors.right: parent.right; visible: root.editing === ""; icon: "plus"; onClicked: root.open(Notes.create()) }
            Rectangle {
                anchors.right: parent.right
                visible: root.editing !== ""
                width: dl.implicitWidth + 24; height: 32; radius: 16
                color: root.armed ? Theme.danger : (dm.containsMouse ? Theme.hover : Theme.surface)
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Text { id: dl; anchors.centerIn: parent; text: root.armed ? I18n.tr("Confirm") : I18n.tr("Delete"); color: root.armed ? "#FFFFFF" : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: root.armed ? Font.DemiBold : Font.Normal }
                MouseArea {
                    id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    focus: false
                    onClicked: {
                        if (!root.armed) { root.armed = true; disarm.restart(); return }
                        root.removeCurrent()
                    }
                }
            }
        }

        // Lista.
        Text {
            visible: root.editing === "" && Notes.notes.length === 0
            width: parent.width; topPadding: 24; bottomPadding: 24
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("No notes. Click + to write one.")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
        }
        Flickable {
            id: listFlick
            visible: root.editing === "" && Notes.notes.length > 0
            width: parent.width
            height: visible ? Math.min(list.implicitHeight, 380) : 0
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Rectangle {
                id: list
                width: parent.width; implicitHeight: notesCol.implicitHeight; radius: 18
                color: Theme.surface
                Column {
                    id: notesCol
                    width: parent.width
                    Repeater {
                        model: Notes.notes
                        delegate: Item {
                            id: nr
                            required property var modelData
                            required property int index
                            width: notesCol.width; height: 56
                            Rectangle {
                                anchors.fill: parent; anchors.margins: 4; radius: 14
                                color: (nm.containsMouse || nr.index === root.currentIndex) ? Theme.hover : "transparent"
                            }
                            Column {
                                x: 16; width: parent.width - 32 - when.implicitWidth - 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                    text: Notes.title(nr.modelData.text) || I18n.tr("New note")
                                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                    visible: text !== ""
                                    text: Notes.preview(nr.modelData.text)
                                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                                }
                            }
                            Text {
                                id: when
                                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                text: root.stamp(nr.modelData.updated)
                                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                            }
                            Rectangle { visible: nr.index < Notes.notes.length - 1; anchors.bottom: parent.bottom; x: 16; width: parent.width - 32; height: 1; color: Theme.track }
                            MouseArea {
                                id: nm; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                focus: false
                                onClicked: { root.currentIndex = nr.index; root.forceActiveFocus(); root.open(nr.modelData.id) }
                            }
                        }
                    }
                }
            }
        }

        // Editor (texto plano; se guarda solo).
        Rectangle {
            visible: root.editing !== ""
            width: parent.width; height: visible ? 300 : 0; radius: 18
            color: Theme.field
            Flickable {
                id: ef
                anchors.fill: parent; anchors.margins: 14
                contentHeight: editor.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: editor
                    width: ef.width
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    color: Theme.textPrimary; selectionColor: Theme.fill; selectedTextColor: Theme.onAccent
                    font.family: Theme.font; font.pixelSize: 14
                    onTextChanged: if (root.editing !== "" && activeFocus) Notes.edit(root.editing, text)
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < ef.contentY) ef.contentY = cursorRectangle.y
                        else if (cursorRectangle.y + cursorRectangle.height > ef.contentY + ef.height) ef.contentY = cursorRectangle.y + cursorRectangle.height - ef.height
                    }
                    // Esc внутри редактора закрывает редактор (возврат к списку).
                    Keys.onEscapePressed: event => {
                        event.accepted = true
                        root.close()
                    }
                }
                Text {
                    visible: editor.text === ""
                    text: I18n.tr("Write something…")
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 14
                }
            }
        }
    }
}