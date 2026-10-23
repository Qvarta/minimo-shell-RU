// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"
import "../../Services"

// Погода внутри острова (открывается кликом по строке погоды):
// текущая погода + детали (ветер, направление, давление, влажность, восход/закат)
// + прогноз на 5 дней. Данные берутся из Weather (Open-Meteo current/daily).
Item {
    id: root
    signal back()
    property var locale: Qt.locale()
    implicitHeight: col.implicitHeight

    // Текущая погода (null пока данные не загружены)
    readonly property var cur: Weather.currentWeather
    readonly property var curUnits: Weather.currentWeatherUnits
    // Дополнительные текущие поля (relativehumidity_2m, surface_pressure, is_day)
    readonly property var curExtra: Weather.current
    readonly property var curExtraUnits: Weather.currentUnits
    readonly property var daily: Weather.daily
    readonly property var dailyUnits: Weather.dailyUnits
    readonly property bool isDay: !cur || cur.is_day === undefined || cur.is_day === 1

    // Прогноз максимум на 5 дней
    readonly property int daysCount: daily && daily.time ? Math.min(daily.time.length, 5) : 0

    // Единицы измерения скорости ветра ("ms" -> "м/с", иначе как в units)
    readonly property string windUnit: {
        const u = curUnits ? String(curUnits.windspeed_10m ?? "") : ""
        if (u === "ms" || u === "m/s") return I18n.tr("м/с")
        if (u) return u
        return I18n.tr("км/ч")
    }

    // Компасное сокращение направления ветра по азимуту (север = 0°, по часовой)
    function dirName(deg) {
        if (deg === undefined || deg === null || isNaN(Number(deg))) return ""
        const names = [I18n.tr("С"), I18n.tr("СВ"), I18n.tr("В"), I18n.tr("ЮВ"),
                       I18n.tr("Ю"), I18n.tr("ЮЗ"), I18n.tr("З"), I18n.tr("СЗ")]
        const i = Math.round((((Number(deg) % 360) + 360) % 360) / 45) % 8
        return names[i]
    }

    // Время из ISO-строки Open-Meteo ("2026-10-24T07:12" или "07:12") -> "HH:MM"
    function timeLabel(iso) {
        if (!iso) return "--:--"
        const s = String(iso)
        const t = s.includes("T") ? s.split("T")[1] : s
        return t.substring(0, 5)
    }

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
        // День недели (по локали): пн, вт, ср...
        const t = d.toLocaleDateString(locale, Locale.ShortWeekdayFormat)
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    // Сегодня / завтра / послезавтра — иначе день недели
    function dayRowLabel(iso, index) {
        if (index === 0) return I18n.tr("Сегодня")
        if (index === 1) return I18n.tr("Завтра")
        return dayLabel(iso)
    }

    // Плитка доп. информации о погоде (ветер, давление, влажность, восход/закат)
    component DetailTile: Rectangle {
        id: tile
        property string label
        property string value
        width: (parent.width - parent.hspacing) / 2
        height: 46
        radius: Theme.radiusField
        color: Theme.surface
        Column {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10; anchors.rightMargin: 8
            spacing: 2
            Text {
                text: tile.label
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 10
                elide: Text.ElideRight; width: parent.width
            }
            Text {
                text: tile.value
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                font.weight: Font.Medium; font.features: { "tnum": 1 }
                elide: Text.ElideRight; width: parent.width
            }
        }
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

        // Детали: ветер, направление, давление, влажность, восход/закат
        Grid {
            width: parent.width
            columns: 2
            hspacing: 8
            vspacing: 8
            visible: root.cur !== null

            DetailTile {
                label: I18n.tr("Ветер")
                value: root.cur && root.cur.windspeed_10m !== undefined
                    ? `${Math.round(Number(root.cur.windspeed_10m))} ${root.windUnit}` : "--"
            }
            DetailTile {
                label: I18n.tr("Направление ветра")
                value: {
                    if (!root.cur || root.cur.winddirection_10m === undefined) return "--"
                    const deg = Math.round(Number(root.cur.winddirection_10m))
                    const name = root.dirName(deg)
                    return name ? `${name} · ${deg}°` : `${deg}°`
                }
            }
            DetailTile {
                label: I18n.tr("Давление")
                value: {
                    // surface_pressure (текущее) предпочтительнее pressure_msl
                    const p = root.curExtra && root.curExtra.surface_pressure !== undefined
                        ? Number(root.curExtra.surface_pressure)
                        : (root.cur && root.cur.pressure_msl !== undefined ? Number(root.cur.pressure_msl) : NaN)
                    if (isNaN(p) || p <= 0) return "--"
                    const unit = (root.curExtraUnits && root.curExtraUnits.surface_pressure)
                        ? root.curExtraUnits.surface_pressure : "гПа"
                    return `${Math.round(p)} ${I18n.tr(unit)}`
                }
            }
            DetailTile {
                label: I18n.tr("Влажность")
                value: {
                    const h = root.curExtra && root.curExtra.relativehumidity_2m !== undefined
                        ? Number(root.curExtra.relativehumidity_2m)
                        : (root.cur && root.cur.relative_humidity_2m !== undefined ? Number(root.cur.relative_humidity_2m) : NaN)
                    return isNaN(h) ? "--" : `${Math.round(h)}%`
                }
            }
            DetailTile {
                label: I18n.tr("Восход")
                value: root.daily && root.daily.sunrise ? root.timeLabel(root.daily.sunrise[0]) : "--"
            }
            DetailTile {
                label: I18n.tr("Закат")
                value: root.daily && root.daily.sunset ? root.timeLabel(root.daily.sunset[0]) : "--"
            }
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
                            text: dayRow.times ? root.dayRowLabel(dayRow.times[dayRow.index], dayRow.index) : ""
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
