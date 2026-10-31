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

    Text {
        width: parent.width
        text: I18n.tr("Current location")
        color: Theme.textPrimary
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    Rectangle {
        width: parent.width
        radius: Theme.radiusField
        color: Theme.surface
        implicitHeight: locationTable.implicitHeight + 24

        Column {
            id: locationTable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 0

            Row {
                width: parent.width
                height: 30
                Text {
                    width: parent.width * 0.42
                    text: I18n.tr("Property")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    width: parent.width * 0.58
                    text: I18n.tr("Value")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.track }

            component InfoRow: Row {
                property string label
                property string value
                width: locationTable.width
                height: Math.max(38, valueText.implicitHeight + 16)
                spacing: 0

                Text {
                    width: parent.width * 0.42
                    height: parent.height
                    text: parent.label
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                }
                Text {
                    id: valueText
                    width: parent.width * 0.58
                    height: parent.height
                    text: parent.value
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                }
            }

            InfoRow {
                label: I18n.tr("Resolved location")
                value: Weather.stableName !== "" ? Weather.stableName : I18n.tr("Not available")
            }

            Rectangle { width: parent.width; height: 1; color: Theme.track; opacity: 0.6 }

            InfoRow {
                visible: Weather.displayCoordinates !== ""
                label: I18n.tr("Coordinates")
                value: Weather.displayCoordinates
            }

            Rectangle { width: parent.width; height: 1; color: Theme.track; opacity: 0.6 }

            InfoRow {
                visible: Weather.weather && Weather.weather.timezone
                label: I18n.tr("Time zone")
                value: Weather.weather ? String(Weather.weather.timezone) + (Weather.weather.timezone_abbreviation ? " (" + Weather.weather.timezone_abbreviation + ")" : "") : ""
            }

            Rectangle { width: parent.width; height: 1; color: Theme.track; opacity: 0.6 }

            InfoRow {
                visible: Weather.weather && Weather.weather.elevation !== undefined
                label: I18n.tr("Elevation")
                value: Weather.weather && Weather.weather.elevation !== undefined ? Math.round(Number(Weather.weather.elevation)) + " m" : ""
            }
        }
    }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.tr("Enter the location")
        color: Theme.textPrimary
        font.family: Theme.font
        font.pixelSize: 14
    }

    Row {
        width: parent.width
        spacing: 12

        Rectangle {
            width: parent.width - saveButton.width - parent.spacing
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

        PillButton {
            id: saveButton
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Save")
            onClicked: root.saveCity()
        }
    }

    Text {
        visible: root.statusText !== ""
        text: root.statusText
        color: root.statusText === I18n.tr("Saved") ? Theme.textSecondary : Theme.danger
        font.family: Theme.font
        font.pixelSize: 12
    }
}
