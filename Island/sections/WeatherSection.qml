// SPDX-License-Identifier: MIT

import QtQuick
import "../../Common"
import "../../Services"

Text {
    id: root
    text: {
        if (!Weather.currentWeather || !Weather.currentWeatherUnits)
            return "--"
        const tempPart = `${Math.round(Weather.currentWeather.temperature)} ${Weather.currentWeatherUnits.temperature}`
        const descPart = I18n.tr(Weather.weatherDescriptionFromCode(Weather.currentWeather.weathercode))
        return ` ${descPart}, ${tempPart}`
    }
    color: Theme.textSecondary
    font.family: Theme.font
    font.pixelSize: 12
}