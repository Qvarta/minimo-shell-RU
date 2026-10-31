// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Servidor de notificaciones de Minimo OS (org.freedesktop.Notifications).
// Las muestra de a una en la isla compacta, en cola (máx. 8), ~5 s cada una.
// Si la app de origen está enfocada, el aviso es más breve (2,5 s): ya la estás viendo.
// "No molestar": qs ipc call notifs dnd  (las críticas se muestran igual).
Singleton {
    id: root
    property var queue: []
    property var history: []             // [{ id, appName, summary, body, urgency, received }]
    property bool historyLoaded: false
    property var pendingHistory: []
    property int historySerial: 0
    readonly property string historyDir: Quickshell.env("HOME") + "/.config/minimo-os"
    readonly property int maxHistory: 100

    function record(n) {
        const entry = {
            id: String(Date.now()) + "-" + String(++historySerial),
            appName: n.appName || n.desktopEntry || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: Number(n.urgency),
            received: Date.now()
        }
        if (!historyLoaded) pendingHistory = pendingHistory.concat([entry])
        else {
            history = [entry].concat(history).slice(0, maxHistory)
            saveHistory()
        }
    }
    function saveHistory() {
        if (historyLoaded) historyFile.setText(JSON.stringify(history.slice(0, maxHistory)))
    }
    function removeHistory(id) {
        history = history.filter(item => item.id !== id)
        saveHistory()
    }
    function clearHistory() {
        history = []
        pendingHistory = []
        saveHistory()
    }

    Process {
        command: ["mkdir", "-p", root.historyDir]
        running: true
        onExited: historyFile.path = root.historyDir + "/notifications.json"
    }
    FileView {
        id: historyFile
        blockLoading: false
        printErrors: false
        atomicWrites: true
        onLoaded: {
            let saved = []
            try {
                const parsed = JSON.parse(text())
                if (Array.isArray(parsed)) saved = parsed.filter(item =>
                    item && typeof item.id === "string" &&
                    typeof item.summary === "string" && typeof item.received === "number")
            } catch (e) {}
            root.history = root.pendingHistory.concat(saved).slice(0, root.maxHistory)
            root.pendingHistory = []
            root.historyLoaded = true
            root.saveHistory()
        }
        onLoadFailed: {
            root.history = root.pendingHistory.slice(0, root.maxHistory)
            root.pendingHistory = []
            root.historyLoaded = true
            root.saveHistory()
        }
    }
    readonly property var current: queue.length > 0 ? queue[0] : null
    property bool dnd: false
    // Mouse encima de alguna isla (una por monitor): no corre el tiempo.
    property int hovers: 0
    readonly property bool paused: hovers > 0

    function keyOf(n) { return ((n.desktopEntry || n.appName || "") + "").toLowerCase() }
    // ¿La app de la notificación es la ventana enfocada? (Hyprland: toplevel activo;
    // niri: ventana enfocada según Services/Niri.qml).
    function focusedClass() {
        if (Compositor.isNiri && !Compositor.isHyprland) {
            const w = Niri.windows[Niri.focusedWindowIndex]
            return w ? ((w.appId || "") + "").toLowerCase() : ""
        }
        const t = Hyprland.activeToplevel
        return t && t.lastIpcObject ? ((t.lastIpcObject["class"] || "") + "").toLowerCase() : ""
    }
    function fromFocused(n) {
        const cls = focusedClass()
        const k = keyOf(n)
        return k !== "" && cls !== "" && (cls.includes(k) || k.includes(cls))
    }
    function iconOf(n) {
        if (!n) return ""
        if (n.image) return n.image
        const p = Quickshell.iconPath(n.appIcon || n.desktopEntry || "", true)
        if (p !== "") return p
        const e = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : DesktopEntries.heuristicLookup(n.appName || "")
        return e ? Quickshell.iconPath(e.icon, true) : ""
    }

    // Miniatura (p. ej. una captura): la imagen de la notificación si es un archivo/imagen propia
    // (hint image-path o image-data), no un icono de app.
    function thumbOf(n) {
        if (!n) return ""
        const h = n.hints || {}
        const p = h["image-path"] || h["image_path"] || ""
        if (typeof p === "string" && (p.startsWith("file://") || p.startsWith("/"))) return p.startsWith("/") ? "file://" + p : p
        return n.image && !n.appIcon && n.image !== "" ? n.image : ""
    }

    // Saca una notificación concreta de la cola. Nunca "la primera a ciegas": invocar una
    // acción puede cerrar la notificación (closed → filtro) antes de que volvamos acá, y
    // quitar queue[0] después se llevaría la siguiente sin mostrarla.
    function drop(n) { queue = queue.filter(x => x !== n) }
    // Cerrarla solo si sigue viva: si la app ya la cerró (p. ej. al invocar una acción),
    // dismiss() sobre un objeto destruido da "Cannot close destroyed notification".
    function finish(n) { const live = queue.indexOf(n) >= 0; drop(n); if (live) n.dismiss() }
    // Cierra la actual (el usuario la descartó o se venció el tiempo).
    function dismiss() { const n = current; if (n) finish(n) }
    // Clic en el aviso: abre la ruta indicada o invoca la acción "default", si existe.
    function activate() {
        const n = current
        if (!n) return
        const def = Array.from(n.actions || []).find(a => a.identifier === "default")
        const open = n.hints ? n.hints["x-minimo-open"] : ""
        if (typeof open === "string" && open.startsWith("/")) Quickshell.execDetached(["xdg-open", open])   // captura: abrirla
        else if (def) def.invoke()
        finish(n)
    }
    function invoke(action) { const n = current; action.invoke(); if (n) finish(n) }

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: false
        onNotification: n => {
            const critical = n.urgency === NotificationUrgency.Critical
            if (root.queue.indexOf(n) >= 0) return          // reemplazo de una ya en cola: se actualiza sola
            root.record(n)
            if (root.dnd && !critical) { n.expire(); return }
            n.tracked = true
            // Si la app cierra/reemplaza la notificación, sale de la cola.
            n.closed.connect(() => { root.queue = root.queue.filter(x => x !== n) })
            let q = root.queue.concat([n])
            while (q.length > 8) { const old = q.splice(1, 1)[0]; old.expire() }
            root.queue = q
        }
    }

    Timer {
        id: life
        interval: root.current ? (root.current.urgency === NotificationUrgency.Critical ? 9000
                                  : root.fromFocused(root.current) ? 2500 : 5000) : 5000
        running: root.current !== null && !root.paused
        onTriggered: { const n = root.current; if (n) { root.drop(n); n.expire() } }
    }
    onCurrentChanged: if (current) life.restart()

    IpcHandler {
        target: "notifs"
        function dnd(): string { root.dnd = !root.dnd; return root.dnd ? "no molestar: sí" : "no molestar: no" }
        function clear(): void { const q = root.queue; root.queue = []; q.forEach(n => n.dismiss()) }
    }
}
