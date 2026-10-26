// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"
import "../../Services"


Item {
    id: root
    signal back()
    property var locale: Qt.locale()
    implicitHeight: col.implicitHeight

    // Текущая погода (null пока данные не загружены)
    readonly property var cur: Weather.currentWeather
    readonly property var curUnits: Weather.currentWeatherUnits
    readonly property var curExtra: Weather.current
    readonly property var curExtraUnits: Weather.currentUnits
    readonly property var daily: Weather.daily
    readonly property var dailyUnits: Weather.dailyUnits
    readonly property bool isDay: !cur || cur.is_day === undefined || cur.is_day === 1

    // Прогноз максимум на 7 дней
    readonly property int daysCount: daily && daily.time ? Math.min(daily.time.length, 7) : 0

    function num(v) {
        if (v === undefined || v === null) return NaN
        return Number(String(v).replace(",", "."))
    }

    readonly property string windUnit: {
        const u = curUnits ? String(curUnits.windspeed ?? "") : ""
        if (u === "") return "m/s"
        if (u === "m/s" || u === "ms") return I18n.tr("m/s")
        return u
    }

    readonly property string pressureUnit: {
        const u = dailyUnits ? String(dailyUnits.surface_pressure_mean ?? "") : ""
        return u !== "" ? u : "hPa"
    }

    function dirName(deg) {
        if (deg === undefined || deg === null || isNaN(Number(deg))) return ""
        const names = [I18n.tr("N"), I18n.tr("NE"), I18n.tr("E"), I18n.tr("SE"),
                       I18n.tr("S"), I18n.tr("SW"), I18n.tr("W"), I18n.tr("NW")]
        const i = Math.round((((Number(deg) % 360) + 360) % 360) / 45) % 8
        return names[i]
    }

    function timeLabel(iso) {
        if (!iso) return "--:--"
        const s = String(iso)
        const t = s.includes("T") ? s.split("T")[1] : s
        return t.substring(0, 5)
    }

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

    readonly property string dayLength: {
        const sr = timeLabel(sunriseLabel())
        const ss = timeLabel(sunsetLabel())
        if (sr === "--:--" || ss === "--:--") return "--"
        const toMin = t => { const p = t.split(":"); return Number(p[0]) * 60 + Number(p[1]) }
        let m = toMin(ss) - toMin(sr)
        if (m < 0) m += 24 * 60
        if (isNaN(m)) return "--"
        return I18n.tr("%1 h %2 min", Math.floor(m / 60), m % 60)
    }

    readonly property string todayWeekday: {
        const t = root.locale.dayName(new Date().getDay(), Locale.LongFormat)
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    function iconForCode(code, isDay) {
        return Weather.weatherSymbolFromCode(Number(code), isDay)
    }

    function shortDayName(iso) {
        if (!iso) return ""
        const d = new Date(iso + "T00:00:00")
        if (isNaN(d.getTime())) return ""
        const s = locale.dayName(d.getDay(), Locale.ShortFormat)
        if (!s) return ""
        return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase()
    }

    function dayRowLabel(iso, index) {
        if (index === 0) return I18n.tr("Today")
        return shortDayName(iso)
    }

    // Плитка доп. информации о погоде (скорость ветра, направление, давление, влажность, восход/закат)
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

        // Заголовок
        Item {
            width: parent.width; height: 46
            RoundButton { anchors.verticalCenter: parent.verticalCenter; icon: "back"; onClicked: root.back() }
            Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.tr("Weather")
                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
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
                size: 56
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
                    text: Weather.name
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
                }
            }
        }

        // Нет данных
        Text {
            visible: root.cur === null
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr("No weather data")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
        }

        // Детали: скорость ветра, направление, давление, влажность, восход/закат, долгота дня
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            visible: root.cur !== null

            DetailTile {
                label: I18n.tr("Wind speed")
                value: {
                    const w = root.num(root.cur ? root.cur.windspeed : undefined)
                    return isNaN(w) ? "--" : `${Math.round(w)} ${root.windUnit}`
                }
            }
            DetailTile {
                label: I18n.tr("Wind direction")
                value: root.cur ? root.dirName(root.num(root.cur.winddirection)) : "--"
            }
            DetailTile {
                label: I18n.tr("Pressure")
                value: {
                    const arr = root.daily ? root.daily.surface_pressure_mean : null
                    if (!arr || arr.length === 0) return "--"
                    const p = root.num(arr[0])
                    if (isNaN(p) || p <= 0) return "--"
                    return `${Math.round(p)} ${root.pressureUnit}`
                }
            }
            DetailTile {
                label: I18n.tr("Humidity")
                value: {
                    const arr = root.daily ? root.daily.relative_humidity_2m_mean : null
                    if (!arr || arr.length === 0) return "--"
                    const h = root.num(arr[0])
                    return isNaN(h) ? "--" : `${Math.round(h)}%`
                }
            }
            DetailTile {
                label: I18n.tr("Sunrise")
                value: root.sunriseLabel()
            }
            DetailTile {
                label: I18n.tr("Sunset")
                value: root.sunsetLabel()
            }
            DetailTile {
                label: I18n.tr("Daylight duration")
                value: root.dayLength
            }
        }

        // Прогноз на неделю: день недели + погода + максимум/минимум за день
        Column {
            width: parent.width
            spacing: 6
            visible: root.daysCount > 0

            Text {
                text: I18n.tr("Forecast")
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

                        // День недели (Сегодня / Пн / Вт / …)
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
                                size: 32
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
                                ? `${Math.round(dayRow.maxs[dayRow.index])}° / ${Math.round(dayRow.mins[dayRow.index])}${root.dailyUnits.temperature_2m_min}` : "--"
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