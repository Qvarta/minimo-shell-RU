// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"
import "../../Services"

// Погода внутри острова (открывается кликом по строке погоды):
// текущая погода + детали (ветер, направление ветра, порывы, давление, влажность,
// восход/закат, долгота дня) + прогноз на неделю. Все даты — в виде дня недели.
// Данные берутся из Weather (Open-Meteo current_weather/current/daily).
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

    // Прогноз максимум на 7 дней
    readonly property int daysCount: daily && daily.time ? Math.min(daily.time.length, 7) : 0

    // Число из значения Open-Meteo (может быть строкой с юнитом, напр. "7.2")
    function num(v) {
        if (v === undefined || v === null) return NaN
        return Number(String(v).replace(",", "."))
    }

    // Единицы измерения скорости ветра ("ms" -> "м/с", иначе как в units)
    readonly property string windUnit: {
        const u = curUnits ? String(curUnits.windspeed_10m ?? "") : ""
        if (u === "ms" || u === "m/s") return I18n.tr("м/с")
        if (u) return u
        return I18n.tr("км/ч")
    }

    // Единицы давления из ответа API (по умолчанию гПа)
    readonly property string pressureUnit: {
        const u = curExtraUnits ? String(curExtraUnits.surface_pressure ?? "") : ""
        return u ? I18n.tr(u) : I18n.tr("гПа")
    }

    // Компасное сокращение направления ветра по азимуту (север = 0°, по часовой)
    function dirName(deg) {
        if (deg === undefined || deg === null || isNaN(Number(deg))) return ""
        const names = [I18n.tr("С"), I18n.tr("СВ"), I18n.tr("В"), I18n.tr("ЮВ"),
                       I18n.tr("Ю"), I18n.tr("ЮЗ"), I18n.tr("З"), I18n.tr("СЗ")]
        const i = Math.round((((Number(deg) % 360) + 360) % 360) / 45) % 8
        return names[i]
    }

    // Направление + градусы для плитки ("С · 15°")
    function dirLabel(deg) {
        const d = num(deg)
        if (isNaN(d)) return "--"
        const r = Math.round(((d % 360) + 360) % 360)
        const name = dirName(r)
        return name ? `${name} · ${r}°` : `${r}°`
    }

    // Время из ISO-строки Open-Meteo ("2026-10-24T07:12" или "07:12") -> "HH:MM"
    function timeLabel(iso) {
        if (!iso) return "--:--"
        const s = String(iso)
        const t = s.includes("T") ? s.split("T")[1] : s
        return t.substring(0, 5)
    }

    // Восход / закат сегодня: сначала current_sun_times (если API вернул), затем daily[0]
    function sunriseLabel() {
        const w = Weather.data ? Weather.data.current_sun_times : null
        if (w && w.sunrise) return timeLabel(w.sunrise)
        return daily && daily.sunrise && daily.sunrise.length > 0 ? timeLabel(daily.sunrise[0]) : "--:--"
    }

    function sunsetLabel() {
        const w = Weather.data ? Weather.data.current_sun_times : null
        if (w && w.sunset) return timeLabel(w.sunset)
        return daily && daily.sunset && daily.sunset.length > 0 ? timeLabel(daily.sunset[0]) : "--:--"
    }

    // Долгота дня "6 ч 42 мин" по времени восхода/заката
    readonly property string dayLength: {
        const sr = timeLabel(sunriseLabel())
        const ss = timeLabel(sunsetLabel())
        if (sr === "--:--" || ss === "--:--") return "--"
        const toMin = t => { const p = t.split(":"); return Number(p[0]) * 60 + Number(p[1]) }
        let m = toMin(ss) - toMin(sr)
        if (m < 0) m += 24 * 60
        if (isNaN(m)) return "--"
        return I18n.tr("%1 ч %2 мин", Math.floor(m / 60), m % 60)
    }

    // Текущая дата — одним днём недели ("Суббота")
    readonly property string todayWeekday: {
        const t = root.locale.dayName(new Date().getDay(), Locale.LongFormat)
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    // Иконки в assets только базовые (sun/moon/drop/cloudy нет): сопоставляем символы погоды им.
    function iconForCode(code, isDay) {
        const sym = Weather.weatherSymbolFromCode(code, isDay)
        if (sym === "clear-day") return "sun"
        if (sym === "clear-night") return "moon"
        if (sym === "rain" || sym === "thunderstorm") return "drop"
        return "globe"
    }

    // Сегодня / завтра / послезавтра — иначе полный день недели ("Четверг")
    function dayRowLabel(iso, index) {
        if (index === 0) return I18n.tr("Сегодня")
        if (index === 1) return I18n.tr("Завтра")
        if (index === 2) return I18n.tr("Послезавтра")
        return dayLabel(iso)
    }

    // Полный день недели по дате Open-Meteo ("2026-10-29" -> "Четверг")
    function dayLabel(iso) {
        if (!iso) return ""
        const d = new Date(iso + "T00:00:00")
        if (isNaN(d.getTime())) return iso
        const t = locale.dayName(d.getDay(), Locale.LongFormat)
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    // Плитка доп. информации о погоде (ветер, давление, влажность, восход/закат)
    component DetailTile: Rectangle {
        id: tile
        property string label
        property string value
        width: (parent.width - parent.columnSpacing) / 2
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

        // Заголовок: назад + название места + сегодня (день недели)
        Item {
            width: parent.width; height: 46
            RoundButton { anchors.verticalCenter: parent.verticalCenter; icon: "back"; onClicked: root.back() }
            Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.tr("Погода")
                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.todayWeekday
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
                }
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

        // Детали: ветер, направление, порывы, давление, влажность, восход/закат, день недели
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            visible: root.cur !== null

            DetailTile {
                label: I18n.tr("Ветер")
                value: {
                    const w = root.num(root.cur ? root.cur.windspeed_10m : undefined)
                    if (isNaN(w)) return "--"
                    const deg = root.cur ? root.num(root.cur.winddirection_10m) : NaN
                    const name = isNaN(deg) ? "" : root.dirName(deg)
                    return name ? `${Math.round(w)} ${root.windUnit} · ${name}` : `${Math.round(w)} ${root.windUnit}`
                }
            }
            DetailTile {
                label: I18n.tr("Направление ветра")
                value: root.cur ? root.dirLabel(root.cur.winddirection_10m) : "--"
            }
            DetailTile {
                label: I18n.tr("Порывы ветра")
                value: {
                    const arr = root.daily ? root.daily.wind_speed_10m_max : null
                    if (!arr || arr.length === 0) return "--"
                    const w = root.num(arr[0])
                    return isNaN(w) ? "--" : `${Math.round(w)} ${root.windUnit}`
                }
            }
            DetailTile {
                label: I18n.tr("Давление")
                value: {
                    // surface_pressure (текущее) предпочтительнее pressure_msl
                    const p = root.curExtra && root.curExtra.surface_pressure !== undefined
                        ? root.num(root.curExtra.surface_pressure)
                        : (root.cur && root.cur.pressure_msl !== undefined ? root.num(root.cur.pressure_msl) : NaN)
                    if (isNaN(p) || p <= 0) return "--"
                    return `${Math.round(p)} ${root.pressureUnit}`
                }
            }
            DetailTile {
                label: I18n.tr("Влажность")
                value: {
                    const h = root.curExtra && root.curExtra.relativehumidity_2m !== undefined
                        ? root.num(root.curExtra.relativehumidity_2m)
                        : (root.cur && root.cur.relative_humidity_2m !== undefined ? root.num(root.cur.relative_humidity_2m) : NaN)
                    return isNaN(h) ? "--" : `${Math.round(h)}%`
                }
            }
            DetailTile {
                label: I18n.tr("Восход")
                value: root.sunriseLabel()
            }
            DetailTile {
                label: I18n.tr("Закат")
                value: root.sunsetLabel()
            }
            DetailTile {
                label: I18n.tr("Долгота дня")
                value: root.dayLength
            }
        }

        // Прогноз на неделю: день недели + погода + максимум/минимум за день
        Column {
            width: parent.width
            spacing: 6
            visible: root.daysCount > 0

            Text {
                text: I18n.tr("Прогноз")
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.daysCount
                delegate: Rectangle {
                    id: dayRow
                    required property int index
                    width: parent.width
                    height: 44
                    radius: Theme.radiusField
                    color: dayMau.containsMouse ? Theme.hover : "transparent"

                    readonly property var codes: root.daily ? root.daily.weathercode : null
                    readonly property var maxs: root.daily ? root.daily.temperature_2m_max : null
                    readonly property var mins: root.daily ? root.daily.temperature_2m_min : null
                    readonly property var times: root.daily ? root.daily.time : null
                    readonly property var winds: root.daily ? root.daily.wind_speed_10m_max : null
                    readonly property var hums: root.daily ? root.daily.relative_humidity_2m_mean : null
                    readonly property var dirs: root.daily ? root.daily.wind_direction_10m_dominant : null

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 10

                        // День недели (Сегодня / Завтра / Понедельник…)
                        Text {
                            width: 76; height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: dayRow.times ? root.dayRowLabel(dayRow.times[dayRow.index], dayRow.index) : ""
                            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        // Иконка погоды + описание и детали дня (ветер, направление, влажность)
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 76 - 96 - 2 * parent.spacing
                            height: parent.height
                            Icon {
                                id: dayIcon
                                anchors.verticalCenter: parent.verticalCenter
                                name: dayRow.codes ? root.iconForCode(dayRow.codes[dayRow.index], true) : "globe"
                                size: 20
                            }
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: dayIcon.width + 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - dayIcon.width - 10
                                spacing: 1
                                Text {
                                    text: {
                                        const c = dayRow.codes ? dayRow.codes[dayRow.index] : undefined
                                        return c === undefined ? "" : I18n.tr(Weather.weatherDescriptionFromCode(c))
                                    }
                                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12
                                    elide: Text.ElideRight; width: parent.width
                                }
                                Text {
                                    visible: text !== ""
                                    text: {
                                        const w = dayRow.winds ? root.num(dayRow.winds[dayRow.index]) : NaN
                                        const d = dayRow.dirs ? root.num(dayRow.dirs[dayRow.index]) : NaN
                                        const h = dayRow.hums ? root.num(dayRow.hums[dayRow.index]) : NaN
                                        const parts = []
                                        if (!isNaN(w)) parts.push(`${Math.round(w)} ${root.windUnit}${isNaN(d) ? "" : " " + root.dirName(d)}`)
                                        if (!isNaN(h)) parts.push(`${Math.round(h)}%`)
                                        return parts.join(" · ")
                                    }
                                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 10
                                    elide: Text.ElideRight; width: parent.width
                                }
                            }
                        }

                        // Максимум / минимум за день
                        Text {
                            width: 96; height: parent.height
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            text: dayRow.maxs !== null && dayRow.mins !== null && root.dailyUnits
                                ? `${Math.round(dayRow.maxs[dayRow.index])}° / ${Math.round(dayRow.mins[dayRow.index])}°${root.dailyUnits.temperature_2m_min}` : "--"
                            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }
                    MouseArea { id: dayMau; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
