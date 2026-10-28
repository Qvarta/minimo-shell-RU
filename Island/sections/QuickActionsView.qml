// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import "../../Services"

// Панель быстрых действий (радио, снимок экрана, заметки, буфер обмена),
// открываемая из ActionsSection.
Item {
    id: root
    signal back()
    signal done()
    signal clipboard()
    signal notes()
    signal radio()

    readonly property var builtins: [
        { id: "radio", label: I18n.tr("Radio"), icon: "music" },
        { id: "capture", label: I18n.tr("Screenshot"), icon: "capture" },
        { id: "notes", label: I18n.tr("Notes"), icon: "note" },
        { id: "clipboard", label: I18n.tr("Clipboard"), icon: "clipboard" },
    ]
    readonly property var buttons: ["radio", "capture", "notes", "clipboard"]
    property int currentIndex: 0

    function moveSelection(delta) {
        if (buttons.length === 0)
            return
        currentIndex = (currentIndex + delta + buttons.length) % buttons.length
    }

    // IslandMenu may keep focus on its own root when switching pages.
    // Reclaim it whenever this page becomes visible/enabled, including first open.
    focus: enabled && visible

    function requestKeyboardFocus() {
        Qt.callLater(function() {
            if (root.enabled && root.visible)
                root.forceActiveFocus()
        })
    }

    onEnabledChanged: if (enabled) requestKeyboardFocus()
    onVisibleChanged: if (visible) requestKeyboardFocus()
    Component.onCompleted: requestKeyboardFocus()

    Keys.priority: Keys.BeforeItem
    Keys.onEscapePressed: event => {
        event.accepted = true
        root.back()
    }
    Keys.onUpPressed: event => { event.accepted = true; moveSelection(-1) }
    Keys.onDownPressed: event => { event.accepted = true; moveSelection(1) }
    Keys.onLeftPressed: event => { event.accepted = true; moveSelection(-1) }
    Keys.onRightPressed: event => { event.accepted = true; moveSelection(1) }
    Keys.onTabPressed: event => {
        event.accepted = true
        moveSelection((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
    }
    Keys.onBacktabPressed: event => { event.accepted = true; moveSelection(-1) }
    Keys.onReturnPressed: event => {
        event.accepted = true
        root.activate(root.buttons[root.currentIndex])
    }
    Keys.onEnterPressed: event => {
        event.accepted = true
        root.activate(root.buttons[root.currentIndex])
    }
    Keys.onSpacePressed: event => {
        event.accepted = true
        root.activate(root.buttons[root.currentIndex])
    }

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
        const t1 = I18n.tr("Screenshot saved");
        const t2 = I18n.tr("Copied to the clipboard");
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

    component ActionButton:
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

        Rectangle {
            id: background
            anchors.fill: parent
            radius: 14
            color: btn.active ? Theme.hover : (mouse.containsMouse ? Theme.hover : Theme.surface)
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
                border.color: Theme.hover
                visible: btn.activeFocus
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 20
                color: btn.active ? Theme.field : Theme.hover

                Icon {
                    anchors.centerIn: parent
                    name: btn.icon
                    size: 24
                    tone: "dark"
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
                text: I18n.tr("Quick actions")
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
                delegate: ActionButton {
                    id: b
                    required property int index
                    required property string modelData
                    readonly property var item: root.builtins.find(x => x.id === modelData)
                    icon: item ? item.icon : ""
                    label: item ? item.label : ""
                    active: index === root.currentIndex
                    onActivated: {
                        root.currentIndex = index
                        root.activate(b.modelData)
                    }
                }
            }
        }
    }
}
