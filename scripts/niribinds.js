// SPDX-License-Identifier: MIT
.pragma library

// Output: [{ title: string, binds: [{ keys: string, desc: string }] }]
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
    const parts = combo.split("+").map(part => part.trim()).filter(part => part.length > 0);
    const modifiers = [];
    let key = "";
    for (let i = 0; i < parts.length; i++) {
        const part = parts[i].toLowerCase();
        let modifier = "";
        if (part === "mod" || part === "super" || part === "meta" || part === "win") modifier = "Super";
        else if (part === "ctrl" || part === "control") modifier = "Ctrl";
        else if (part === "alt") modifier = "Alt";
        else if (part === "shift") modifier = "Shift";
        if (modifier) {
            if (modifiers.indexOf(modifier) < 0) modifiers.push(modifier);
        } else {
            key = parts[i];
        }
    }

    const ordered = [];
    const order = ["Super", "Ctrl", "Alt", "Shift"];
    for (let i = 0; i < order.length; i++)
        if (modifiers.indexOf(order[i]) >= 0) ordered.push(order[i]);
    if (key) ordered.push(normalizeKey(key));
    return ordered.join(" + ");
}

// Finds the binds block without parsing the rest of KDL.
function getBindsLines(source) {
    const lines = source.split("\n");
    let start = -1;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.indexOf("//") !== 0 && line.indexOf("binds") === 0 && line.indexOf("{") >= 0) {
            start = i;
            break;
        }
    }
    if (start < 0) return [];

    const result = [];
    let depth = 0;
    for (let i = start; i < lines.length; i++) {
        const line = lines[i];
        // Braces in quoted arguments are not part of the block structure.
        let quote = "";
        for (let j = 0; j < line.length; j++) {
            const ch = line[j];
            if (quote) {
                if (ch === "\\" && j + 1 < line.length) j++;
                else if (ch === quote) quote = "";
                continue;
            }
            if (ch === '"' || ch === "'") quote = ch;
            else if (ch === "/" && line[j + 1] === "/") break;
            else if (ch === "{") depth++;
            else if (ch === "}") depth--;
        }
        if (i > start) result.push(line);
        if (depth === 0 && i > start) break;
    }
    return result;
}

function parseLine(line) {
    // In the supported shortcut format, // after } is the visible description.
    let commentAt = line.indexOf("//");
    const code = (commentAt < 0 ? line : line.substring(0, commentAt)).trim();
    const comment = commentAt < 0 ? "" : line.substring(commentAt + 2).trim();

    const open = code.indexOf("{");
    const close = code.lastIndexOf("}");
    if (open < 1 || close < open) return null;

    // Header can contain KDL options (e.g. cooldown-ms=150); only key tokens are used.
    const headerParts = code.substring(0, open).trim().split(" ");
    const keyParts = [];
    for (let i = 0; i < headerParts.length; i++) {
        const part = headerParts[i].trim();
        if (part && part.indexOf("=") < 0) keyParts.push(part);
    }
    if (!keyParts.length) return null;

    return {
        keys: parseCombo(keyParts.join("+")),
        desc: comment || code.substring(open + 1, close).trim()
    };
}

function parse(source) {
    const lines = getBindsLines(source);
    const categories = [];
    let category = null;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line || line === "}") continue;

        if (line.indexOf("//") === 0) {
            const title = line.substring(2).trim();
            if (!title) continue;
            if (category && category.binds.length) categories.push(category);
            category = { title: title, binds: [] };
            continue;
        }

        const binding = parseLine(line);
        if (!binding) continue;
        if (!category) category = { title: "Прочее", binds: [] };
        category.binds.push(binding);
    }

    if (category && category.binds.length) categories.push(category);
    return categories;
}
