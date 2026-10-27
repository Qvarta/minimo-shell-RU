import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    spacing: Style.marginL

    property string configFile: pluginApi?.pluginSettings?.config

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        color: Color.mSurfaceVariant
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: Style.borderS
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM
            
            NText {
                text: pluginApi?.tr("fileTitle")
                color: Color.mPrimary
                font.pointSize: Style.fontSizeL
                font.weight: Font.Bold
            }
            
            NDivider {
                Layout.fillWidth: true
            }
            
            RowLayout {
                spacing: Style.marginL
                Layout.fillWidth: true
                
                Rectangle {
                    width: 40
                    height: 40
                    radius: Style.radiusS
                    color: Color.mSurface
                    
                    NIcon {
                        anchors.centerIn: parent
                        icon: "file-settings"
                        color: Color.mPrimary
                        pointSize: 24  
                        applyUiScale: true
                    }
                }

                NText {
                    text: {
                        if (root.configFile) {
                            var parts = root.configFile.split('/')
                            return parts[parts.length - 1]
                        }
                        return pluginApi?.tr("fileNotExist");
                    }
                    font.pointSize: Style.fontSizeM
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                NButton {
                    text: pluginApi?.tr("fileSelect")
                    onClicked: {
                        filePicker.openFilePicker();
                    }
                }
            }
        }
    }

    NFilePicker {
        id: filePicker
        title: pluginApi?.tr("fileSelectTitle")
        selectionMode: "files"
        nameFilters: ["*.kdl", "*.conf"]
        
        onAccepted: function(paths) {
            if (paths.length > 0) {
                root.configFile = paths[0];
            }
        }
        
        onCancelled: {
            // 
        }
    }
    
    function saveSettings() {
        if (!pluginApi) {
            return;
        }
        
        if (root.configFile !== ""){
            pluginApi.pluginSettings["config"] = root.configFile;
        }
        
        pluginApi.saveSettings();
        pluginApi?.mainInstance?.refreshData();
        
        if (pluginApi.closePanel) {
            pluginApi.closePanel();
        }
    }
}