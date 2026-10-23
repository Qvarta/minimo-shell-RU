// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"
import "../../Services"

// Погода внутри острова (открывается кликом по строке погоды):
// текущая погода + прогноз на 5 дней. Данные берутся из Weather (Open-Meteo daily).
Item {
    id: root
    signal back()
    property var locale: Qt.locale()
    implicitHeight: col.implicitHeight

    // Текущая погода (null пока данные не загружены)
    readonly property var cur: Weather.currentWeather
    readonly property var curUnits: Weather.currentWeatherUnits
    readonly property var daily: Weather.daily
    readonly property var dailyUnits: Weather.dailyUnits
    readonly property bool isDay: !cur || cur.is_day === undefined || cur.is_day === 1

    // Прогноз максимум на 5 дней
    readonly property int daysCount: daily && daily.time ? Math.min(daily.time.length, 5) : 0

    // Иконки в assets только базовые (sun/moon/drop/cloudy нет): сопоставляем символы погоды им.
    function iconForCode(code, isDay) {
        const sym = Weather.weatherSymbolFromCode(code, isDay)
        if (sym === "clear-day") return "sun"
        if (sym === "clear-night") return "moon"
        if (sym === "rain" || sym === "thunderstorm") return "drop"
        return "globe"
    }

    function dayLabel(iso) {
        if (!iso) return ""
        const d = new Date(iso + "T00:00:00")
        if (isNaN(d.getTime())) return iso
        const t = d.toLocaleDateString(locale, Locale.ShortFormat)
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    component RoundButton: Rectangle {
        id: rb
        property string icon
        property real iconRotation: 0
        signal clicked()
        width: 32; height: 32; radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18; rotation: rb.iconRotation }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Заголовок: назад + название места
        Item {
            width: parent.width; height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Погода")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
        }

        // Текущая погода
        Row {
            width: parent.width
            spacing: 12
            visible: root.cur !== null
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.cur ? root.iconForCode(root.cur.weathercode, root.isDay) : "sun"
                size: 34
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: root.cur && root.curUnits
                        ? `${Math.round(root.cur.temperature)}${root.curUnits.temperature}` : "--"
                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
                Text {
                    text: root.cur ? I18n.tr(Weather.weatherDescriptionFromCode(root.cur.weathercode)) : ""
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                }
                Text {
                    visible: text !== ""
                    text: Weather.stableName
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
                }
            }
        }

        // Нет данных
        Text {
            visible: root.cur === null
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr("Нет данных о погоде")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
        }

        // Прогноз на 5 дней
        Column {
            width: parent.width
            spacing: 6
            visible: root.daysCount > 0

            Repeater {
                model: root.daysCount
                delegate: Rectangle {
                    id: dayRow
                    required property int index
                    width: parent.width
                    height: 40
                    radius: Theme.radiusField
                    color: dayMau.containsMouse ? Theme.hover : "transparent"

                    readonly property var codes: root.daily ? root.daily.weathercode : null
                    readonly property var maxs: root.daily ? root.daily.temperature_2m_max : null
                    readonly property var mins: root.daily ? root.daily.temperature_2m_min : null
                    readonly property var times: root.daily ? root.daily.time : null

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 10
                        Text {
                            width: 70; height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: dayRow.times ? root.dayLabel(dayRow.times[dayRow.index]) : ""
                            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: dayRow.codes ? root.iconForCode(dayRow.codes[dayRow.index], true) : "globe"
                            size: 20
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: dayRow.maxs !== null && dayRow.mins !== null && root.dailyUnits
                                ? `${Math.round(dayRow.maxs[dayRow.index])}° / ${Math.round(dayRow.mins[dayRow.index])}°${root.dailyUnits.temperature_2m_min}` : "--"
                            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
                            font.features: { "tnum": 1 }
                        }
                    }
                    MouseArea { id: dayMau; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
