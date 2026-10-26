// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"

// Personalización: fondo de pantalla + opciones de la isla y del personaje.
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

    SectionTitle { text: I18n.tr("Appearance") }
    Rectangle {
        width: parent.width
        height: ap.implicitHeight
        radius: 20
        color: Theme.surface
        Column {
            id: ap
            width: parent.width
            Item {
                width: parent.width; height: 56
                Text { anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Appearance"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 184; height: 32; radius: 16; color: Theme.field
                    Row {
                        anchors.fill: parent; anchors.margins: 3
                        Repeater {
                            model: [{ id: "light", label: I18n.tr("Light") }, { id: "dark", label: I18n.tr("Dark") }]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool cur: DisplayState.theme === modelData.id
                                width: parent.width / 2; height: parent.height; radius: height / 2
                                color: cur ? Theme.fill : (thm.containsMouse ? Theme.hover : "transparent")
                                Text { anchors.centerIn: parent; text: modelData.label; color: parent.cur ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: parent.cur ? Font.DemiBold : Font.Normal }
                                MouseArea { id: thm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: DisplayState.setTheme(modelData.id) }
                            }
                        }
                    }
                }
            }
            Rectangle { x: 18; width: parent.width - 18; height: 1; color: Theme.track }
            // Idioma de la interfaz (los nombres van en su propio idioma).
            Item {
                width: parent.width; height: 56
                Text { anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Language"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 250; height: 32; radius: 16; color: Theme.field
                    Row {
                        anchors.fill: parent; anchors.margins: 3
                        Repeater {
                            model: I18n.languages
                            delegate: Rectangle {
                                id: lg
                                required property var modelData
                                readonly property bool cur: I18n.lang === modelData.id
                                width: parent.width / I18n.languages.length; height: parent.height; radius: height / 2
                                color: cur ? Theme.fill : (lgm.containsMouse ? Theme.hover : "transparent")
                                Text { anchors.centerIn: parent; text: lg.modelData.name; color: lg.cur ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: lg.cur ? Font.DemiBold : Font.Normal }
                                MouseArea { id: lgm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: DisplayState.setLanguage(lg.modelData.id) }
                            }
                        }
                    }
                }
            }
        }
    }

    SectionTitle { text: I18n.tr("Dynamic island") }
    Rectangle {
        width: parent.width
        height: opts.implicitHeight
        radius: 20
        color: Theme.surface
        Column {
            id: opts
            width: parent.width
            SwitchRow {
                width: parent.width
                text: I18n.tr("Hide the island automatically")
                detail: I18n.tr("Hides at the top and appears when you hover over it.")
                checked: DisplayState.islandAutoHide
                onToggled: v => DisplayState.setIslandAutoHide(v)
            }
            Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.track }
            SwitchRow {
                width: parent.width
                text: I18n.tr("Smart hide")
                detail: I18n.tr("Hides the island when an app is open on the desktop.")
                checked: DisplayState.islandSmartHide
                onToggled: v => DisplayState.setIslandSmartHide(v)
            }
            Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.track }
            SwitchRow {
                width: parent.width
                text: I18n.tr("Animated character")
                detail: I18n.tr("Follows the mouse, blinks, dances and falls asleep.")
                checked: DisplayState.characterAnimated
                onToggled: v => DisplayState.setCharacterAnimated(v)
            }
            Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.track }
            // Dormir tras inactividad (segmentado 1/2/5 min).
            Item {
                width: parent.width; height: 64
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: I18n.tr("Sleep after inactivity"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
                    Text { text: I18n.tr("No keyboard or mouse input anywhere on the PC."); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12 }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 168; height: 32; radius: 16; color: Theme.field
                    Row {
                        anchors.fill: parent; anchors.margins: 3
                        Repeater {
                            model: [1, 2, 5]
                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool cur: DisplayState.sleepMinutes === modelData
                                width: parent.width / 3; height: parent.height; radius: height / 2
                                color: cur ? Theme.fill : (zm.containsMouse ? Theme.hover : "transparent")
                                Text { anchors.centerIn: parent; text: I18n.tr("%1 min", modelData); color: parent.cur ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: parent.cur ? Font.DemiBold : Font.Normal }
                                MouseArea { id: zm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: DisplayState.setSleepMinutes(modelData) }
                            }
                        }
                    }
                }
            }
        }
    }

}
