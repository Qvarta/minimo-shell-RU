// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import "../Services"
import "i18n.js" as D

// Idioma de la interfaz (español / inglés / ruso). Uso: I18n.tr("English key", arg1, …).
// Como `tr` lee `lang`, los bindings se reevalúan solos al cambiar de idioma.
// El contenido del usuario (notas, nombres de accesos, títulos de ventanas…) no pasa por acá.
Singleton {
    id: root
    readonly property string lang: DisplayState.language
    readonly property var languages: D.languages
    readonly property var locale: Qt.locale(D.localeName(lang))

    function tr(s) { return D.translate(root.lang, s, Array.prototype.slice.call(arguments, 1)) }
    // "Jueves 15 de octubre" / "Thursday, October 15" / "четверг, 15 октября"
    function longDate(d) {
        const fmt = root.lang === "en" ? "dddd, MMMM d" : root.lang === "ru" ? "dddd, d MMMM" : "dddd d 'de' MMMM"
        const t = d.toLocaleDateString(root.locale, fmt)
        return t.charAt(0).toUpperCase() + t.slice(1)
    }
}
