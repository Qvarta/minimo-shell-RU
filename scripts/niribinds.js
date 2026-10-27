// SPDX-License-Identifier: MIT
.pragma library

// Public output contract: [{ title: string, binds: [{ keys: string, desc: string }] }]
function normalizeKey(key) {
    const value = key.trim();
    const names = {
        escape:"ESCAPE", return:"ENTER", enter:"ENTER", space:"SPACE", tab:"TAB",
        backspace:"BACKSPACE", delete:"DELETE", insert:"INSERT", home:"HOME", end:"END",
        page_up:"PAGE UP", page_down:"PAGE DOWN", prior:"PAGE UP", next:"PAGE DOWN",
        left:"LEFT", right:"RIGHT", up:"UP", down:"DOWN", print:"PRINT",
        kp_add:"KP ADD", kp_subtract:"KP SUBTRACT", kp_multiply:"KP MULTIPLY",
        kp_divide:"KP DIVIDE", kp_enter:"KP ENTER", wheelscrollup:"WHEEL UP",
        wheelscrolldown:"WHEEL DOWN", wheelscrollleft:"WHEEL LEFT", wheelscrollright:"WHEEL RIGHT",
        mouseleft:"MOUSE LEFT", mouseright:"MOUSE RIGHT", mousemiddle:"MOUSE MIDDLE",
        mouseback:"MOUSE BACK", mouseforward:"MOUSE FORWARD"
    };
    return names[value.toLowerCase()] || value.toUpperCase();
}

function parseCombo(combo) {
    const parts = combo.split("+").map(p => p.trim()).filter(p => p.length > 0);
    const modifiers = [];
    let key = "";
    for (let i = 0; i < parts.length; i++) {
        const part = parts[i].toLowerCase();
        if (["mod", "super", "meta", "win"].indexOf(part) >= 0) modifiers.push("Super");
        else if (part === "shift") modifiers.push("Shift");
        else if (part === "ctrl" || part === "control") modifiers.push("Ctrl");
        else if (part === "alt") modifiers.push("Alt");
        else key = parts[i];
    }
    const ordered = [];
    const order = ["Super", "Ctrl", "Alt", "Shift"];
    for (let i = 0; i < order.length; i++)
        if (modifiers.indexOf(order[i]) >= 0) ordered.push(order[i]);
    if (key) ordered.push(normalizeKey(key));
    return ordered.join(" + ");
}

function isSpace(ch) {
    return ch === " " || ch === "\t" || ch === "\n" || ch === "\r";
}

function splitInlineComment(line) {
    let quote = "";
    for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (quote) {
            if (ch === "\\" && i + 1 < line.length) i++;
            else if (ch === quote) quote = "";
        } else if (ch === '"' || ch === "'") quote = ch;
        else if (ch === "/" && line[i + 1] === "/")
            return { code: line.substring(0, i), comment: line.substring(i + 2).trim() };
    }
    return { code: line, comment: null };
}

function extractBlock(source, name) {
    let open = -1, quote = "", comment = false;
    for (let i = 0; i < source.length; i++) {
        const ch = source[i];
        if (comment) { if (ch === "\n") comment = false; continue; }
        if (quote) {
            if (ch === "\\" && i + 1 < source.length) i++;
            else if (ch === quote) quote = "";
            continue;
        }
        if (ch === '"' || ch === "'") { quote = ch; continue; }
        if (ch === "/" && source[i + 1] === "/") { comment = true; i++; continue; }
        if (source.substr(i, name.length) !== name) continue;
        const before = i === 0 ? "" : source[i - 1];
        const after = source[i + name.length] || "";
        if (!(i === 0 || isSpace(before) || before === "{")) continue;
        if (!(after === "" || isSpace(after) || after === "{")) continue;
        let cursor = i + name.length;
        while (cursor < source.length && isSpace(source[cursor])) cursor++;
        if (source[cursor] === "{") { open = cursor; break; }
    }
    if (open < 0) return null;

    let depth = 0;
    quote = ""; comment = false;
    for (let i = open; i < source.length; i++) {
        const ch = source[i];
        if (comment) { if (ch === "\n") comment = false; continue; }
        if (quote) {
            if (ch === "\\" && i + 1 < source.length) i++;
            else if (ch === quote) quote = "";
            continue;
        }
        if (ch === '"' || ch === "'") quote = ch;
        else if (ch === "/" && source[i + 1] === "/") { comment = true; i++; }
        else if (ch === "{") depth++;
        else if (ch === "}" && --depth === 0) return source.substring(open + 1, i);
    }
    return null;
}

function tokenize(source) {
    const result = [];
    let token = "", quote = "", active = false;
    for (let i = 0; i < source.length; i++) {
        const ch = source[i];
        if (quote) {
            if (ch === "\\" && i + 1 < source.length) { token += source[++i]; }
            else if (ch === quote) quote = "";
            else token += ch;
            active = true;
        } else if (ch === '"' || ch === "'") { quote = ch; active = true; }
        else if (isSpace(ch)) {
            if (active) result.push(token);
            token = ""; active = false;
        } else { token += ch; active = true; }
    }
    if (active) result.push(token);
    return result;
}

function actionDescription(body) {
    const first = body.split(";")[0].trim();
    if (!first) return "Нет описания";
    const descriptions = {
        "close-window":"Закрыть окно", "fullscreen-window":"Полный экран",
        "toggle-window-floating":"Плавающее окно", "focus-column-left":"Фокус влево",
        "focus-column-right":"Фокус вправо", "focus-window-up":"Фокус вверх",
        "focus-window-down":"Фокус вниз", "focus-window-or-workspace-up":"Фокус вверх",
        "focus-window-or-workspace-down":"Фокус вниз", "focus-workspace-up":"Раб. стол вверх",
        "focus-workspace-down":"Раб. стол вниз", "focus-workspace":"Переключиться на раб. стол",
        "move-column-to-workspace":"Окно на раб. стол"
    };
    const tokens = tokenize(first);
    if (!tokens.length) return "Нет описания";
    if (tokens[0] === "spawn" || tokens[0] === "spawn-sh") {
        const command = tokens[1] || "";
        for (let i = 0; i + 2 < tokens.length; i++)
            if (tokens[i] === "ipc" && tokens[i + 1] === "call")
                return "Открыть " + tokens[i + 2].replace("plugin:", "");
        const parts = command.split("/");
        return "Запустить " + (parts[parts.length - 1] || command || "команду");
    }
    if (descriptions[tokens[0]])
        return tokens.length > 1 ? descriptions[tokens[0]] + " " + tokens[1] : descriptions[tokens[0]];
    return first;
}

function braceDelta(source) {
    let delta = 0, quote = "";
    for (let i = 0; i < source.length; i++) {
        const ch = source[i];
        if (quote) {
            if (ch === "\\" && i + 1 < source.length) i++;
            else if (ch === quote) quote = "";
        } else if (ch === '"' || ch === "'") quote = ch;
        else if (ch === "/" && source[i + 1] === "/") break;
        else if (ch === "{") delta++;
        else if (ch === "}") delta--;
    }
    return delta;
}

function isBindingHeader(code) {
    const open = code.indexOf("{");
    return open > 0 && (code.indexOf("}") < 0 || code.indexOf("}") > open);
}

function bindingCombo(header) {
    const name = header.substring(0, header.indexOf("{")).trim();
    const words = [];
    let word = "";
    for (let i = 0; i <= name.length; i++) {
        const ch = i === name.length ? " " : name[i];
        if (isSpace(ch)) {
            if (word && word.indexOf("=") < 0) words.push(word);
            word = "";
        } else {
            word += ch;
        }
    }
    return words.join("+");
}

function isSeparatorLine(value) {
    if (!value) return true;
    for (let i = 0; i < value.length; i++)
        if ("─=-*_".indexOf(value[i]) < 0) return false;
    return true;
}

function cleanComment(value) {
    value = value.trim();
    while (value.length && "─=-*_ \t".indexOf(value[0]) >= 0) value = value.substring(1);
    while (value.length && "─=-*_ \t".indexOf(value[value.length - 1]) >= 0)
        value = value.substring(0, value.length - 1);
    return value.trim();
}

function parse(text) {
    let body = extractBlock(text, "binds");
    if (body === null) {
        const input = extractBlock(text, "input");
        if (input !== null) body = extractBlock(input, "binds");
    }
    if (body === null) return [];

    const categories = [];
    let category = null, pendingDescription = null;
    const lines = body.split("\n");
    let i = 0;
    while (i < lines.length) {
        const trimmed = lines[i].trim();
        if (!trimmed) { i++; continue; }

        if (trimmed.indexOf("//") === 0) {
            const comment = cleanComment(trimmed.substring(2));
            if (!comment || isSeparatorLine(comment)) { i++; continue; }
            let nextCode = null, nextComment = null;
            for (let j = i + 1; j < lines.length; j++) {
                const next = splitInlineComment(lines[j].trim());
                if (!next.code.trim()) continue;
                nextCode = next.code.trim(); nextComment = next.comment; break;
            }
            if (nextCode !== null && isBindingHeader(nextCode) && !nextComment) pendingDescription = comment;
            else {
                if (category) categories.push(category);
                category = { title: comment, binds: [] };
            }
            i++; continue;
        }

        const split = splitInlineComment(trimmed);
        const code = split.code.trim();
        if (!isBindingHeader(code)) { i++; continue; }
        const combo = bindingCombo(code);
        let action = code.substring(code.indexOf("{") + 1);
        let depth = braceDelta(action), last = i;
        while (depth > 0 && last + 1 < lines.length) {
            last++;
            action += "\n" + lines[last];
            depth += braceDelta(lines[last]);
        }
        const close = action.lastIndexOf("}");
        if (close >= 0) action = action.substring(0, close);
        const actionLines = action.split("\n");
        for (let j = 0; j < actionLines.length; j++)
            actionLines[j] = splitInlineComment(actionLines[j]).code;
        action = actionLines.join("\n").trim();

        if (combo) {
            if (!category) category = { title: "Прочее", binds: [] };
            let desc = actionDescription(action);
            if (split.comment) desc = split.comment;
            if (pendingDescription) desc = pendingDescription;
            category.binds.push({ keys: parseCombo(combo), desc: desc });
        }
        pendingDescription = null;
        i = last + 1;
    }
    if (category && category.binds.length) categories.push(category);
    return categories;
}
