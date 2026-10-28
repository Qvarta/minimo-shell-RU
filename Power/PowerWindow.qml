// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../Common"
import "../Common/confirm.js" as Confirm
import "../Services"

// Panel de energía como ventana INDEPENDIENTE (igual que Launcher/Launcher.qml),
// ya no vive dentro de la isla. Al ser su propia capa layer-shell con
// WlrKeyboardFocus.Exclusive cuando está abierta, el compositor le entrega el
// foco de teclado de verdad — algo imposible dentro de Island, donde el Timer
// unfocusLater devolvía el foco a la píldora.
// Botones grandes: Cerrar sesión / Reiniciar / Apagar, con la misma máquina de
// confirmación que ActionsSection (Common/confirm.js): primer clic/Enter arma
// ("Confirmar"), segundo ejecuta; solo una armada a la vez y 2 s de guarda tras
// ejecutar. Clic fuera o Esc cierran. Flechas ← → ↑ ↓ y Tab/Shift+Tab mueven el
// foco entre los botones; Enter/Espacio dispara el enfocado.
// Abrir por IPC: qs -c minimo-shell ipc call power open|toggle|close
PanelWindow {
    id: win
    readonly property bool open: PowerState.open
    property real t: open ? 1 : 0          // progreso de la animación
    Behavior on t { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

    visible: open || t > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "minimo-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // --- Estado de las acciones (idéntico a ActionsSection.qml) --------------
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
            PowerState.hide()
        }
    }
    function disarmAll() { disarm.stop(); st = Confirm.disarm(st) }
    Timer { id: disarm; interval: 3000; onTriggered: win.st = Confirm.disarm(win.st) }

    // --- Foco de teclado ------------------------------------------------------
    // Los tres botones, en orden de navegación.
    readonly property var buttons: [btnLogout, btnReboot, btnPoweroff]
    property int focusedIndex: 0
    function focusButton(i) {
        const n = buttons.length
        focusedIndex = ((i % n) + n) % n
        buttons[focusedIndex].forceActiveFocus()
    }
    function moveFocus(delta) { focusButton(focusedIndex + delta) }

    // Cuando la ventana abre, el compositor le da foco exclusivo; lo colocamos
    // en un botón con un pequeño retardo (la ventana debe estar mapeada), igual
    // que el lanzador con su campo de búsqueda. Repetimos unas pocas veces para
    // ganar cualquier carrera con el repartidor de foco del compositor.
    onOpenChanged: if (open) { disarmAll(); focusLater.restart() }
    Timer { id: focusLater; interval: 60; triggeredOnStart: true; repeat: true
        property int tries: 5
        onTriggered: {
            if (!win.open) { stop(); return }
            win.focusButton(win.focusedIndex)
            if (--tries <= 0) stop()
        }
    }

    // Velo MUY sutil: solo decorativo (la opacidad no intercepta eventos), para que
    // un clic fuera de la tarjeta llegue al MouseArea de cierre. El lanzador usa el
    // mismo truco con 0.08; acá se baja a 0.05 porque esta capa cubre toda la pantalla.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.05 * win.t)
        opacity: 0
        MouseArea { anchors.fill: parent; onPressed: PowerState.hide() }
    }

    Rectangle {
        id: shadowSrc
        x: card.x; y: card.y; width: card.width; height: card.height
        radius: card.radius; color: Theme.card
        opacity: win.t; scale: card.scale
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: Theme.shadow
            shadowBlur: 1.0; blurMax: 48; shadowVerticalOffset: 12; autoPaddingEnabled: true
        }
    }

    Rectangle {
        id: card
        width: 420
        height: col.implicitHeight + 32
        x: (win.width - width) / 2
        y: win.height * 0.28
        radius: Math.min(height / 2, 32)
        color: Theme.card
        opacity: win.t
        scale: 0.96 + 0.04 * win.t
        clip: true

        // Bloquea el clic "afuera" dentro de la tarjeta (no cerrar al pulsar dentro).
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: 16; y: 16
            width: parent.width - 32
            spacing: 18

            // Encabezado: solo el título centrado (sin botón "volver").
            Item {
                width: parent.width; height: 30
                Text {
                    anchors.centerIn: parent
                    text: I18n.tr("Energy")
                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
                }
            }

            Row {
                id: btnRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                // Botón grande propio: mismos estados que MenuButton (hover, armado
                // negro con "Confirmar", aro de foco), pero círculo e ícono más grandes.
                component BigButton: Item {
                    id: btn
                    property string icon
                    property string label
                    property bool armed: false
                    signal activated()
                    width: 104; height: 112
                    activeFocusOnTab: true
                    Keys.onReturnPressed: mouse.fire()
                    Keys.onSpacePressed: mouse.fire()
                    Rectangle {
                        id: circle
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72; height: 72; radius: 36
                        color: btn.armed ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
                        scale: mouse.pressed ? 0.92 : 1
                        Rectangle {          // aro de foco por teclado
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
                        function fire() { btn.forceActiveFocus(); btn.activated() }
                        onClicked: fire()
                    }
                }

                BigButton { id: btnLogout;   icon: "logout";  label: I18n.tr("Log out");   armed: win.armed === "logout";   onActivated: win.press("logout") }
                BigButton { id: btnReboot;   icon: "restart"; label: I18n.tr("Restart");   armed: win.armed === "reboot";   onActivated: win.press("reboot") }
                BigButton { id: btnPoweroff; icon: "power";   label: I18n.tr("Shut down"); armed: win.armed === "poweroff"; onActivated: win.press("poweroff") }
            }
        }
    }

    // Navegación global de la ventana: Esc cierra; flechas/Tab mueven el foco.
    // Está en un ítem raíz enfocable para que funcione aunque el evento no lo
    // consuma el botón activo (las flechas no tienen handler en BigButton).
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: PowerState.hide()
        Keys.onLeftPressed:  { event.accepted = true; win.moveFocus(-1) }
        Keys.onUpPressed:    { event.accepted = true; win.moveFocus(-1) }
        Keys.onRightPressed: { event.accepted = true; win.moveFocus(1) }
        Keys.onDownPressed:  { event.accepted = true; win.moveFocus(1) }
        Keys.onTabPressed:     { event.accepted = true; win.moveFocus(!(event.modifiers & Qt.ShiftModifier) ? 1 : -1) }
        Keys.onBacktabPressed: { event.accepted = true; win.moveFocus(-1) }
    }
}
