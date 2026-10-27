import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen

    readonly property bool isBarVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"
    readonly property string displayMode: "auto"
    readonly property bool isPlaying: currentPlayingStation && currentPlayingStation !== ""

    property string currentIconName: pluginApi?.pluginSettings?.currentIconName || pluginApi?.manifest?.metadata?.defaultSettings?.currentIconName
    property string currentPlayingStation: pluginApi?.pluginSettings?.currentPlayingStation  || ""
    property string currentTrack: pluginApi?.pluginSettings?.currentTrack || ""
    property string currentArtist: pluginApi?.pluginSettings?.currentArtist || ""
    
    visible: isPlaying
    
    readonly property string displayText: {
        if (isPlaying) {
            if (currentTrack && currentTrack !== "") {
                if (currentArtist && currentArtist !== "") {
                    return currentPlayingStation + ": " + currentArtist + " • " + currentTrack;
                } else {
                    return currentTrack;
                }
            } else {
                return currentPlayingStation;
            }
        }
        return "";
    }

    implicitWidth: displayText === "" ? 32 + 16 : 200
    implicitHeight: 32

    anchors {
        fill: parent
        margins: 4
    }

    onCurrentPlayingStationChanged: {
        if (!currentPlayingStation || currentPlayingStation === "") {
            icon.rotation = 0;
        }
    }

    property real savedX: 0

    // Основной контейнер
    Row {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 8
        }
        spacing: 8
        layoutDirection: Qt.LeftToRight
        

        Item {
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter
            
            Rectangle {
                id: iconBackground
                anchors.fill: parent
                anchors.margins: 4
                radius: 16
                color: mouseArea.containsMouse ? Color.mHover : Color.mSurface
            }
            
            NIcon {
                id: icon
                anchors.centerIn: parent
                icon: root.currentIconName
                color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant
                
                pointSize: 14
                applyUiScale: true
                
                // Вращение иконки при проигрывании
                RotationAnimation on rotation {
                    id: rotationAnimation
                    running: root.isPlaying
                    from: 0
                    to: 360
                    duration: 3000
                    loops: Animation.Infinite
                    easing.type: Easing.Linear
                }
            }
        }
        
        // Контейнер для бегущей строки
        Item {
            id: textContainer
            width: parent.width - 32 - parent.spacing * 2
            height: parent.height
            clip: true
            anchors.verticalCenter: parent.verticalCenter
            
            NText {
                id: runningText
                property bool running: runningText.width > parent.width
                x: root.savedX
                text: root.displayText
                color: Color.mSecondary
                font.pointSize: Style.fontSizeXS + 2
                font.weight: Font.Medium
                // opacity: 0.8
                
                anchors.verticalCenter: parent.verticalCenter
                
                onTextChanged: {
                    root.savedX = 0;
                }
                
                onXChanged: {
                    if (scrollAnimation.running) {
                        root.savedX = x;
                    }
                }
                
                // Анимация бегущей строки
                NumberAnimation on x {
                    id: scrollAnimation
                    running: runningText.running
                    from: runningText.parent.width
                    to: -runningText.width
                    duration: Math.max(1000, (runningText.width + runningText.parent.width) * 30)
                    loops: Animation.Infinite
                    
                    // Сохраняем позицию при паузе/остановке
                    onRunningChanged: {
                        if (!running && runningText.running) {
                            root.savedX = runningText.x;
                        }
                    }
                }
                
                // Обновление при изменении размера
                Connections {
                    target: runningText
                    function onWidthChanged() {
                        if (scrollAnimation.running) {
                            scrollAnimation.restart();
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                pluginApi.openPanel(root.screen, this);
            } else if (mouse.button === Qt.RightButton) {
                var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
                if (popupMenuWindow) {
                    popupMenuWindow.showContextMenu(contextMenu);
                    contextMenu.openAtItem(root, screen);
                }
            }
        }
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
                        {
                "label": pluginApi?.tr("stop"),
                "action": "stop",
                "icon": "stop"
            },
            {
                "label": I18n.tr("actions.widget-settings"),
                "action": "widget-settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
            if (popupMenuWindow) {
                popupMenuWindow.close();
            }

            if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            } else if (action === "stop") {
                if (pluginApi && pluginApi.mainInstance) {
                    pluginApi.mainInstance.stopPlayback();
                }
            }
        }
    }
}