// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"
import "../../Services"

// Portapapeles dentro de la isla: fijados arriba, historial debajo.
// Clic en un elemento: lo copia y cierra la isla (pegar con Ctrl+V).
Item {
    id: root
    signal back()
    signal done()
    signal picked()
    property bool armed: false        // "Borrar" pide un segundo clic
    implicitHeight: col.implicitHeight

    // Индекс выбранного элемента в объединённом списке: [pins..., history...]
    property int currentIndex: 0

    // Плоский список для навигации: сначала закреплённые, потом история.
    readonly property var navItems: {
        const out = []
        for (const p of Clipboard.pins)
            out.push({ kind: "pin", data: p })
        for (const h of root.history)
            out.push({ kind: "history", data: h })
        return out
    }

    function refresh() { armed = false; currentIndex = 0; Clipboard.refresh() }
    readonly property var history: Clipboard.items.filter(i => i.binary || !Clipboard.isPinned(i.text))

    // ───────── Навигация с клавиатуры ─────────
    function moveSelection(delta) {
        const n = root.navItems.length
        if (n === 0)
            return
        currentIndex = (currentIndex + delta + n) % n
        Qt.callLater(root.ensureVisible)
    }

    function activateCurrent() {
        const item = root.navItems[root.currentIndex]
        if (!item)
            return
        if (item.kind === "pin")
            Clipboard.copyText(item.data)
        else
            Clipboard.copy(item.data)
        root.picked()
    }

    function removeCurrent() {
        const item = root.navItems[root.currentIndex]
        if (!item || item.kind !== "history")
            return
        Clipboard.remove(item.data)
        const n = root.navItems.length
        if (n > 0 && currentIndex >= n)
            currentIndex = n - 1
    }

    function ensureVisible() {
        if (!flick || flick.contentHeight <= flick.height)
            return
        const item = list.children[root.currentIndex]
        if (!item)
            return
        const top = item.y
        const bottom = item.y + item.height
        if (top < flick.contentY)
            flick.contentY = top
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height
    }

    // ───────── Фокус ─────────
    // Фокус ставим на flick, чтобы клавиши точно доходили до нас и не
    // перехватывались IslandMenu / pill.
    focus: enabled

    function requestKeyboardFocus() {
        Qt.callLater(function() {
            if (root.enabled && root.visible)
                flick.forceActiveFocus()
        })
        refocusTimer.restart()
    }

    Timer {
        id: refocusTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.enabled && root.visible && !flick.activeFocus)
                flick.forceActiveFocus()
        }
    }

    onEnabledChanged: if (enabled) requestKeyboardFocus()
    Component.onCompleted: requestKeyboardFocus()

    // Esc закрывает островок целиком (done), а кнопка «назад» возвращает в меню (back).
    Keys.onEscapePressed: event => {
        event.accepted = true
        root.done()
    }

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Item {
            width: parent.width; height: 32
            Rectangle {
                width: 32; height: 32; radius: 16
                color: bm.containsMouse ? Theme.hover : Theme.surface
                Icon { anchors.centerIn: parent; name: "back"; size: 18 }
                MouseArea {
                    id: bm; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    focus: false
                    onClicked: { flick.forceActiveFocus(); root.back() }
                }
            }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Clipboard")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                visible: Clipboard.items.length > 0
                width: cl.implicitWidth + 24; height: 32; radius: 16
                color: root.armed ? Theme.fill : (cm.containsMouse ? Theme.hover : Theme.surface)
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Text { id: cl; anchors.centerIn: parent; text: root.armed ? I18n.tr("Confirm") : I18n.tr("Clear clipboard"); color: root.armed ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: root.armed ? Font.DemiBold : Font.Normal }
                MouseArea {
                    id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    focus: false
                    onClicked: {
                        flick.forceActiveFocus()
                        if (!root.armed) { root.armed = true; disarm.restart() } else { root.armed = false; Clipboard.clear() }
                    }
                }
            }
        }

        Flickable {
            id: flick
            width: parent.width
            height: Math.min(list.implicitHeight, 420)
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            // Клавиши ловим здесь, а не на root: flick — реальный получатель фокуса.
            focus: true

            Keys.onEscapePressed: event => {
                event.accepted = true
                root.done()
            }
            Keys.onUpPressed:     event => { event.accepted = true; root.moveSelection(-1) }
            Keys.onDownPressed:   event => { event.accepted = true; root.moveSelection(1)  }
            Keys.onLeftPressed:   event => { event.accepted = true; root.moveSelection(-1) }
            Keys.onRightPressed:  event => { event.accepted = true; root.moveSelection(1)  }
            Keys.onReturnPressed: event => { event.accepted = true; root.activateCurrent() }
            Keys.onEnterPressed:  event => { event.accepted = true; root.activateCurrent() }
            Keys.onDeletePressed: event => { event.accepted = true; root.removeCurrent() }

            Column {
                id: list
                width: flick.width
                spacing: 2

                Text {
                    visible: Clipboard.pins.length > 0
                    leftPadding: 14; bottomPadding: 2
                    text: I18n.tr("Pinned items"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                Repeater {
                    model: Clipboard.pins
                    delegate: ClipRow {
                        required property string modelData
                        required property int index
                        width: list.width
                        text: modelData
                        pinned: true
                        removable: false
                        active: index === root.currentIndex
                        onPicked: { root.currentIndex = index; Clipboard.copyText(modelData); root.picked() }
                        onPinToggled: Clipboard.unpin(modelData)
                    }
                }
                Item { visible: Clipboard.pins.length > 0 && root.history.length > 0; width: 1; height: 8 }
                Text {
                    visible: Clipboard.pins.length > 0 && root.history.length > 0
                    leftPadding: 14; bottomPadding: 2
                    text: I18n.tr("Recent"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                Repeater {
                    model: root.history
                    delegate: ClipRow {
                        required property var modelData
                        required property int index
                        width: list.width
                        text: modelData.text
                        binary: modelData.binary
                        active: (Clipboard.pins.length + index) === root.currentIndex
                        onPicked: { root.currentIndex = Clipboard.pins.length + index; Clipboard.copy(modelData); root.picked() }
                        onPinToggled: Clipboard.pin(modelData)
                        onRemoveRequested: Clipboard.remove(modelData)
                    }
                }
            }
        }

        Text {
            visible: Clipboard.pins.length === 0 && root.history.length === 0
            width: parent.width
            topPadding: 18; bottomPadding: 18
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Clipboard.available ? I18n.tr("What you copy shows up here.") : I18n.tr("cliphist is needed to keep the history.")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
        }
    }
}