// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Services"

// Workspaces de la sesión activa: Hyprland (socket IPC / dispatch Lua 0.56)
// o niri (Services/Niri.qml, socket NIRI_SOCKET). La UI usa siempre esta API.
Singleton {
    id: root
    readonly property bool isNiri: Compositor.isNiri && !Compositor.isHyprland

    // En niri los escritorios tienen id único e idx (posición); se expande idx
    // para que la UI (que ordena por id) respete el orden relativo de niri.
    // Causa del "Binding loop detected for property list": el binding de
    // "list" recorría el ListModel Niri.workspaces (count/get(i)/propiedades
    // de cada rollo) dentro de su propia expresión. Cada WorkspaceChanged del
    // EventStream de niri vaciaba y rellenaba ese modelo, Qt reevaluaba
    // "list" mientras aún se estaba aplicando la actualización anterior y
    // detectaba relanzamientos infinitos (una advertencia por evento).
    // Solución: los datos crudos se sincronizan DESDE FUERA del binding, en
    // el handler de señal onWorkspaceChanged (ciclo de eventos normal), y
    // "list" solo mapea un arreglo JS plano (`niriWsData`). No hay ninguna
    // dependencia del binding sobre sí mismo ni sobre el ListModel.
    // API visible sin cambios: id = idx ordenado, raw conserva el objeto.
    property var niriWsData: []       // [{id, idx, name, isOccupied, raw}, ...]

    function syncNiriWorkspaces() {
        const arr = []
        const count = Niri.workspaces.count
        for (let i = 0; i < count; i++) {
            const ws = Niri.workspaces.get(i)
            if (!ws) continue
            // Copia plana: ni "raw" ni ningún campo apuntan al rollo vivo del
            // ListModel, así "list" no depende de objetos mutables externos.
            arr.push({ id: ws.idx, idx: ws.idx, name: ws.name,
                       isOccupied: ws.isOccupied,
                       raw: { id: ws.id, idx: ws.idx, name: ws.name,
                              output: ws.output, isFocused: ws.isFocused,
                              isActive: ws.isActive, isUrgent: ws.isUrgent,
                              isOccupied: ws.isOccupied } })
        }
        arr.sort((a, b) => a.id - b.id)
        niriWsData = arr
    }

    Connections {
        target: Niri
        enabled: root.isNiri
        function onWorkspaceChanged() { root.syncNiriWorkspaces() }
    }

    // Sincronización inicial y por si la sesión es niri pero el singleton se
    // completó antes de que Compositor resolviera el compositor.
    Component.onCompleted: if (isNiri) syncNiriWorkspaces()
    onIsNiriChanged: if (isNiri) syncNiriWorkspaces()

    // IMPORTANTE: el acceso a "Hyprland.*" debe quedar DENTRO del ternario.
    // Si se evaluara aunque fuera una vez en niri, Quickshell intentaría
    // conectar al socket IPC y lanzaría el WARN "$HYPRLAND_INSTANCE_SIGNATURE
    // is unset. Cannot connect to hyprland." Los bindings solo registran la
    // dependencia de la rama que realmente se evalúa.
    readonly property var list: isNiri
        ? niriWsData
        : Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
    readonly property int activeId: isNiri
        ? (Niri.activeWorkspace ? Niri.activeWorkspace.idx : -1)
        : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1)
    property real lastSwitch: 0      // para el indicador de puntos
    property real lastWheel: 0

    function dispatchWs(target) {
        if (isNiri) {
            // En niri se navega por índice: "r±1" = relativo, número = absoluto.
            if (typeof target === "string" && target.startsWith("r")) {
                const cur = Niri.activeWorkspace ? Niri.activeWorkspace.idx : 1
                Niri.switchToWorkspace(cur + parseInt(target))
            } else {
                Niri.switchToWorkspace(target)
            }
            lastSwitch = Date.now()
            return
        }
        // Hyprland.dispatch() no entiende la sintaxis Lua: se usa hyprctl.
        Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({workspace=\"" + target + "\"})' >/dev/null 2>&1"])
        lastSwitch = Date.now()
    }
    // Una muesca de rueda = un workspace (con enfriamiento).
    function wheel(deltaY) {
        const now = Date.now()
        if (deltaY === 0 || now - lastWheel < 220) return
        lastWheel = now
        dispatchWs(deltaY > 0 ? "r-1" : "r+1")
    }
    function goTo(id) { dispatchWs(String(id)) }
    function goEmpty() { if (!isNiri) dispatchWs("emptynm") }
}