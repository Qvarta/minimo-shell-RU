// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import "../../Common"
import "../../Common/confirm.js" as Confirm
import "../../Services"
import ".."

// Energía. El botón de Ajustes vive en IslandMenu (esquina superior derecha).
// Cerrar sesión / Reiniciar / Apagar piden confirmación con UNA sola
// máquina de estados (Common/confirm.js): solo una puede estar armada; el segundo clic
// ejecuta una vez y los clics siguientes se ignoran durante 2 s.
Row {
    id: root
    signal done()

    readonly property var commands: ({
        reboot: "systemctl reboot",
        poweroff: "systemctl poweroff"
    })
    // logout depende del compositor: la sesión se lee de Services/Compositor.qml.
    readonly property var logoutCommands: ({
        hyprland: "hyprctl dispatch 'hl.dsp.exit()'",
        niri: "niri msg action quit --skip-confirmation"
    })
    property var st: Confirm.initial()
    readonly property string armed: st.armed

    function press(id) {
        const r = Confirm.press(st, id, Date.now(), 3000, 2000)
        st = r.state
        if (r.state.armed !== "") disarm.restart()
        if (r.run !== "") {
            const cmd = r.run === "logout" ? (logoutCommands[Compositor.session] || "") : commands[r.run]
            if (cmd !== "") Quickshell.execDetached(["sh", "-c", cmd])
            root.done()
        }
    }
    function reset() { disarm.stop(); st = Confirm.disarm(st) }
    Timer { id: disarm; interval: 3000; onTriggered: root.st = Confirm.disarm(root.st) }

    MenuButton { icon: "logout"; armed: root.armed === "logout"; onActivated: root.press("logout") }
    MenuButton { icon: "restart"; armed: root.armed === "reboot"; onActivated: root.press("reboot") }
    MenuButton { icon: "power"; armed: root.armed === "poweroff"; onActivated: root.press("poweroff") }
}
