#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Vuelve a mostrar una app de la bandeja (panel "En segundo plano").
# Uso: tray-open.py <id del item SNI> [desktop entry id]
# Muchas apps (Steam/libappindicator, Electron) ignoran Activate, así que después de
# pedírselo desde QML seguimos esta cadena: ventana existente → enfocarla;
# si no hay → relanzar (las apps de instancia única muestran la ventana que ya tienen).
import json, os, shutil, subprocess, sys, time

def run(*a, timeout=4):
    try:
        return subprocess.run(a, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""

def log(msg):
    print("tray-open:", msg, file=sys.stderr, flush=True)

# Modo "--quit <id>": cerrar la app con amabilidad (SIGTERM), para items sin menú propio.
quit_mode = len(sys.argv) > 1 and sys.argv[1] == "--quit"
args = sys.argv[2:] if quit_mode else sys.argv[1:]
item_id = args[0] if len(args) > 0 else ""
entry = args[1] if len(args) > 1 else ""

def item_pid():
    """PID dueño del item SNI con ese Id (vía el watcher y el bus)."""
    out = run("busctl", "--user", "--json=short", "get-property", "org.kde.StatusNotifierWatcher",
              "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
    try:
        items = json.loads(out)["data"]
    except Exception:
        return 0
    for it in items:
        svc, _, path = it.partition("/")
        path = "/" + path if path else "/StatusNotifierItem"
        got = run("busctl", "--user", "--json=short", "get-property", svc, path, "org.kde.StatusNotifierItem", "Id")
        try:
            if json.loads(got)["data"] != item_id:
                continue
            pid = run("busctl", "--user", "--json=short", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
                      "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", svc)
            return int(json.loads(pid)["data"][0])
        except Exception:
            continue
    return 0

def family(pid):
    """El PID y todos sus descendientes: Steam y Electron dibujan ventanas en procesos hijos."""
    kids = {}
    try:
        for p in os.listdir("/proc"):
            if p.isdigit():
                try:
                    with open(f"/proc/{p}/stat") as f:
                        ppid = int(f.read().rsplit(")", 1)[1].split()[1])
                    kids.setdefault(ppid, []).append(int(p))
                except (OSError, ValueError, IndexError):
                    pass
    except OSError:
        pass
    fam, todo = {pid}, [pid]
    while todo:
        for k in kids.get(todo.pop(), []):
            if k not in fam:
                fam.add(k); todo.append(k)
    return fam

def comm(pid):
    try:
        with open(f"/proc/{pid}/comm") as f:
            return f.read().strip().lower()
    except Exception:
        return ""

def compositor():
    """Detect the active compositor without assuming Hyprland just because hyprctl is installed."""
    if os.environ.get("NIRI_SOCKET") and shutil.which("niri"):
        return "niri"
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return "hyprland"
    if shutil.which("niri"):
        try:
            response = json.loads(run("niri", "msg", "--json", "focused-window"))
            if "Ok" in response and "FocusedWindow" in response["Ok"]:
                return "niri"
        except Exception:
            pass
    if shutil.which("hyprctl"):
        return "hyprland"
    return ""

def niri_windows():
    """Return niri's JSON window list, accepting its IPC response envelope."""
    try:
        response = json.loads(run("niri", "msg", "--json", "windows"))
        if isinstance(response, list):
            return response
        if isinstance(response, dict):
            payload = response.get("Ok", response)
            if isinstance(payload, dict):
                return payload.get("Windows", payload.get("windows", []))
    except Exception:
        pass
    return []

def find_niri_window(pid):
    windows = niri_windows()
    fam = family(pid) if pid else set()
    keys = {k for k in (item_id.lower(), entry.lower().removesuffix(".desktop"), comm(pid)) if k}
    hit = [w for w in windows if w.get("pid") in fam]
    if not hit:
        hit = [w for w in windows if (w.get("app_id") or "").lower() in keys]
    return max(hit, key=lambda w: bool(w.get("is_focused"))) if hit else None

def find_hyprland_window(pid):
    try:
        clients = json.loads(run("hyprctl", "clients", "-j") or "[]")
    except ValueError:
        clients = []
    fam = family(pid) if pid else set()
    keys = {k for k in (item_id.lower(), entry.lower().removesuffix(".desktop"), comm(pid)) if k}
    hit = [c for c in clients if c.get("pid") in fam]
    if not hit:
        hit = [c for c in clients if (c.get("class") or "").lower() in keys]
    hit = [c for c in hit if c.get("mapped", True) and not c.get("hidden")
           and (c.get("size") or [1, 1])[0] > 40 and (c.get("size") or [1, 1])[1] > 40]
    return min(hit, key=lambda c: c.get("focusHistoryID", 999)) if hit else None

if not item_id:
    sys.exit(0)
if quit_mode:
    import signal
    pid = item_pid()
    me = {os.getpid(), os.getppid()}
    if pid <= 1 or pid in me or comm(pid) in ("qs", "quickshell", "systemd", "hyprland", "niri"):
        log(f"{item_id}: no se cierra (pid {pid})")
        sys.exit(1)
    os.kill(pid, signal.SIGTERM)
    log(f"{item_id}: SIGTERM a {pid} ({comm(pid)})")
    sys.exit(0)

time.sleep(0.6)   # darle tiempo al Activate que ya mandó QML
pid = item_pid()
wm = compositor()
c = find_niri_window(pid) if wm == "niri" else find_hyprland_window(pid) if wm == "hyprland" else None
if c:
    if wm == "niri":
        window_id = c.get("id")
        focused = run("niri", "msg", "action", "focus-window", "--id", str(window_id)) if window_id is not None else ""
        if focused:
            log(f"{item_id}: ventana niri {window_id} enfocada")
            sys.exit(0)
    else:
        addr = c["address"]
        if (c.get("workspace") or {}).get("name", "").startswith("special:"):
            try:
                cur = json.loads(run("hyprctl", "activeworkspace", "-j") or "{}").get("id", 1)
            except ValueError:
                cur = 1
            run("hyprctl", "dispatch", 'hl.dsp.window.move({ workspace = "%s", follow = true, window = "address:%s" })' % (cur, addr))
        run("hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:%s" })' % addr)
        log(f"{item_id}: ventana {addr} enfocada")
        sys.exit(0)

# Sin ventana: relanzar (las apps de instancia única muestran la ventana que ya tienen).
if comm(pid) in ("qs", "quickshell"):
    sys.exit(0)
name = (entry or comm(pid) or item_id).lower().removesuffix(".desktop")
cands = []
if "steam" in name and shutil.which("steam"):
    cands.append(["steam", "steam://open/main"])
if entry and shutil.which("gtk-launch"):
    cands.append(["gtk-launch", entry.removesuffix(".desktop")])
if pid:
    try:
        cands.append([os.readlink(f"/proc/{pid}/exe")])
    except OSError:
        pass
for cmd in cands:
    try:
        subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as e:
        log(f"{item_id}: {cmd[0]} falló ({e})")
        continue
    log(f"{item_id}: relanzado con {cmd}")
    sys.exit(0)
log(f"{item_id}: sin ventana ni forma de relanzar")
sys.exit(1)
