// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"
import "../../Widgets"
import "../../Services"


Column {
    id: root
    property bool active: false            // панель открыта: слушать изменения адаптера
    property bool expanded: false
    property int radius: 18                
    spacing: 6
    onActiveChanged: {
        Bluetooth.setWatch(active);
        if (!active) {
            expanded = false
            Bluetooth.error = ""
            Bluetooth.stopScan()
            scanTimeout.stop()
        }
    }
    Component.onDestruction: if (active) Bluetooth.setWatch(false)

    // Таймер авто-останова
    Timer {
        id: scanTimeout
        interval: 15000
        repeat: false
        onTriggered: Bluetooth.stopScan()
    }

    Rectangle {
        width: parent.width; height: 52; radius: root.radius
        color: rowMouse.containsMouse ? Theme.hover : Theme.surface
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            id: badge
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            color: Bluetooth.enabled ? Theme.fill : Theme.field
            Icon { anchors.centerIn: parent; name: "bluetooth"; size: 18; tone: Bluetooth.enabled ? "white" : "gray" }
        }
        Column {
            anchors.left: badge.right; anchors.leftMargin: 12
            anchors.right: sw.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; elide: Text.ElideRight; text: "Bluetooth"; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: !Bluetooth.available ? I18n.tr("No Bluetooth adapter")
                    : !Bluetooth.enabled ? I18n.tr("Off")
                    : Bluetooth.connectedName !== "" ? Bluetooth.connectedName
                    : Bluetooth.connectingPath !== "" ? I18n.tr("Connecting…")
                    : I18n.tr("Not connected")
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.expanded = !root.expanded
                if (root.expanded && Bluetooth.enabled) {
                    Bluetooth.scan()
                    scanTimeout.restart()
                } else {
                    scanTimeout.stop()
                }
            }
        }
        // Стопка подключённых (бейдж с количеством, как полоски сигнала в Wi-Fi).
        Rectangle {
            visible: Bluetooth.connectedCount > 0 && Bluetooth.enabled
            anchors.right: sw.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; radius: 11
            color: Theme.field
            Text { anchors.centerIn: parent; text: Bluetooth.connectedCount; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
        }
        MSwitch { id: sw; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: Bluetooth.enabled; enabled: Bluetooth.available; onToggled: v => Bluetooth.setEnabled(v) }
    }

    // Список устройств.
    Rectangle {
        width: parent.width
        visible: root.expanded && Bluetooth.enabled
        height: visible ? Math.min(listCol.implicitHeight + 12, 300) : 0
        radius: root.radius
        color: Theme.surface
        clip: true
        Flickable {
            anchors.fill: parent; anchors.margins: 6
            contentHeight: listCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: listCol
                width: parent.width
                Row {
                    visible: Bluetooth.discovering
                    x: 14; height: 28; spacing: 8
                    Icon { name: "bluetooth"; size: 13; tone: "gray"; anchors.verticalCenter: parent.verticalCenter }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Searching for devices…"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12 }
                }
                Text {
                    visible: Bluetooth.devices.length === 0 && !Bluetooth.discovering
                    x: 14; height: 36; verticalAlignment: Text.AlignVCenter
                    text: I18n.tr("No devices nearby"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                }
                Repeater {
                    model: Bluetooth.devices.slice(0, 15)
                    delegate: Rectangle {
                        id: dev
                        required property var modelData
                        width: listCol.width; height: 42; radius: 12
                        color: dm.containsMouse ? Theme.hover : "transparent"
                        Item {
                            id: iconBox
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 20; height: 20
                            Icon { anchors.centerIn: parent; name: "bluetooth"; size: 16; tone: dev.modelData.connected ? "dark" : "gray" }
                        }
                        Column {
                            anchors.left: iconBox.right; anchors.leftMargin: 10
                            anchors.right: actions.left; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: dev.modelData.name || dev.modelData.address
                                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                                font.weight: dev.modelData.connected ? Font.DemiBold : Font.Normal
                            }
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: !dev.modelData.paired ? I18n.tr("New device")
                                    : dev.modelData.connected ? I18n.tr("Connected") + (dev.modelData.battery >= 0 ? " · " + dev.modelData.battery + "%" : "")
                                    : dev.modelData.connecting ? I18n.tr("Connecting…")
                                    : I18n.tr("Paired")
                                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
                            }
                        }
                        Row {
                            id: actions
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Icon { name: "check"; size: 14; visible: dev.modelData.connected; anchors.verticalCenter: parent.verticalCenter }
                            // Батарея (краткий текст, без отдельной иконки BT).
                            Text {
                                visible: dev.modelData.connected && dev.modelData.battery >= 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: dev.modelData.battery + "%"
                                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
                            }
                            // Забыть (только спаренные): × при наведении мыши.
                            Rectangle {
                                visible: dm.containsMouse && dev.modelData.paired && !dev.modelData.connected
                                width: 22; height: 22; radius: 11
                                anchors.verticalCenter: parent.verticalCenter
                                color: forgetMouse.containsMouse ? Theme.track : "transparent"
                                Text { anchors.centerIn: parent; text: "×"; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 15 }
                                MouseArea {
                                    id: forgetMouse
                                    anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { dm.clickedFromChild = true; Bluetooth.forget(dev.modelData.path) }
                                }
                            }
                        }
                        MouseArea {
                            id: dm
                            property bool clickedFromChild: false
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (clickedFromChild) { clickedFromChild = false; return }
                                const d = dev.modelData
                                if (d.connected) Bluetooth.disconnect(d.path)
                                else if (d.connecting) return
                                else if (d.paired) Bluetooth.connect(d.path)
                                else {
                                    scanTimeout.stop()
                                    Bluetooth.stopScan()
                                    Bluetooth.pair(d.path)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        visible: Bluetooth.error !== "" && root.expanded
        x: 14
        text: Bluetooth.error
        color: Theme.danger; font.family: Theme.font; font.pixelSize: 12
    }
}