import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null
    property var allLines: []

    Process {
        id: catProcess
        command: ["sh", "-c", "cat " + pluginApi?.pluginSettings?.config]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.allLines.push(data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.allLines.length > 0) {
                var fullContent = root.allLines.join("\n");
                parseAndSave(fullContent);
                root.allLines = [];
            } else {
                saveToDb([
                    {
                        "title": pluginApi?.tr("panel.error_read_file") || "File read error",
                        "binds": [
                            {
                                "keys": "ERROR",
                                "desc": "Exit code: " + exitCode
                            }
                        ]
                    }
                ]);
            }
        }
    }

    onPluginApiChanged: {
        if (pluginApi) {
            pluginApi.mainInstance = root;
            checkAndGenerate();
        }
    }

    Component.onCompleted: {
        if (pluginApi) {
            pluginApi.mainInstance = root;
            checkAndGenerate();
        }
    }

    function checkAndGenerate() {
        if (!pluginApi?.pluginSettings?.cheatsheetData || pluginApi.pluginSettings.cheatsheetData.length === 0) {
            allLines = [];
            catProcess.running = true;
        }
    }

    function parseAndSave(text) {
        var lines = text.split('\n');
        var cats = [];
        var currentCat = null;

        function normalizeKey(key) {
            var k = key.trim();
            var low = k.toLowerCase();

            var map = {
                "escape": "ESCAPE",
                "return": "ENTER",
                "enter": "ENTER",
                "space": "SPACE",
                "tab": "TAB",
                "backspace": "BACKSPACE",
                "delete": "DELETE",
                "insert": "INSERT",
                "home": "HOME",
                "end": "END",
                "page_up": "PAGE UP",
                "page_down": "PAGE DOWN",
                "prior": "PAGE UP",
                "next": "PAGE DOWN",
                "left": "LEFT",
                "right": "RIGHT",
                "up": "UP",
                "down": "DOWN",
                "print": "PRINT",
                "kp_add": "KP ADD",
                "kp_subtract": "KP SUBTRACT",
                "kp_multiply": "KP MULTIPLY",
                "kp_divide": "KP DIVIDE",
                "kp_enter": "KP ENTER",
                "wheelscrollup": "WHEEL UP",
                "wheelscrolldown": "WHEEL DOWN",
                "wheelscrollleft": "WHEEL LEFT",
                "wheelscrollright": "WHEEL RIGHT",
                "mouseleft": "MOUSE LEFT",
                "mouseright": "MOUSE RIGHT",
                "mousemiddle": "MOUSE MIDDLE",
                "mouseback": "MOUSE BACK",
                "mouseforward": "MOUSE FORWARD"
            };

            if (map[low])
                return map[low];
            if (/^f\d+$/i.test(k))
                return k.toUpperCase();
            if (/^xf86/i.test(k))
                return k.toUpperCase();
            if (k.length === 1)
                return k.toUpperCase();
            return k.toUpperCase();
        }

        function parseCombo(combo) {
            var parts = combo.split('+').map(p => p.trim()).filter(p => p.length > 0);
            var mods = [];
            var key = "";

            for (var i = 0; i < parts.length; i++) {
                var p = parts[i].toLowerCase();
                if (p === "mod" || p === "super" || p === "meta" || p === "win") {
                    mods.push("Super");
                } else if (p === "shift") {
                    mods.push("Shift");
                } else if (p === "ctrl" || p === "control") {
                    mods.push("Ctrl");
                } else if (p === "alt") {
                    mods.push("Alt");
                } else {
                    key = parts[i];
                }
            }

            var order = ["Super", "Ctrl", "Alt", "Shift"];
            var uniq = [];
            for (var j = 0; j < order.length; j++) {
                if (mods.indexOf(order[j]) !== -1)
                    uniq.push(order[j]);
            }

            var fullKey = uniq.join(" + ");
            var normKey = key ? normalizeKey(key) : "";
            if (normKey)
                fullKey = fullKey ? fullKey + " + " + normKey : normKey;

            return fullKey;
        }

        function autoDesc(body) {
            var first = body.split(';')[0].trim();
            if (!first)
                return pluginApi?.tr("panel.no_description") || "No description";

            var actionMap = {
                "close-window": "Закрыть окно",
                "fullscreen-window": "Полный экран",
                "toggle-window-floating": "Плавающее окно",
                "focus-column-left": "Фокус влево",
                "focus-column-right": "Фокус вправо",
                "focus-window-up": "Фокус вверх",
                "focus-window-down": "Фокус вниз",
                "focus-workspace-up": "Раб. стол вверх",
                "focus-workspace-down": "Раб. стол вниз",
                "focus-workspace": "Переключиться на раб. стол",
                "move-column-to-workspace": "Окно на раб. стол"
            };

            var spawnMatch = first.match(/^spawn(?:-sh)?\s+["']([^"']+)["']/);
            if (spawnMatch) {
                var cmd = spawnMatch[1];
                var ipcMatch = cmd.match(/ipc"?\s+"call"?\s+"([^"]+)"\s+"([^"]+)"/);
                if (ipcMatch)
                    return "Открыть " + ipcMatch[1].replace("plugin:", "");

                var words = cmd.split(/\s+/);
                var bin = words[0].split('/').pop();
                return "Запустить " + bin;
            }

            var actionKey = first.split(/\s+/)[0];
            if (actionMap[actionKey]) {
                var arg = first.substring(actionKey.length).trim().replace(/^["']|["']$/g, "");
                if (arg)
                    return actionMap[actionKey] + " " + arg;
                return actionMap[actionKey];
            }

            return first;
        }

        function splitInlineComment(s) {
            var inStr = false;
            for (var i = 0; i < s.length - 1; i++) {
                var ch = s[i];
                if (inStr) {
                    if (ch === "\\") {
                        i++;
                        continue;
                    }
                    if (ch === '"') {
                        inStr = false;
                    }
                } else {
                    if (ch === '"') {
                        inStr = true;
                    } else if (ch === "/" && s[i + 1] === "/") {
                        return {
                            code: s.substring(0, i),
                            comment: s.substring(i + 2).trim()
                        };
                    }
                }
            }
            return {
                code: s,
                comment: null
            };
        }

        var i = 0;
        while (i < lines.length) {
            var rawLine = lines[i];
            var trimmed = rawLine.trim();

            if (trimmed.length === 0) {
                i++;
                continue;
            }

            if (/^binds\s*\{?\s*$/.test(trimmed) || trimmed === "}" || trimmed === "{") {
                i++;
                continue;
            }

            if (trimmed.startsWith("//")) {
                var c = trimmed.replace(/^\/\/\s*/, "").trim();
                if (c.length === 0 || /^[─=\-_*]+$/.test(c)) {
                    i++;
                    continue;
                }

                if (currentCat)
                    cats.push(currentCat);
                currentCat = {
                    "title": c,
                    "binds": []
                };
                i++;
                continue;
            }

            var splitFirst = splitInlineComment(trimmed);
            var code = splitFirst.code;
            var inlineComment = splitFirst.comment;

            var bindMatch = code.match(/^([^\{\}]+?)\s*(?:[a-z\-]+=[^\s\{]+\s*)*\{\s*(.*)$/);
            if (bindMatch) {
                var combo = bindMatch[1].trim();
                var rest = bindMatch[2];
                var body = rest;

                var depth = 1;
                var j = i;
                var openCount = (rest.match(/\{/g) || []).length;
                var closeCount = (rest.match(/\}/g) || []).length;
                depth = 1 + openCount - closeCount;

                while (depth > 0 && j + 1 < lines.length) {
                    j++;
                    var nextLine = lines[j];

                    if (!inlineComment) {
                        var splitNext = splitInlineComment(nextLine);
                        var codeNext = splitNext.code;
                        if (splitNext.comment !== null && /\}\s*$/.test(codeNext.trim())) {
                            inlineComment = splitNext.comment;
                            nextLine = codeNext;
                        }
                    }

                    body += "\n" + nextLine;
                    depth += (nextLine.match(/\{/g) || []).length;
                    depth -= (nextLine.match(/\}/g) || []).length;
                }

                body = body.replace(/^[^{]*\{/, "").replace(/\}\s*$/, "").trim();

                body = body.split('\n').map(function (l) {
                    return splitInlineComment(l).code;
                }).join('\n').trim();

                if (!combo || /^[a-z\-]+=$/.test(combo)) {
                    i = j + 1;
                    continue;
                }

                if (!currentCat) {
                    currentCat = {
                        "title": pluginApi?.tr("panel.other") || "Прочее",
                        "binds": []
                    };
                }

                var fullKey = parseCombo(combo);
                var desc = (inlineComment && inlineComment.length > 0) ? inlineComment : autoDesc(body);

                currentCat.binds.push({
                    "keys": fullKey,
                    "desc": desc
                });

                i = j + 1;
                continue;
            }

            i++;
        }

        if (currentCat && currentCat.binds.length > 0)
            cats.push(currentCat);

        if (cats.length > 0) {
            pluginApi.pluginSettings.cheatsheetData = cats;
            pluginApi.saveSettings();
        } else {
            if (pluginApi?.pluginSettings) {
                pluginApi.pluginSettings.cheatsheetData = [];
                pluginApi.saveSettings();
            }
        }
    }

    IpcHandler {
        target: "plugin:niri-cheatsheet"

        function toggle() {
            if (pluginApi) {
                pluginApi.pluginSettings.cheatsheetData = [];
                pluginApi.saveSettings();
                checkAndGenerate();
                pluginApi.withCurrentScreen(screen => {
                    pluginApi.openPanel(screen);
                });
            }
        }

        function refresh() {
            if (pluginApi) {
                pluginApi.pluginSettings.cheatsheetData = [];
                pluginApi.saveSettings();
                checkAndGenerate();
            }
        }
    }

    function getKeyColor(keyName) {
        if (keyName === "Super")
            return Color.mPrimary;
        if (keyName === "PRINT")
            return Color.mSecondary;
        if (["Alt", "Ctrl", "Shift", "ESCAPE", "ENTER", "TAB", "SPACE", "BACKSPACE", "DELETE"].includes(keyName))
            return Color.mTertiary;
        if (keyName.startsWith("F"))
            return Color.mTertiary;
        if (keyName.startsWith("XF86"))
            return Qt.lighter(Color.mTertiary, 1.2);
        if (keyName.match(/^[0-9]$/))
            return Qt.lighter(Color.mPrimary, 1.3);
        if (keyName.includes("MOUSE"))
            return Color.mSecondary;
        if (keyName.includes("WHEEL"))
            return Color.mSecondary;
        if (keyName.includes("ARROW"))
            return Qt.darker(Color.mTertiary, 1.1);
        if (keyName.includes("LEFT") || keyName.includes("RIGHT") || keyName.includes("UP") || keyName.includes("DOWN"))
            return Qt.darker(Color.mTertiary, 1.1);
        if (keyName.includes("PAGE"))
            return Qt.lighter(Color.mPrimary, 1.1);
        if (keyName.includes("HOME") || keyName.includes("END"))
            return Qt.lighter(Color.mTertiary, 1.1);
        if (keyName.includes("KP"))
            return Qt.lighter(Color.mTertiary, 1.1);
        return Qt.lighter(Color.mPrimary, 1.3);
    }

    function getCategoryIcon(categoryTitle) {
        var title = categoryTitle.toLowerCase();

        if (title.includes("меню"))
            return "menu";
        if (title.includes("приложения") || title.includes("приложение"))
            return "apps-filled";
        if (title.includes("система"))
            return "settings-filled";
        if (title.includes("окна") || title.includes("окно"))
            return "brand-windows-filled";
        if (title.includes("фокус"))
            return "focus";
        if (title.includes("мышь") || title.includes("mouse"))
            return "mouse-filled";
        if (title.includes("рабочие") || title.includes("workspace"))
            return "circle-dot-filled";
        if (title.includes("перемещение"))
            return "arrows-move-horizontal";
        if (title.includes("скриншот") || title.includes("screenshot"))
            return "screenshot";
        if (title.includes("громкость") || title.includes("volume"))
            return "volume";
        if (title.includes("медиа") || title.includes("media"))
            return "player-play-filled";

        return "keyboard-filled";
    }

    function refreshData() {
        pluginApi.pluginSettings.cheatsheetData = [];
        pluginApi.saveSettings();
        checkAndGenerate();
    }
}
