// SPDX-License-Identifier: MIT
import QtQuick
import "../Common"

Item {
    id: root

    property var tabs: []
    property var tabIcons: ({})
    property string currentPage: ""
    signal tabSelected(string page)
    signal cycleRequested(int delta)

    readonly property int itemSize: 40
    readonly property int itemGap: 4
    readonly property int padding: 4

    component TabButton: Item {
        id: tab
        property string iconName: "home"
        property bool active: false
        signal clicked()

        width: root.itemSize
        height: root.itemSize

        Rectangle {
            anchors.centerIn: parent
            width: tab.active ? 40 : 32
            height: tab.active ? 40 : 32
            radius: height / 2
            color: tab.active
                   ? Theme.textPrimary
                   : (tabMouse.containsMouse ? Theme.hover : Theme.track)
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        Icon {
            anchors.centerIn: parent
            name: tab.iconName
            size: tab.active ? 20 : 16
            tone: tab.active ? "gray" : "dark"
            Behavior on size { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.clicked()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.card
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: root.padding
        contentWidth: navRow.implicitWidth
        contentHeight: navRow.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width

        Row {
            id: navRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.itemGap

            Repeater {
                model: root.tabs
                delegate: TabButton {
                    required property string modelData
                    iconName: root.tabIcons[modelData] || "home"
                    active: root.currentPage === modelData
                    onClicked: root.tabSelected(modelData)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) root.cycleRequested(-1)
            else if (wheel.angleDelta.y < 0) root.cycleRequested(1)
            wheel.accepted = true
        }
    }
}
