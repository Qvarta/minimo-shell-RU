// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
.pragma library

// Чистый JS-парсер конфигурации клавиш niri (без QML-типов, работает в любой
// контексте). Логика перенесена из плагина niri-cheatsheet (Main.qml): разбор
// категорий (комментарии-заголовки //), биндов и нормализация названий клавиш.
// Возвращает массив категорий [{ title, binds: [{ keys: "Super + A", desc }] }].

// Приводит название клавиши к читаемому виду (Escape -> ESCAPE, page_up -> PAGE UP).
function normalizeKey(key) {
    const k = key.trim();
    const low = k.toLowerCase();

    const map = {
        "escape": "ESCAPE", "return": "ENTER", "enter": "ENTER", "space": "SPACE",
        "tab": "TAB", "backspace": "BACKSPACE", "delete": "DELETE", "insert": "INSERT",
        "home": "HOME", "end": "END", "page_up": "PAGE UP", "page_down": "PAGE DOWN",
        "prior": "PAGE UP", "next": "PAGE DOWN", "left": "LEFT", "right": "RIGHT",
        "up": "UP", "down": "DOWN", "print": "PRINT", "kp_add": "KP ADD",
        "kp_subtract": "KP SUBTRACT", "kp_multiply": "KP MULTIPLY", "kp_divide": "KP DIVIDE",
        "kp_enter": "KP ENTER", "wheelscrollup": "WHEEL UP", "wheelscrolldown": "WHEEL DOWN",
        "wheelscrollleft": "WHEEL LEFT", "wheelscrollright": "WHEEL RIGHT",
        "mouseleft": "MOUSE LEFT", "mouseright": "MOUSE RIGHT", "mousemiddle": "MOUSE MIDDLE",
        "mouseback": "MOUSE BACK", "mouseforward": "MOUSE FORWARD"
    };

    if (map[low]) return map[low];
    if (/^f\d+$/i.test(k)) return k.toUpperCase();
    if (/^xf86/i.test(k)) return k.toUpperCase();
    if (k.length === 1) return k.toUpperCase();
    return k.toUpperCase();
}

// Собирает человекочитаемую комбинацию: модификаторы в порядке Super, Ctrl, Alt, Shift,
// затем основная клавиша ("mod+Shift+a" -> "Super + Shift + A").
function parseCombo(combo) {
    const parts = combo.split('+').map(p => p.trim()).filter(p => p.length > 0);
    let mods = [];
    let key = "";

    for (const p of parts) {
        const q = p.toLowerCase();
        if (q === "mod" || q === "super" || q === "meta" || q === "win") mods.push("Super");
        else if (q === "shift") mods.push("Shift");
        else if (q === "ctrl" || q === "control") mods.push("Ctrl");
        else if (q === "alt") mods.push("Alt");
        else key = p;
    }

    const order = ["Super", "Ctrl", "Alt", "Shift"];
    const uniq = order.filter(m => mods.includes(m));

    let fullKey = uniq.join(" + ");
    const normKey = key ? normalizeKey(key) : "";
    if (normKey) fullKey = fullKey ? fullKey + " + " + normKey : normKey;

    return fullKey;
}

// Описание действия по телу бинда (когда в конфиге нет комментария //).
function autoDesc(body) {
    const first = body.split(';')[0].trim();
    if (!first) return "Нет описания";

    const actionMap = {
        "close-window": "Закрыть окно", "fullscreen-window": "Полный экран",
        "toggle-window-floating": "Плавающее окно", "focus-column-left": "Фокус влево",
        "focus-column-right": "Фокус вправо", "focus-window-up": "Фокус вверх",
        "focus-window-down": "Фокус вниз", "focus-workspace-up": "Раб. стол вверх",
        "focus-workspace-down": "Раб. стол вниз", "focus-workspace": "Переключиться на раб. стол",
        "move-column-to-workspace": "Окно на раб. стол"
    };

    const spawnMatch = first.match(/^spawn(?:-sh)?\s+["']([^"']+)["']/);
    if (spawnMatch) {
        const cmd = spawnMatch[1];
        const ipcMatch = cmd.match(/ipc"?\s+"call"?\s+"([^"]+)"\s+"([^"]+)"/);
        if (ipcMatch) return "Открыть " + ipcMatch[1].replace("plugin:", "");
        const bin = cmd.split(/\s+/)[0].split('/').pop();
        return "Запустить " + bin;
    }

    const actionKey = first.split(/\s+/)[0];
    if (actionMap[actionKey]) {
        const arg = first.substring(actionKey.length).trim().replace(/^["']|["']$/g, "");
        return arg ? actionMap[actionKey] + " " + arg : actionMap[actionKey];
    }

    return first;
}

// Разделяет строку на код и инлайн-комментарий "// ...", не трогая строки в кавычках.
function splitInlineComment(s) {
    let inStr = false;
    for (let i = 0; i < s.length - 1; i++) {
        const ch = s[i];
        if (inStr) {
            if (ch === "\\") { i++; continue; }
            if (ch === '"') inStr = false;
        } else {
            if (ch === '"') inStr = true;
            else if (ch === "/" && s[i + 1] === "/") {
                return { code: s.substring(0, i), comment: s.substring(i + 2).trim() };
            }
        }
    }
    return { code: s, comment: null };
}

// Основной парсер: текст конфига niri -> массив категорий с биндами.
function parse(text) {
    const lines = text.split('\n');
    const cats = [];
    let currentCat = null;

    let i = 0;
    while (i < lines.length) {
        const trimmed = lines[i].trim();

        if (trimmed.length === 0) { i++; continue; }

        // Пропускаем обрамление секции binds { ... }.
        if (/^binds\s*\{?\s*$/.test(trimmed) || trimmed === "}" || trimmed === "{") { i++; continue; }

        // Комментарий-заголовок = новая категория.
        if (trimmed.startsWith("//")) {
            const c = trimmed.replace(/^\/\/\s*/, "").replace(/^[─=\-*_]+/, "").replace(/[─=\-*_]+$/, "").trim();
            if (c.length === 0 || /^[─=\-*_]+$/.test(c)) { i++; continue; }
            if (currentCat) cats.push(currentCat);
            currentCat = { title: c, binds: [] };
            i++;
            continue;
        }

        const splitFirst = splitInlineComment(trimmed);
        const code = splitFirst.code;
        let inlineComment = splitFirst.comment;

        // Строка вида: mod+Key { action... }
        const bindMatch = code.match(/^[^\{\}]+?\s*(?:[a-z\-]+=[^\s\{]+\s*)*\{\s*(.*)$/);
        if (bindMatch) {
            const combo = code.replace(/\{[\s\S]*$/, "").trim();
            let body = bindMatch[1];

            // Дочитываем многострочное тело бинда до закрывающей скобки.
            let depth = 1 + (body.match(/\{/g) || []).length - (body.match(/\}/g) || []).length;
            let j = i;
            while (depth > 0 && j + 1 < lines.length) {
                j++;
                let nextLine = lines[j];
                if (!inlineComment) {
                    const splitNext = splitInlineComment(nextLine);
                    if (splitNext.comment !== null && /\}\s*$/.test(splitNext.code.trim())) {
                        inlineComment = splitNext.comment;
                        nextLine = splitNext.code;
                    }
                }
                body += "\n" + nextLine;
                depth += (nextLine.match(/\{/g) || []).length;
                depth -= (nextLine.match(/\}/g) || []).length;
            }

            body = body.replace(/^[^{]*\{/, "").replace(/\}\s*$/, "").trim();
            body = body.split('\n').map(l => splitInlineComment(l).code).join('\n').trim();

            if (!combo || /^[a-z\-]+=$/.test(combo)) { i = j + 1; continue; }

            if (!currentCat) {
                currentCat = { title: "Прочее", binds: [] };
            }

            currentCat.binds.push({
                keys: parseCombo(combo),
                desc: (inlineComment && inlineComment.length > 0) ? inlineComment : autoDesc(body)
            });

            i = j + 1;
            continue;
        }

        i++;
    }

    if (currentCat && currentCat.binds.length > 0) cats.push(currentCat);
    return cats;
}
