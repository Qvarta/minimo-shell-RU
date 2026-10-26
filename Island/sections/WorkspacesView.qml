// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../Common"
import "../../Services"

// Vista de escritorios dentro de la isla: grilla de workspaces con los iconos
// de sus ventanas, el activo con contorno negro, y un "+" para uno nuevo.
Item {
    id: root
    signal back()
    signal picked()
    implicitHeight: col.implicitHeight

    readonly property bool isNiri: Compositor.isNiri && !Compositor.isHyprland

    function refresh() { if (!isNiri) { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces() } }

    // Icono de una ventana: toplevel de Hyprland u objeto de window de Niri (appId/title).
    function classOf(t) {
        if (t.wayland && t.wayland.appId) return t.wayland.appId
        if (t.appId) return t.appId
        if (t.lastIpcObject && t.lastIpcObject["class"]) return t.lastIpcObject["class"]
        return ""
    }
    // Ventanas a mostrar en cada tesela. En niri Workspaces.list usa idx como id,
    // así que se filtra por el workspace del objeto crudo (raw.id).
    function windowsFor(ws) {
        if (isNiri) return Niri.windows.filter(w => w.workspaceId === ws.raw.id).slice(0, 4)
        return ws.toplevels ? ws.toplevels.values.slice(0, 4) : []
    }

    function iconFor(t) {
        const cls = classOf(t)
        const e = cls ? DesktopEntries.heuristicLookup(cls) : null
        const p = Quickshell.iconPath(e ? e.icon : cls, true)
        return p !== "" ? p : Qt.resolvedUrl("../../assets/icons/src/apps.svg")
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        Item {
            width: parent.width; height: 32
            Rectangle {
                id: backBtn
                width: 32; height: 32; radius: 16
                color: backMouse.containsMouse ? Theme.hover : Theme.surface
                Icon { anchors.centerIn: parent; name: "back"; size: 18 }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
            }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Desktops")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
        }

        // Escritorios en una cuadrícula fija; al pulsar se cambia al escritorio.
        Item {
            id: grid
            readonly property int columns: 3
            readonly property int gap: 8
            readonly property int tileH: 76
            readonly property real tileW: (col.width - gap * (columns - 1)) / columns
            width: col.width
            height: Math.ceil((Workspaces.list.length + 1) / columns) * (tileH + gap) - gap
            function slotX(i) { return (i % columns) * (tileW + gap) }
            function slotY(i) { return Math.floor(i / columns) * (tileH + gap) }
            Repeater {
                model: Workspaces.list
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool active: modelData.id === Workspaces.activeId
                    readonly property int slot: index
                    width: grid.tileW; height: grid.tileH; radius: 14
                    x: grid.slotX(slot); y: grid.slotY(slot)
                    color: tileMouse.containsMouse ? Theme.hover : Theme.surface
                    border.width: active ? 2 : 0
                    border.color: Theme.textPrimary
                    Text {
                        x: 10; y: 8
                        text: tile.modelData.name || tile.modelData.id
                        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium
                    }
                    Row {
                        anchors.centerIn: parent; anchors.verticalCenterOffset: 6
                        spacing: 6
                        Repeater {
                            model: root.windowsFor(tile.modelData)
                            delegate: Image {
                                required property var modelData
                                width: 24; height: 24; sourceSize: Qt.size(48, 48)
                                source: root.iconFor(modelData)
                            }
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Workspaces.goTo(tile.modelData.id); root.picked() }
                    }
                }
            }
            Rectangle {
                x: grid.slotX(Workspaces.list.length); y: grid.slotY(Workspaces.list.length)
                width: grid.tileW; height: grid.tileH; radius: 14
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                color: "transparent"
                border.width: 1.5; border.color: plusMouse.containsMouse ? Theme.textSecondary : Theme.track
                Icon { anchors.centerIn: parent; name: "plus"; tone: "gray"; size: 22 }
                MouseArea {
                    id: plusMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Workspaces.goEmpty(); root.picked() }
                }
            }
        }
    }
}
