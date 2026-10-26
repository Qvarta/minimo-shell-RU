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

    property string stateFile: cacheDir ? cacheDir + "state.json" : ""
    property int weatherUpdateFrequency: 30 * 60 // 30 minutes expressed in seconds
    property bool isFetchingWeather: false
    property int requestGeneration: 0

    // Прогноз и координаты хранятся только в памяти.
    property var weather: null
    property bool loadingState: false
    property bool stateFileLoadFailed: false

    readonly property alias data: adapter
    readonly property alias location: adapter
    // Expose the configured city name for WeatherView.qml (`Weather.name`).
    property alias name: adapter.name
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
    // state.json — сохраняем только имя города в ключе weather.name.
    // Остальные настройки оболочки сохраняются при обновлении файла.
    QtObject {
        id: adapter
        property string name: "Москва"
        property bool weatherEnabled: true
        property string latitude: ""
        property string longitude: ""
        property string resolvedName: ""
        property int weatherLastFetch: 0

        onNameChanged: {
            if (!root.loadingState)
                saveTimer.start();
        }
    }

    FileView {
        id: stateFileView
        path: root.stateFile
        printErrors: false
        watchChanges: true

        onLoaded: {
            root.stateFileLoadFailed = false;
            root.loadCityFromState();
        }
        onLoadFailed: {
            root.stateFileLoadFailed = true;
            root.loadingState = true;
            adapter.name = "Москва";
            root.loadingState = false;
            root.saveCityName();
            root.update();
        }
        onFileChanged: reload()
    }

    function loadCityFromState() {
        var state = {};
        const raw = stateFileView.text();

        if (raw.trim() !== "") {
            try {
                state = JSON.parse(raw);
                if (!state || typeof state !== "object" || Array.isArray(state))
                    throw new Error("state.json root must be an object");
            } catch (e) {
                console.error("[Weather] Cannot parse state.json:", e);
                // Не перезаписываем существующий файл с повреждённым JSON.
                root.loadingState = true;
                adapter.name = "Москва";
                root.loadingState = false;
                root.update();
                return;
            }
        }

        const savedCity = state.weather && typeof state.weather.name === "string"
            ? state.weather.name.trim() : "";

        root.loadingState = true;
        adapter.name = savedCity !== "" ? savedCity : "Москва";
        root.loadingState = false;

        if (savedCity === "")
            root.saveCityName();

        root.update();
    }

    function saveCityName() {
        if (!root.stateFile || (!stateFileView.loaded && !root.stateFileLoadFailed))
            return;

        var state = {};
        const raw = stateFileView.loaded ? stateFileView.text() : "";

        if (raw.trim() !== "") {
            try {
                state = JSON.parse(raw);
                if (!state || typeof state !== "object" || Array.isArray(state))
                    throw new Error("state.json root must be an object");
            } catch (e) {
                console.error("[Weather] Refusing to overwrite invalid state.json:", e);
                return;
            }
        }

        // Persist only the city name; do not persist coordinates, forecast or cache.
        state.weather = { name: adapter.name };
        stateFileView.setText(JSON.stringify(state, null, 2) + "\n");
    }

    // Change the configured city, persist it, and immediately refresh geocoding/weather.
    function setCity(cityName) {
        const city = String(cityName || "").trim()
        if (city === "") return false

        root.requestGeneration += 1
        saveTimer.stop()
        adapter.name = city
        adapter.latitude = ""
        adapter.longitude = ""
        adapter.resolvedName = ""
        adapter.weatherLastFetch = 0
        root.weather = null
        root.coordinatesReady = false
        root.stableLatitude = ""
        root.stableLongitude = ""
        root.stableName = ""
        root.isFetchingWeather = false
        saveTimer.stop()

        root.saveCityName()
        root.update()
        return true
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
        onTriggered: root.saveCityName()
    }

    Component.onCompleted: {
        console.info("[Weather] The service is running");
    }

    function init() {
        // no-op
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

        const requestedCity = adapter.name;
        const requestId = root.requestGeneration;
        geocodeLocation(requestedCity, requestId, function (latitude, longitude, name, country) {
            // Ignore a response for a city that was changed while the request was running.
            if (requestId !== root.requestGeneration || requestedCity !== adapter.name)
                return;

            adapter.resolvedName = requestedCity;
            adapter.latitude = latitude.toString();
            adapter.longitude = longitude.toString();
            root.stableLatitude = adapter.latitude;
            root.stableLongitude = adapter.longitude;
            root.stableName = `${name}, ${country}`;
            root.coordinatesReady = true;

            isFetchingWeather = false;
            root.updateWeatherData();
        }, function (module, message) {
            if (requestId === root.requestGeneration)
                errorCallback(module, message);
        });
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
            const requestId = root.requestGeneration;
            fetchWeatherData(adapter.latitude, adapter.longitude, requestId, function (module, message) {
                if (requestId === root.requestGeneration)
                    errorCallback(module, message);
            });
        }
    }

    // Query geocoding API to convert location name to coordinates
    function geocodeLocation(locationName, requestId, callback, errorCallback) {
        var geoUrl = "https://api.noctalia.dev/geocode?city=" + encodeURIComponent(locationName);
        var xhr = new XMLHttpRequest();
        var startedAt = Date.now();
        var networkFailureLogged = false;

        function logNetworkFailure(source) {
            if (networkFailureLogged)
                return;
            networkFailureLogged = true;
            console.warn("[Weather][geocode] network failure (" + source
                         + "), requestId=" + requestId
                         + ", status=" + xhr.status
                         + ", readyState=" + xhr.readyState
                         + ", elapsedMs=" + (Date.now() - startedAt));
        }

        console.info("[Weather][geocode] request started, requestId=" + requestId
                     + ", endpoint=api.noctalia.dev");

        xhr.onerror = function () {
            logNetworkFailure("onerror");
            if (requestId === root.requestGeneration)
                isFetchingWeather = false;
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            console.info("[Weather][geocode] request finished, requestId=" + requestId
                         + ", status=" + xhr.status
                         + ", elapsedMs=" + (Date.now() - startedAt));

            if (requestId !== root.requestGeneration) {
                console.warn("[Weather][geocode] ignoring stale response, requestId=" + requestId
                             + ", currentGeneration=" + root.requestGeneration);
                return;
            }
            if (xhr.status === 0) {
                logNetworkFailure("DONE/status 0");
                isFetchingWeather = false;
                return;
            }
            if (xhr.status === 200) {
                try {
                    var geoData = JSON.parse(xhr.responseText);
                    if (geoData.lat != null) {
                        console.info("[Weather][geocode] response parsed successfully, requestId=" + requestId);
                        callback(geoData.lat, geoData.lng, geoData.name, geoData.country);
                    } else {
                        console.warn("[Weather][geocode] response has no coordinates, requestId=" + requestId);
                        errorCallback("Location", "could not resolve location name");
                    }
                } catch (e) {
                    console.error("[Weather][geocode] response parse failed, requestId=" + requestId + ":", e);
                    errorCallback("Location", "Failed to parse geocoding data: " + e);
                }
            } else {
                console.warn("[Weather][geocode] HTTP error, requestId=" + requestId
                             + ", status=" + xhr.status);
                errorCallback("Location", "Geocoding error: " + xhr.status);
            }
        };
        xhr.open("GET", geoUrl);
        xhr.send();
    }

    // Fetch weather data from Open-Meteo API
    function fetchWeatherData(latitude, longitude, requestId, errorCallback) {
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude + "&current_weather=true&current=relativehumidity_2m,surface_pressure,is_day&daily=temperature_2m_max,temperature_2m_min,weathercode,sunset,sunrise,wind_direction_10m_dominant,wind_speed_10m_max,relative_humidity_2m_mean,surface_pressure_mean&timezone=auto&wind_speed_unit=ms";
        var xhr = new XMLHttpRequest();
        var startedAt = Date.now();
        var networkFailureLogged = false;

        function logNetworkFailure(source) {
            if (networkFailureLogged)
                return;
            networkFailureLogged = true;
            console.warn("[Weather][forecast] network failure (" + source
                         + "), requestId=" + requestId
                         + ", status=" + xhr.status
                         + ", readyState=" + xhr.readyState
                         + ", elapsedMs=" + (Date.now() - startedAt));
        }

        console.info("[Weather][forecast] request started, requestId=" + requestId
                     + ", endpoint=api.open-meteo.com");

        xhr.onerror = function () {
            logNetworkFailure("onerror");
            if (requestId === root.requestGeneration)
                isFetchingWeather = false;
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            console.info("[Weather][forecast] request finished, requestId=" + requestId
                         + ", status=" + xhr.status
                         + ", elapsedMs=" + (Date.now() - startedAt));

            if (requestId !== root.requestGeneration) {
                console.warn("[Weather][forecast] ignoring stale response, requestId=" + requestId
                             + ", currentGeneration=" + root.requestGeneration);
                return;
            }
            if (xhr.status === 0) {
                logNetworkFailure("DONE/status 0");
                isFetchingWeather = false;
                return;
            }
            if (xhr.status === 200) {
                var text = xhr.responseText || "";
                try {
                    var weatherData = JSON.parse(text);

                    if (weatherData.latitude == null || weatherData.longitude == null) {
                        console.warn("[Weather][forecast] response missing coordinates, requestId=" + requestId);
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
                    console.info("[Weather][forecast] response parsed successfully, requestId=" + requestId);
                } catch (e) {
                    console.error("[Weather][forecast] response parse failed, requestId=" + requestId + ":", e);
                    errorCallback("Location", "Failed to parse weather data: " + e + " | raw: " + text.slice(0, 200));
                }
            } else {
                console.warn("[Weather][forecast] HTTP error, requestId=" + requestId
                             + ", status=" + xhr.status);
                errorCallback("Location", "Weather fetch error: " + xhr.status + " | raw: " + (xhr.responseText || "").slice(0, 200));
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
    // Returns an English i18n key; I18n.tr() translates it for the selected language.
    function weatherDescriptionFromCode(code) {
        if (code === 0)
            return "Clear sky";
        if (code === 1)
            return "Mostly clear";
        if (code === 2)
            return "Partly cloudy";
        if (code === 3)
            return "Cloudy";
        if (code === 45 || code === 48)
            return "Fog";
        if (code >= 51 && code <= 57)
            return "Drizzle";
        if (code >= 61 && code <= 67)
            return "Rain";
        if (code >= 71 && code <= 77)
            return "Snow";
        if (code >= 80 && code <= 82)
            return "Rain showers";
        if (code >= 85 && code <= 86)
            return "Snow showers";
        if (code >= 95 && code <= 99)
            return "Thunderstorm";
        return "Unknown";
    }

    // --------------------------------
    function celsiusToFahrenheit(celsius) {
        return 32 + celsius * 1.8;
    }
}