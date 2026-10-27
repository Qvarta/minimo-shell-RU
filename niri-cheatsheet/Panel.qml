import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property var rawCategories: pluginApi?.pluginSettings?.cheatsheetData || []
    property var categories: rawCategories

    readonly property bool allowAttach: true 

    property var categoryExpanded: ({})
    property int currentExpandedIndex: 1
    property int currentIndex: -1

    property real contentPreferredWidth: 460
    property real contentPreferredHeight: {
        var hasExpanded = false;
        for (var i = 0; i < categories.length; i++) {
            if (categoryExpanded[i]) {
                hasExpanded = true;
                break;
            }
        }
        
        if (!hasExpanded) {
            return 420;
        } else {
            return 600;
        }
    }
    
    // anchors.fill: parent

    function moveSelection(delta) {
        if (categories.length === 0) return;
        
        var newIndex = currentIndex + delta;
        if (newIndex >= 0 && newIndex < categories.length) {
            currentIndex = newIndex;
            
            // Ensure the selected category is visible
            var targetY = 0;
            for (var i = 0; i < currentIndex; i++) {
                targetY += getCategoryHeight(i);
            }
            
            var viewportHeight = flickable.height;
            
            if (targetY < flickable.contentY) {
                flickable.contentY = targetY;
            } else if (targetY + getCategoryHeight(currentIndex) > flickable.contentY + viewportHeight) {
                flickable.contentY = targetY + getCategoryHeight(currentIndex) - viewportHeight;
            }
        }
    }
    
    function getCategoryHeight(index) {
        if (index >= 0 && index < categories.length) {
            var expanded = categoryExpanded[index] || false;
            if (expanded) {
                var bindsHeight = getBindsHeight(index);
                return 50 + bindsHeight + 12; 
            } else {
                return 50;
            }
        }
        return 50;
    }
    
    function getBindsHeight(index) {
        if (index >= 0 && index < categories.length) {
            var category = categories[index];
            if (category && category.binds) {
                return category.binds.length * 28; 
            }
        }
        return 0;
    }
    
    function activateCurrentCategory() {
        if (currentIndex >= 0 && currentIndex < categories.length) {
            toggleCategory(currentIndex);
        }
    }
    
    Keys.onUpPressed: moveSelection(-1)
    Keys.onDownPressed: moveSelection(1)
    Keys.onReturnPressed: activateCurrentCategory()
    Keys.onEnterPressed: activateCurrentCategory()

    Component.onCompleted: {
        var expanded = {};
        for (var i = 0; i < categories.length; i++) {
            expanded[i] = false;
        }
        categoryExpanded = expanded;
        currentExpandedIndex = -1;
        currentIndex = categories.length > 0 ? 0 : -1;
        forceActiveFocus();
    }
    
    onCategoriesChanged: {
        var expanded = {};
        for (var i = 0; i < categories.length; i++) {
            expanded[i] = (i === currentExpandedIndex);
        }
        categoryExpanded = expanded;
        
        if (currentIndex >= categories.length) {
            currentIndex = categories.length > 0 ? 0 : -1;
        } else if (currentIndex === -1 && categories.length > 0) {
            currentIndex = 0;
        }
    }
    
    function toggleCategory(index) {
        var newExpanded = {};
        
        if (currentExpandedIndex === index) {
            for (var i = 0; i < categories.length; i++) {
                newExpanded[i] = false;
            }
            currentExpandedIndex = -1;
        } else {
            for (var i = 0; i < categories.length; i++) {
                newExpanded[i] = (i === index);
            }
            currentExpandedIndex = index;
        }
        
        categoryExpanded = newExpanded;
    }
    
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        anchors.margins: Style.marginS
        color: Color.mSurface
        radius: Style.radiusM        
        border.width: Style.borderS
        border.color: Color.mOutline
        clip: true
        
        NText {
            id: emptyText
            anchors.centerIn: parent
            text: pluginApi?.tr("panel.no_data")
            font.pointSize: Style.fontSizeL
            color: Color.mOnSurface
            visible: categories.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width * 0.8
        }
        
        Flickable {
            id: flickable
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width - 2 * Style.marginS
            contentWidth: width
            contentHeight: categoriesColumn.height
            boundsBehavior: Flickable.StopAtBounds
            visible: categories.length > 0
            
            onContentHeightChanged: {
                if (contentHeight < height) {
                    contentY = 0;
                }
            }
            
            Column {
                id: categoriesColumn
                width: flickable.width
                spacing: Style.marginS
                
                y: Math.max(0, (flickable.height - height) / 2)
                
                Repeater {
                    model: categories
                    
                    Rectangle {
                        id: categoryContainer
                        width: categoriesColumn.width
                        height: expanded ? 50 + bindsColumn.height + 12 : 50
                        color: "transparent"
                        
                        readonly property bool expanded: categoryExpanded[index] || false
                        readonly property bool isSelected: index === currentIndex
                        
                        Behavior on height {
                            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                        
                        Rectangle {
                            id: header
                            width: parent.width - 24
                            height: 50
                            radius: 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            color: (mouseArea.containsMouse || isSelected) ? 
                                   Color.mHover : (expanded ? Color.mHover : Color.mSurfaceVariant)
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                            
                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    currentIndex = index;
                                    root.toggleCategory(index);
                                }
                                
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: Style.marginL
                                    
                                    NIcon {
                                        id: categoryIcon
                                        icon: pluginApi?.mainInstance?.getCategoryIcon(modelData.title)
                                        pointSize: 20
                                        
                                        color: (mouseArea.containsMouse || isSelected) ? 
                                               Color.mOnHover : (expanded ? Color.mOnHover : Color.mPrimary)
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                        
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    NText {
                                        id: categoryTitle
                                        text: modelData.title
                                        font.pointSize: Style.fontSizeXL
                                        font.weight: Font.Medium
                                        
                                        color: (mouseArea.containsMouse || isSelected) ? 
                                               Color.mOnHover : (expanded ? Color.mOnHover : Color.mPrimary)
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                        
                                        width: parent.width - 32
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                        
                        Column {
                            id: bindsColumn
                            width: parent.width - 24
                            anchors.top: header.bottom
                            anchors.topMargin: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            visible: expanded
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            
                            Repeater {
                                model: modelData.binds
                                visible: expanded
                                
                                Rectangle {
                                    width: bindsColumn.width
                                    height: 28
                                    color: index % 2 === 0 ? Color.mSurface : Color.mSurfaceVariant
                                    
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8
                                        
                                        Rectangle {
                                            width: 200
                                            height: 20
                                            anchors.verticalCenter: parent.verticalCenter
                                            clip: true
                                            color: "transparent"
                                            
                                            Row {
                                                height: 20
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Repeater {
                                                    model: modelData.keys.split(" + ")
                                                    Rectangle {
                                                        width: Math.max(keyText.implicitWidth + 8, 24)
                                                        height: 20
                                                        color: pluginApi?.mainInstance?.getKeyColor(modelData)
                                                        radius: 3
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        
                                                        NText {
                                                            id: keyText
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            font.pointSize: Style.fontSizeL
                                                            font.weight: Font.Medium
                                                            color: Color.mOnPrimary
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        NText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.desc
                                            font.pointSize: Style.fontSizeL
                                            color: Color.mOnSurface
                                            wrapMode: Text.NoWrap
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                            
                            NText {
                                width: parent.width
                                height: 28
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: pluginApi?.tr("panel.no_data")
                                font.pointSize: 9
                                color: Color.mOnSurfaceVariant
                                visible: modelData.binds.length === 0 && expanded
                            }
                        }
                    }
                }
            }
            
            ScrollBar.vertical: ScrollBar {
                width: 8
                policy: ScrollBar.AsNeeded
                visible: false
                active: false
            }
        }
    }
}