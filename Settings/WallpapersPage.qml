// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"

// Fondos de pantalla: imágenes estáticas (galería + selector) y fondo animado.
Column {
    id: root
    spacing: 20
    signal pickerOpened()       // el selector de archivos necesita el teclado

    readonly property string mainDir: Quickshell.env("HOME") + "/Pictures/Wallpapers/Local"
    property var images: []

    function refresh() { scan.running = false; scan.running = true }
    Component.onCompleted: refresh()

    // Solo fondos reales: el actual, los elegidos antes y los que el usuario agregó a
    // ~/Pictures/Wallpapers/Local (sin los de ejemplo "minimo-*"). Se descartan archivos inexistentes.
    Process {
        id: scan
        property var found: []
        command: ["sh", "-c",
            'mkdir -p "$HOME/Pictures/Wallpapers/Local"; for f in "$@"; do [ -f "$f" ] && echo "$f" || echo "!$f"; done; ' +
            'for d in "$HOME/Pictures/Wallpapers/Local" "$HOME/Pictures/Wallpapers"; do [ -d "$d" ] && find "$d" -maxdepth 1 -type f ! -name "minimo-*" \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) | sort; done',
            "sh"].concat(DisplayState.wallpaper ? [DisplayState.wallpaper] : []).concat(DisplayState.wallpaperHistory)
        stdout: SplitParser { onRead: line => scan.found.push(line) }
        onStarted: found = []
        onExited: {
            const missing = found.filter(l => l.startsWith("!")).map(l => l.slice(1))
            const ok = found.filter(l => l !== "" && !l.startsWith("!"))
            root.images = ok.filter((p, i) => ok.indexOf(p) === i)
            if (missing.some(p => DisplayState.wallpaperHistory.indexOf(p) >= 0)) DisplayState.forgetWallpapers(missing)
        }
    }
    // Quitar un fondo: los de ~/Pictures/Wallpapers/Local van a la papelera (gio trash; si no está, se borran);
    // los de otras carpetas solo salen de la lista. Si era el actual, queda sin fondo.
    function remove(path, owned) {
        DisplayState.removeWallpaper(path)
        root.images = root.images.filter(p => p !== path)
        if (owned) { trash.command = ["sh", "-c", 'gio trash -- "$1" 2>/dev/null || rm -f -- "$1"', "sh", path]; trash.running = true }
    }
    Process { id: trash; onExited: root.refresh() }
    Process {
        id: picker
        command: ["zenity", "--file-selection", "--title=" + I18n.tr("Choose wallpaper"),
                  "--filename=" + root.mainDir + "/",
                  "--file-filter=" + I18n.tr("Images") + " | *.png *.jpg *.jpeg *.webp"]
        stdout: SplitParser { onRead: line => { if (line.trim() !== "") DisplayState.setWallpaper(line.trim()) } }
        onExited: root.refresh()
    }

    SectionTitle { text: I18n.tr("Wallpaper") }

    Grid {
        id: grid
        columns: 3
        spacing: 14
        width: parent.width
        readonly property real tileW: (width - spacing * (columns - 1)) / columns

        Repeater {
            model: root.images
            delegate: WallpaperTile {
                width: grid.tileW; height: Math.round(grid.tileW * 10 / 16)
                owned: path.startsWith(root.mainDir + "/")
                onPicked: DisplayState.setWallpaper(path)
                onRemoveRequested: root.remove(path, owned)
            }
        }
    }

    Row {
        spacing: 8
        PillButton { icon: "folder"; text: I18n.tr("Choose image…"); onClicked: if (!picker.running) { root.pickerOpened(); picker.running = true } }
        PillButton { text: I18n.tr("No wallpaper"); outlined: true; onClicked: DisplayState.setWallpaper("") }
    }

    LiveWallpaperCard { width: parent.width; onPickerOpened: root.pickerOpened() }
    Text { text: I18n.tr("Folder: ~/Pictures/Wallpapers/Local"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11 }

}
