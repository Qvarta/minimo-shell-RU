// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Services"


// Estado persistente de la interfaz y del fondo de pantalla.
Singleton {
    id: root
    property bool loaded: false
    property string wallpaper: ""
    property var wallpaperHistory: []       // fondos elegidos (más reciente primero)
    property bool islandAutoHide: true      // ocultar la isla automáticamente
    property bool islandSmartHide: false    // ocultar solo si hay ventanas en el escritorio
    property bool characterAnimated: true   // personaje animado (si no, quieto)
    property string theme: "light"          // "light" | "dark"
    property int sleepMinutes: 1            // dormir tras inactividad (1, 2 o 5 min).
    // Idioma: el guardado; si no hay, el del sistema (LANG en… → inglés, ru… → ruso, si no español).
    property string language: { const l = Quickshell.env("LANG") || ""; return l.startsWith("en") ? "en" : l.startsWith("ru") ? "ru" : "es" }
    // Fondo animado (video o GIF con mpvpaper). Vacío = fondo estático.
    property string liveWallpaper: ""
    property bool livePauseCovered: true    // pausar si hay ventanas encima

    function setWallpaper(path) {
        wallpaper = path
        if (path !== "") wallpaperHistory = [path].concat(wallpaperHistory.filter(p => p !== path)).slice(0, 24)
        save()
    }
    // Quitar un fondo de la lista (y dejar de usarlo si era el actual).
    function removeWallpaper(path) {
        wallpaperHistory = wallpaperHistory.filter(p => p !== path)
        if (wallpaper === path) wallpaper = ""
        save()
    }
    function forgetWallpapers(missing) { wallpaperHistory = wallpaperHistory.filter(p => missing.indexOf(p) < 0); save() }
    function setIslandAutoHide(v) { islandAutoHide = v; if (v) islandSmartHide = false; save() }
    // Excluyentes: activar uno apaga el otro.
    function setIslandSmartHide(v) { islandSmartHide = v; if (v) islandAutoHide = false; save() }
    function setCharacterAnimated(v) { characterAnimated = v; save() }
    function setSleepMinutes(v) { sleepMinutes = v; save() }
    function setTheme(v) { theme = v; save() }
    function setLanguage(v) { language = (v === "en" || v === "ru") ? v : "es"; save() }
    function setLiveWallpaper(p) { liveWallpaper = p; save() }
    function setLivePauseCovered(v) { livePauseCovered = v; save() }
    // Empuja el tema al singleton Theme (sin dependencia inversa: evita init cíclico).
    onThemeChanged: Theme.dark = theme === "dark"
    function save() {
        // Merge settings into the existing state so Weather's city is never discarded.
        var state = {}
        if (file.loaded) {
            const raw = file.text()
            if (raw.trim() !== "") {
                try {
                    state = JSON.parse(raw)
                    if (!state || typeof state !== "object" || Array.isArray(state))
                        throw new Error("state.json root must be an object")
                } catch (e) {
                    console.error("DisplayState: refusing to overwrite invalid state.json:", e)
                    return
                }
            }
        }
        state.wallpaper = root.wallpaper
        state.wallpaperHistory = root.wallpaperHistory
        state.islandAutoHide = root.islandAutoHide
        state.islandSmartHide = root.islandSmartHide
        state.characterAnimated = root.characterAnimated
        state.sleepMinutes = root.sleepMinutes
        state.theme = root.theme
        state.language = root.language
        state.liveWallpaper = root.liveWallpaper
        state.livePauseCovered = root.livePauseCovered
        file.setText(JSON.stringify(state, null, 2))
    }

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/minimo-os"
    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
        onExited: file.path = root.stateDir + "/state.json"
    }

    FileView {
        id: file
        blockLoading: false
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text())
                root.wallpaper = s.wallpaper ?? ""
                root.wallpaperHistory = s.wallpaperHistory ?? (root.wallpaper ? [root.wallpaper] : [])
                root.islandAutoHide = s.islandAutoHide ?? true
                root.islandSmartHide = (s.islandSmartHide ?? false) && !root.islandAutoHide
                root.characterAnimated = s.characterAnimated ?? true
                root.sleepMinutes = s.sleepMinutes ?? 1
                root.theme = s.theme === "dark" ? "dark" : "light"
                if (s.language === "es" || s.language === "en" || s.language === "ru") root.language = s.language
                root.liveWallpaper = typeof s.liveWallpaper === "string" ? s.liveWallpaper : ""
                root.livePauseCovered = s.livePauseCovered ?? true
            } catch (e) {}
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
}
