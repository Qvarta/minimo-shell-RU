// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import "../../Services"

// Панель закреплённых действий, открываемая из ActionsSection.
Item {
    id: root
    signal back()
    signal done()
    signal clipboard()
    signal notes()
    signal radio()
    // Встроенные закреплённые действия. Кнопка радио — локальное действие,
    // добавляется сверх builtins.
    readonly property var builtins: [
        { id: "capture", label: I18n.tr("Screenshot"), icon: "capture" },
        { id: "notes", label: I18n.tr("Notes"), icon: "note" },
        { id: "clipboard", label: I18n.tr("Clipboard"), icon: "clipboard" }
    ].concat([{ id: "radio", label: I18n.tr("Radio"), icon: "music" }])
    readonly property var buttons: ["capture", "notes", "clipboard", "radio"]
    implicitHeight: col.implicitHeight

    readonly property string screenshotDirAbs: (Quickshell.env("HOME") || "/tmp") + "/Pictures/Screenshots"

    function takeScreenshot(session) {
        const p = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root);

        const nameFormat = "screenshot-%Y-%m-%d_%H-%M-%S";
        if (session === "niri") {
            p.command = ["sh", "-c", "mkdir -p '" + root.screenshotDirAbs + "' && wayshot -g --silent --file-name-format '" + nameFormat + "' '" + root.screenshotDirAbs + "'"];
        } else {
            const script = 'd="$1"; mkdir -p "$d" || exit 1; ' + 'f="$d/$(date +\'' + nameFormat + '\').png"; ' + 'g=$(slurp) || exit 0; grim -g "$g" "$f" || exit 1; ' + '[ -s "$f" ] || exit 1; ' + 'wl-copy --type image/png < "$f"; ';
            p.command = ["sh", "-c", script, "screenshot", root.screenshotDirAbs];
        }

        p.running = true;
        p.exited.connect(function (exitCode) {
            p.destroy();
            if (exitCode === 0)
                root.notifyScreenshot();
        });
        root.done();
    }

    function notifyScreenshot() {
        const lang = DisplayState.language;
        const t1 = lang === "en" ? "Screenshot saved" : lang === "ru" ? "Снимок сохранён" : "Captura guardada";
        const t2 = lang === "en" ? "Copied to the clipboard" : lang === "ru" ? "Скопирован в буфер обмена" : "Copiada al portapapeles";
        // Последний созданный .png в каталоге снимков, экранированный для GVariant.
        const script = 'q=$(ls -t "$1"/*.png 2>/dev/null | head -n1); q=$(printf "%s" "$q" | sed "s/\x27/\\\\\x27/g"); ' + 'gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications ' + '--method org.freedesktop.Notifications.Notify "Screenshots" 0 "" "$2" "$3" "[]" ' + '"{\x27image-path\x27: <\x27file://$q\x27>, \x27x-minimo-open\x27: <\x27$q\x27>}" 4000 >/dev/null 2>&1 || true';
        Quickshell.execDetached(["sh", "-c", script, "notify", root.screenshotDirAbs, t1, t2]);
    }

    function activate(id) {
        if (id === "capture")
            root.takeScreenshot(Compositor.session);
        else if (id === "clipboard")
            root.clipboard();
        else if (id === "notes")
            root.notes();
        else if (id === "radio")
            root.radio();
    }

    component RoundButton: Rectangle {
        id: rb
        property string icon
        signal clicked()
        width: 32
        height: 32
        radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18 }
        MouseArea {
            id: rbm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.clicked()
        }
    }

    // Горизонтальная кнопка закреплённого действия: иконка слева, подпись справа.
    // Цвета и состояния повторяют MenuButton.
    component PinnedButton:
    Item {
        id: btn

        property string icon
        property string label
        property bool active: false

        signal activated()

        implicitWidth: 220
        implicitHeight: 52
        width: implicitWidth
        height: implicitHeight
        activeFocusOnTab: true

        Keys.onReturnPressed: mouse.fire()
        Keys.onSpacePressed: mouse.fire()

        Rectangle {
            id: background
            anchors.fill: parent
            radius: 14
            color: btn.active ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
            scale: mouse.pressed ? 0.98 : 1

            Behavior on color {
                ColorAnimation { duration: Theme.durFast }
            }
            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: Theme.fill
                visible: btn.activeFocus
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 20
                color: btn.active ? Theme.fill : Theme.hover

                Icon {
                    anchors.centerIn: parent
                    name: btn.icon
                    size: 24
                    tone: btn.active ? "white" : "dark"
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 62
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: btn.active ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: btn.active ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function fire() {
                btn.activated()
            }
            onClicked: fire()
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        Item {
            width: parent.width
            height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Pinned")
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
        }

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.buttons.length > 0
            columns: 1
            rowSpacing: 4
            Repeater {
                model: root.buttons
                delegate: PinnedButton {
                    id: b
                    required property string modelData
                    readonly property var item: root.builtins.find(x => x.id === modelData)
                    icon: item ? item.icon : ""
                    label: item ? item.label : ""
                    onActivated: root.activate(b.modelData)
                }
            }
        }
    }
}
