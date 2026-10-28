// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import "../../Common"
import "../../Common/confirm.js" as Confirm
import "../../Services"
import ".."

// Panel de energía (como el del calendario): Cerrar sesión / Reiniciar / Apagar.
// Usa la misma máquina de estados de confirmación que ActionsSection
// (Common/confirm.js): primer clic arma ("Confirmar"), el segundo ejecuta; solo una
// puede estar armada y hay 2 s de guarda tras ejecutar. Botones e íconos idénticos a
// los del menú de la isla, con el botón "volver" arriba como en las demás vistas.
Item {
    id: root
    signal back()
    implicitHeight: col.implicitHeight

    readonly property var commands: ({ reboot: "systemctl reboot", poweroff: "systemctl poweroff" })
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
            root.back()
        }
    }
    function reset() { disarm.stop(); st = Confirm.disarm(st) }
    Timer { id: disarm; interval: 3000; onTriggered: root.st = Confirm.disarm(root.st) }

    // Desarma las acciones al salir del panel (no queda ninguna armada).
    onVisibleChanged: if (!visible) reset()

    component RoundButton: Rectangle {
        id: rb
        property string icon
        signal clicked()
        width: 32; height: 32; radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18 }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        Item {
            width: parent.width; height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Energy")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
        }

        // Los tres botones, idénticos a los del menú de la isla (ActionsSection).
        Row {
            id: btnRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            MenuButton { icon: "logout"; label: I18n.tr("Log out"); armed: root.armed === "logout"; onActivated: root.press("logout") }
            MenuButton { icon: "restart"; label: I18n.tr("Restart"); armed: root.armed === "reboot"; onActivated: root.press("reboot") }
            MenuButton { icon: "power"; label: I18n.tr("Shut down"); armed: root.armed === "poweroff"; onActivated: root.press("poweroff") }
        }

        // En pantallas chicas los 3 botones no entran en una fila: pasan a dos.
        Item {
            width: 1; height: 6
            Binding { target: btnRow; property: "spacing"; value: 24; when: btnRow.implicitWidth > col.width }
            Binding { target: btnRow; property: "width"; value: col.width; restoreMode: Binding.RestoreNone; when: btnRow.implicitWidth > col.width }
        }
    }
}
