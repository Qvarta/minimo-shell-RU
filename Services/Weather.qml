pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Location and weather service with decoupled geocoding and weather fetching.
Singleton {
    id: root

    readonly property string cacheDir: {
        const home = Quickshell.env("HOME") || "";
        return home ? home + "/.config/minimo-os/" : "";
    }

    property string locationFile: cacheDir ? cacheDir + "location.json" : ""
    property int weatherUpdateFrequency: 30 * 60 // 30 minutes expressed in seconds
    property bool isFetchingWeather: false

    // Погода живёт только в памяти — в location.json не пишется
    property var weather: null

    readonly property alias data: adapter
    readonly property alias location: adapter
    readonly property bool weatherEnabled: adapter.weatherEnabled

    // ------------------------------------------------------------------
    // Безопасные геттеры для UI — возвращают null/"" пока данных нет
    // ------------------------------------------------------------------
    readonly property var currentWeather: {
        const w = root.weather;
        return (w && w.current_weather) ? w.current_weather : null;
    }

    readonly property var currentWeatherUnits: {
        const w = root.weather;
        return (w && w.current_weather_units) ? w.current_weather_units : null;
    }

    readonly property var current: {
        const w = root.weather;
        return (w && w.current) ? w.current : null;
    }

    readonly property var currentUnits: {
        const w = root.weather;
        return (w && w.current_units) ? w.current_units : null;
    }

    readonly property var daily: {
        const w = root.weather;
        return (w && w.daily) ? w.daily : null;
    }

    readonly property var dailyUnits: {
        const w = root.weather;
        return (w && w.daily_units) ? w.daily_units : null;
    }

    readonly property bool hasWeather: currentWeather !== null && currentWeatherUnits !== null
    readonly property bool hasDaily: daily !== null && dailyUnits !== null

    // Stable UI properties - only updated when location is successfully geocoded
    property bool coordinatesReady: false
    property string stableLatitude: ""
    property string stableLongitude: ""
    property string stableName: ""

    // ------------------------------------------------------------------
    // location.json — конфиг + лёгкий кэш (без weather)
    // ------------------------------------------------------------------
    FileView {
        id: locationFileView
        path: root.locationFile
        printErrors: false
        onAdapterUpdated: saveTimer.start()
        onLoaded: {
            // Если файл был пустым/без ключевых полей — заполняем дефолтами
            if (adapter.name === "") {
                writeDefaultLocation();
                return;
            }

            if (adapter.latitude !== "" && adapter.longitude !== "" && adapter.weatherLastFetch > 0) {
                root.stableLatitude = adapter.latitude;
                root.stableLongitude = adapter.longitude;
                root.stableName = adapter.resolvedName;
                root.coordinatesReady = true;
            }
            update();
        }
        onLoadFailed: function (error) {
            writeDefaultLocation();
        }

        JsonAdapter {
            id: adapter
            property string name: ""
            property bool weatherEnabled: true
            property string latitude: ""
            property string longitude: ""
            property string resolvedName: ""
            property int weatherLastFetch: 0
            // weather здесь больше нет — не пишется в файл
        }
    }

    // Formatted coordinates for UI display
    readonly property string displayCoordinates: {
        if (!root.coordinatesReady || root.stableLatitude === "" || root.stableLongitude === "") {
            return "";
        }
        const lat = parseFloat(root.stableLatitude).toFixed(4);
        const lon = parseFloat(root.stableLongitude).toFixed(4);
        return `${lat}, ${lon}`;
    }

    // Update timer runs when weather is enabled
    Timer {
        id: updateTimer
        interval: 20 * 1000
        running: root.weatherEnabled
        repeat: true
        onTriggered: {
            update();
        }
    }

    Timer {
        id: saveTimer
        running: false
        interval: 1000
        onTriggered: locationFileView.writeAdapter()
    }

    Component.onCompleted: {
        console.info("[Weather] The service is running");
    }

    function init() {
        // no-op
    }

    // Запись дефолтного location.json, если файла не было
    function writeDefaultLocation() {
        adapter.name = "Москва";
        adapter.weatherEnabled = true;
        adapter.latitude = "";
        adapter.longitude = "";
        adapter.resolvedName = "";
        adapter.weatherLastFetch = 0;
        root.weather = null;
        locationFileView.writeAdapter();
        update();
    }

    function resetWeather() {
        root.coordinatesReady = false;
        root.stableLatitude = "";
        root.stableLongitude = "";
        root.stableName = "";

        adapter.latitude = "";
        adapter.longitude = "";
        adapter.resolvedName = "";
        adapter.weatherLastFetch = 0;
        root.weather = null;
        update();
    }

    // Main update function - geocodes location if needed, then fetches weather if enabled
    function update() {
        updateLocation();

        if (root.weatherEnabled) {
            updateWeatherData();
        }
    }

    // Runs independently of weather toggle
    function updateLocation() {
        const locationChanged = adapter.resolvedName !== adapter.name;
        const needsGeocoding = (adapter.latitude === "") || (adapter.longitude === "") || locationChanged;

        if (!needsGeocoding) {
            return;
        }

        if (isFetchingWeather) {
            return;
        }

        isFetchingWeather = true;

        if (locationChanged) {
            root.coordinatesReady = false;
        }

        geocodeLocation(adapter.name, function (latitude, longitude, name, country) {
            adapter.resolvedName = adapter.name;
            adapter.latitude = latitude.toString();
            adapter.longitude = longitude.toString();
            root.stableLatitude = adapter.latitude;
            root.stableLongitude = adapter.longitude;
            root.stableName = `${name}, ${country}`;
            root.coordinatesReady = true;

            isFetchingWeather = false;
        }, errorCallback);
    }

    // Fetch weather data if enabled and coordinates are available
    function updateWeatherData() {
        if (!root.weatherEnabled) {
            return;
        }

        if (isFetchingWeather) {
            return;
        }

        if (adapter.latitude === "" || adapter.longitude === "") {
            return;
        }

        const nowSec = Math.floor(Date.now() / 1000);
        const needsWeatherUpdate = (adapter.weatherLastFetch === 0) || (root.weather === null) || (nowSec >= adapter.weatherLastFetch + weatherUpdateFrequency);

        if (needsWeatherUpdate) {
            isFetchingWeather = true;
            fetchWeatherData(adapter.latitude, adapter.longitude, errorCallback);
        }
    }

    // Query geocoding API to convert location name to coordinates
    function geocodeLocation(locationName, callback, errorCallback) {
        var geoUrl = "https://api.noctalia.dev/geocode?city=" + encodeURIComponent(locationName);
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var geoData = JSON.parse(xhr.responseText);
                        if (geoData.lat != null) {
                            callback(geoData.lat, geoData.lng, geoData.name, geoData.country);
                        } else {
                            errorCallback("Location", "could not resolve location name");
                        }
                    } catch (e) {
                        errorCallback("Location", "Failed to parse geocoding data: " + e);
                    }
                } else {
                    errorCallback("Location", "Geocoding error: " + xhr.status);
                }
            }
        };
        xhr.open("GET", geoUrl);
        xhr.send();
    }

    // Fetch weather data from Open-Meteo API
    function fetchWeatherData(latitude, longitude, errorCallback) {
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude + "&current_weather=true&current=relativehumidity_2m,surface_pressure,is_day&daily=temperature_2m_max,temperature_2m_min,weathercode,sunset,sunrise,wind_direction_10m_dominant,wind_speed_10m_max,relative_humidity_2m_mean,surface_pressure_mean&timezone=auto&wind_speed_unit=ms";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var text = xhr.responseText || "";
                    try {
                        var weatherData = JSON.parse(text);

                        if (weatherData.latitude == null || weatherData.longitude == null) {
                            errorCallback("Location", "Unexpected weather payload: " + text.slice(0, 200));
                            return;
                        }

                        // Save core data — только в памяти
                        root.weather = weatherData;
                        adapter.weatherLastFetch = Math.floor(Date.now() / 1000);

                        // Update stable display values only when complete and successful
                        root.stableLatitude = weatherData.latitude.toString();
                        root.stableLongitude = weatherData.longitude.toString();
                        adapter.latitude = root.stableLatitude;
                        adapter.longitude = root.stableLongitude;
                        root.coordinatesReady = true;

                        isFetchingWeather = false;
                    } catch (e) {
                        errorCallback("Location", "Failed to parse weather data: " + e + " | raw: " + text.slice(0, 200));
                    }
                } else {
                    errorCallback("Location", "Weather fetch error: " + xhr.status + " | raw: " + (xhr.responseText || "").slice(0, 200));
                }
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // --------------------------------
    function errorCallback(module, message) {
        console.error(module, message);
        isFetchingWeather = false;
    }

    // --------------------------------
    function weatherSymbolFromCode(code, isDay) {
        // Ясно
        if (code === 0)
            return isDay ? "clear-day" : "clear-night";

        // Переменная облачность
        if (code === 1 || code === 2)
            return isDay ? "partly-cloudy-day" : "partly-cloudy-night";

        // Пасмурно
        if (code === 3)
            return "cloudy";

        // Туман
        if (code >= 45 && code <= 48)
            return "fog";

        // Дождь / Ливень
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "rain";

        // Снег
        if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86))
            return "snow";

        // Гроза
        if (code >= 95 && code <= 99)
            return "thunderstorm";

        // По умолчанию (включая 68-70, слякоть)
        return "cloudy";
    }

    // --------------------------------
    // Devuelve la clave i18n en español (idioma de origen). I18n.tr() la traduce a cada idioma.
    function weatherDescriptionFromCode(code) {
        if (code === 0)
            return "Despejado";
        if (code === 1)
            return "Mayormente despejado";
        if (code === 2)
            return "Parcialmente nublado";
        if (code === 3)
            return "Nublado";
        if (code === 45 || code === 48)
            return "Niebla";
        if (code >= 51 && code <= 57)
            return "Llovizna";
        if (code >= 61 && code <= 67)
            return "Lluvia";
        if (code >= 71 && code <= 77)
            return "Nieve";
        if (code >= 80 && code <= 82)
            return "Chubascos";
        if (code >= 85 && code <= 86)
            return "Chubascos de nieve";
        if (code >= 95 && code <= 99)
            return "Tormenta eléctrica";
        return "Desconocido";
    }

    // --------------------------------
    function celsiusToFahrenheit(celsius) {
        return 32 + celsius * 1.8;
    }
}