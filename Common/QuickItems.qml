// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick

QtObject {
    readonly property var builtins: [
        { id: "capture", label: I18n.tr("Screenshot"), icon: "capture" },
        { id: "notes", label: I18n.tr("Notes"), icon: "note" },
        { id: "clipboard", label: I18n.tr("Clipboard"), icon: "clipboard" }
    ]
    readonly property var pinnedSliders: ["volume", "brightness"]
}
