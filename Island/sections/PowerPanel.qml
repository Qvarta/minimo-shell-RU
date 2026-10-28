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
// puede estar armada y hay 2 s de guarda tras ejecutar. Íconos y lógica idénticos a
// los del menú de la isla, pero aquí los botones son más grandes (componente propio)
// y el encabezado lleva solo el título, sin botón "volver".
// Navegación por teclado: al abrirse el panel (page === "power") la isla ya tiene
// foco exclusivo del compositor (WlrKeyboardFocus.Exclusive, ver Island.qml), así
// que aquí solo se captura el foco QML interno. IMPORTANTE: no basta con pedir el
// foco una vez al abrir — en Island.qml hay un Timer (unfocusLater, 150 ms) que, al
// expandir la isla, devuelve el foco a la píldora DESPUÉS de que esta ventana esté
// visible; eso "apagaba" el foco del panel justo después de tomarlo. Por eso el
// panel observa Window.activeFocusItem (el ítem realmente enfocado en la ventana):
// si el foco se va fuera del panel mientras está visible, lo recupera. Las flechas
// ← → ↑ ↓ y Tab/Shift+Tab mueven el foco entre los tres botones (envuelto) y
// Enter/Espacio disparan el enfocado. Esc vuelve al menú de la isla.
Item {
    id: root
    signal back()
    implicitHeight: col.implicitHeight

    // Índice del botón enfocado por teclado (-1 = ninguno aún).
    property int focusedIndex: -1

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

    // --- Foco de teclado -----------------------------------------------------
    // Los botones del panel (se recorren en orden con las flechas/Tab).
    readonly property var buttons: [btnLogout, btnReboot, btnPoweroff]
    // Mueve el foco interno entre botones: delta ±1 (lineal, envuelto).
    function moveFocus(delta) {
        const n = buttons.length
        const i = focusedIndex < 0 ? (delta > 0 ? 0 : n - 1)
                                   : (focusedIndex + delta + n) % n
        focusedIndex = i
        buttons[i].forceActiveFocus()
    }
    function focusButton(i) {
        focusedIndex = i
        buttons[i].forceActiveFocus()
    }
    // ¿El ítem enfocado de la ventana está dentro de este panel? (sube el árbol de
    // padres hasta root; Window.activeFocusItem puede ser un hijo profundo, p.ej. el
    // MouseArea no, pero sí el propio Item botón o cualquier descendiente).
    function containsFocusItem(item) {
        for (let it = item; it !== null; it = it.parent)
            if (it === root) return true
        return false
    }
    // Flechas: ← ↑ retroceden, → ↓ avanzan; Tab/Shift+Tab también. El handler está en
    // root (no en los botones): si la tecla no se consume aquí, Qt la propaga al padre
    // y termina rebotando el foco por Tab (saldría del panel hacia el buscador de la
    // isla); al consumirla siempre, el foco queda capturado dentro del panel.
    // RadioView usa el mismo patrón (Keys.on... sobre la raíz de la vista).
    function keyNav(event, forward) {
        event.accepted = true
        if (visible) moveFocus(forward ? 1 : -1)
    }

    // Ventana de la isla (WlrLayershell): su activeFocusItem es el ítem que tiene el
    // foco real. Lo usamos para "reclamar" el foco si otro lo toma mientras el panel
    // está visible — ver comentario arriba: unfocusLater en Island.qml devuelve el
    // foco a la píldora 150 ms después de expandir, justo cuando ya veíamos el panel.
    readonly property Window islandWindow: Window.window
    // El panel solo muestra el anillo de foco cuando de verdad tiene el foco activo
    // de la ventana (no solo porque Qt "le dio" focus internamente estando invisible).
    readonly property bool hasWinFocus: islandWindow !== null && containsFocusItem(islandWindow.activeFocusItem)
    // Reenfoca sin robar el foco si ya estaba aquí (evita bucles de señal).
    function reclaimFocus() {
        if (!visible || !islandWindow) return
        if (containsFocusItem(islandWindow.activeFocusItem)) return
        focusButton(focusedIndex < 0 ? 0 : focusedIndex)
    }
    Connections {
        target: root.islandWindow
        enabled: root.visible && root.islandWindow !== null
        function onActiveFocusItemChanged() { root.reclaimFocus() }
    }

    // Al abrirse el panel se intenta enfocar varias veces (cada 60 ms, ~8 intentos):
    // hay que ganar la carrera con unfocusLater (Island.qml), que devuelve el foco a
    // la píldora ~150 ms después de expandir la isla; además la opacidad animada hace
    // que `visible` se vuelva true recién unos frames después de cambiar de página.
    // Tras los reintentos, el Connections de arriba mantiene el foco capturado.
    onVisibleChanged: if (visible) {
        refocus.restart()
    } else {
        reset()
    }
    Timer { id: refocus; interval: 60; repeat: true; triggeredOnStart: true
        property int tries: 0
        onTriggered: {
            if (!root.visible) { stop(); return }
            root.reclaimFocus()
            if (++tries >= 8) stop()
        } }

    // Esc -> vuelve al menú de la isla (mismo gesto que cerrar con clic fuera).
    Keys.onEscapePressed: { event.accepted = true; root.back() }
    Keys.onLeftPressed: keyNav(event, false)
    Keys.onUpPressed: keyNav(event, false)
    Keys.onRightPressed: keyNav(event, true)
    Keys.onDownPressed: keyNav(event, true)
    Keys.onTabPressed: keyNav(event, !(event.modifiers & Qt.ShiftModifier))
    Keys.onBacktabPressed: keyNav(event, false)

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
        // No consume las flechas/Tab: la navegación se gestiona en root (Keys.on...),
        // que siempre acepta el evento, así el foco no escapa del panel por Tab.
        Keys.onReturnPressed: mouse.fire()
        Keys.onSpacePressed: mouse.fire()
        Rectangle {
            id: circle
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.circleSize; height: root.circleSize; radius: root.circleSize / 2
            color: btn.armed ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
            scale: mouse.pressed ? 0.92 : 1
            Rectangle {          // aro de foco por teclado (solo con foco real)
                anchors.fill: parent; anchors.margins: -4; radius: width / 2
                color: "transparent"; border.width: 2; border.color: Theme.fill
                visible: btn.activeFocus && root.hasWinFocus
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
            BigButton { id: btnLogout; icon: "logout"; label: I18n.tr("Log out"); armed: root.armed === "logout"; onActivated: root.press("logout") }
            BigButton { id: btnReboot; icon: "restart"; label: I18n.tr("Restart"); armed: root.armed === "reboot"; onActivated: root.press("reboot") }
            BigButton { id: btnPoweroff; icon: "power"; label: I18n.tr("Shut down"); armed: root.armed === "poweroff"; onActivated: root.press("poweroff") }
        }

        // En pantallas chicas los 3 botones no entran en una fila: pasan a dos.
        Item {
            width: 1; height: 6
            Binding { target: btnRow; property: "spacing"; value: 24; when: btnRow.implicitWidth > col.width }
            Binding { target: btnRow; property: "width"; value: col.width; restoreMode: Binding.RestoreNone; when: btnRow.implicitWidth > col.width }
        }
    }
}
