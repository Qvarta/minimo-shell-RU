// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"
import "../Services"

Column {
    id: root
    spacing: 20
    property string statusText: ""

    function saveCity() {
        const city = cityInput.text.trim()
        if (city === "") {
            statusText = I18n.tr("Enter a city")
            return
        }

        if (Weather.setCity(city)) {
            cityInput.text = city
            statusText = I18n.tr("Saved")
        }
    }

    onVisibleChanged: {
        if (visible) {
            cityInput.text = Weather.location.name
            statusText = ""
        }
    }

    // SectionTitle { text: I18n.tr("Weather location") }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.tr("City")
        color: Theme.textPrimary
        font.family: Theme.font
        font.pixelSize: 14
    }

    Rectangle {
        width: parent.width
        height: 44
        radius: 22
        color: Theme.field

        TextInput {
            id: cityInput
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.textPrimary
            selectionColor: Theme.fill
            selectedTextColor: Theme.onAccent
            font.family: Theme.font
            font.pixelSize: 14
            selectByMouse: true
            clip: true
            onTextChanged: root.statusText = ""
            Keys.onReturnPressed: root.saveCity()
            Keys.onEnterPressed: root.saveCity()
        }

        Text {
            anchors.fill: cityInput
            verticalAlignment: Text.AlignVCenter
            visible: cityInput.text.length === 0
            text: I18n.tr("Enter a city")
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 14
            enabled: false
        }
    }

    Row {
        spacing: 12
        PillButton {
            text: I18n.tr("Save")
            onClicked: root.saveCity()
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.statusText !== ""
            text: root.statusText
            color: root.statusText === I18n.tr("Saved") ? Theme.textSecondary : Theme.danger
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
