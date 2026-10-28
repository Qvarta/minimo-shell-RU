// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import "../../Common/confirm.js" as Confirm
import "../../Services"
import ".."

// Panel de energía (como el del calendario): Cerrar sesión / Reiniciar / Apagar.
// Usa la misma máquina de estados de confirmación que ActionsSection
// (Common/confirm.js): primer clic arma ("Confirmar"), el segundo ejecuta; solo una
// puede estar armada y hay 2 s de guarda tras ejecutar. Íconos y lógica idénticos a
// los del menú de la isla, pero aquí los botones son más grandes (componente propio)
// y el encabezado lleva solo el título, sin botón "volver".
Item {
    id: root
    signal back()
    implicitHeight: col.implicitHeight

    // Tamaño de los botones de este panel (más grandes que los del menú).
    readonly property int btnW: 104
    readonly property int circleSize: 72

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

    // Botón grande propio de este panel: misma apariencia y estados que MenuButton
    // (hover, armado negro con "Confirmar", aro de foco), pero círculo e ícono más
    // grandes. No se usa MenuButton para no agrandar los botones del menú de la isla.
    component BigButton: Item {
        id: btn
        property string icon
        property string label
        property bool armed: false
        signal activated()
        width: root.btnW; height: 104
        activeFocusOnTab: true
        Keys.onReturnPressed: mouse.fire()
        Keys.onSpacePressed: mouse.fire()
        Rectangle {
            id: circle
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.circleSize; height: root.circleSize; radius: root.circleSize / 2
            color: btn.armed ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
            scale: mouse.pressed ? 0.92 : 1
            Rectangle {          // aro de foco por teclado (solo con foco)
                anchors.fill: parent; anchors.margins: -4; radius: width / 2
                color: "transparent"; border.width: 2; border.color: Theme.fill
                visible: btn.activeFocus
            }
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            Icon { anchors.centerIn: parent; name: btn.icon; size: 32; tone: btn.armed ? "white" : "dark" }
        }
        Text {
            anchors.top: circle.bottom; anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: btn.width - 4
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: btn.armed ? I18n.tr("Confirm") : btn.label
            color: btn.armed ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: 13; font.weight: btn.armed ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: mouse
            anchors.fill: circle
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function fire() { btn.activated() }
            onClicked: fire()
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        // Encabezado: solo el título centrado (sin botón "volver").
        Item {
            width: parent.width; height: 32
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Energy")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
        }

        // Los tres botones, con los mismos íconos y lógica que ActionsSection, en versión grande.
        Row {
            id: btnRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            BigButton { icon: "logout"; label: I18n.tr("Log out"); armed: root.armed === "logout"; onActivated: root.press("logout") }
            BigButton { icon: "restart"; label: I18n.tr("Restart"); armed: root.armed === "reboot"; onActivated: root.press("reboot") }
            BigButton { icon: "power"; label: I18n.tr("Shut down"); armed: root.armed === "poweroff"; onActivated: root.press("poweroff") }
        }

        // En pantallas chicas los 3 botones no entran en una fila: pasan a dos.
        Item {
            width: 1; height: 6
            Binding { target: btnRow; property: "spacing"; value: 24; when: btnRow.implicitWidth > col.width }
            Binding { target: btnRow; property: "width"; value: col.width; restoreMode: Binding.RestoreNone; when: btnRow.implicitWidth > col.width }
        }
    }
}
