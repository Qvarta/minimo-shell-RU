// SPDX-License-Identifier: MIT

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    property int floatingWindowPosition: Number.MAX_SAFE_INTEGER

    property ListModel workspaces: ListModel {}
    property var windows: []
    property int focusedWindowIndex: -1

    property bool overviewActive: false

    property var keyboardLayouts: []

    signal workspaceChanged
    signal activeWindowChanged
    signal windowListChanged
    signal displayScalesChanged

    property var outputCache: ({})
    property var workspaceCache: ({})

    // Solo disponible si Compositor detecta que la sesión es niri.
    readonly property bool available: Compositor.session === "niri"

    function initialize() {
        niriEventStream.connected = true;
        niriCommandSocket.connected = true;

        startEventStream();
        updateOutputs();
        updateWorkspaces();
        updateWindows();
        queryDisplayScales();
    }

    // https://yalter.github.io/niri/niri_ipc/enum.Request.html
    function sendSocketCommand(sock, command) {
        sock.write(JSON.stringify(command) + "\n");
        sock.flush();
    }

    function startEventStream() {
        sendSocketCommand(niriEventStream, "EventStream");
    }

    function updateOutputs() {
        sendSocketCommand(niriCommandSocket, "Outputs");
    }

    function updateWorkspaces() {
        sendSocketCommand(niriCommandSocket, "Workspaces");
    }

    function updateWindows() {
        sendSocketCommand(niriCommandSocket, "Windows");
    }

    Timer {
        id: workspaceUpdateTimer
        interval: 50
        repeat: false
        onTriggered: updateWorkspaces()
    }

    function queryDisplayScales() {
        sendSocketCommand(niriCommandSocket, "Outputs");
    }

    function recollectOutputs(outputsData) {
        const scales = {};
        outputCache = {};

        for (const outputName in outputsData) {
            const output = outputsData[outputName];
            if (output && output.name) {
                const isConnected = output.logical !== null && output.current_mode !== null;
                const logical = output.logical || {};
                const currentModeIdx = output.current_mode ?? 0;
                const modes = output.modes || [];
                const currentMode = modes[currentModeIdx] || {};

                const outputData = {
                    "name": output.name,
                    "connected": isConnected,
                    "scale": logical.scale || 1.0,
                    "width": logical.width || 0,
                    "height": logical.height || 0,
                    "x": logical.x || 0,
                    "y": logical.y || 0,
                    "physical_width": (output.physical_size && output.physical_size[0]) || 0,
                    "physical_height": (output.physical_size && output.physical_size[1]) || 0,
                    "refresh_rate": currentMode.refresh_rate || 0,
                    "vrr_supported": output.vrr_supported || false,
                    "vrr_enabled": output.vrr_enabled || false,
                    "transform": logical.transform || "Normal"
                };

                outputCache[output.name] = outputData;
                scales[output.name] = outputData;
            }
        }

        displayScalesChanged();
    }

    function recollectWorkspaces(workspacesData) {
        const workspacesList = [];
        workspaceCache = {};

        for (const ws of workspacesData) {
            const wsData = {
                "id": ws.id,
                "idx": ws.idx,
                "name": ws.name || "",
                "output": ws.output || "",
                "isFocused": ws.is_focused === true,
                "isActive": ws.is_active === true,
                "isUrgent": ws.is_urgent === true,
                "isOccupied": ws.active_window_id ? true : false
            };

            workspacesList.push(wsData);
            workspaceCache[ws.id] = wsData;
        }

        workspacesList.sort((a, b) => {
            if (a.output !== b.output) {
                return a.output.localeCompare(b.output);
            }
            return a.idx - b.idx;
        });

        workspaces.clear();
        for (var i = 0; i < workspacesList.length; i++) {
            workspaces.append(workspacesList[i]);
        }

        workspaceChanged();
    }

    Socket {
        id: niriCommandSocket
        path: Quickshell.env("NIRI_SOCKET")
        connected: false

        parser: SplitParser {
            onRead: function (line) {
                try {
                    const data = JSON.parse(line);

                    if (data && data.Ok) {
                        const res = data.Ok;
                        if (res.Windows) {
                            recollectWindows(res.Windows);
                        } else if (res.Outputs) {
                            recollectOutputs(res.Outputs);
                        } else if (res.Workspaces) {
                            recollectWorkspaces(res.Workspaces);
                        }
                    } else {
                        console.error("NiriService: Niri returned an error:", data.Err, line);
                    }
                } catch (e) {
                    console.error("NiriService: Failed to parse data from socket:", e, line);
                    return;
                }
            }
        }
    }

    Socket {
        id: niriEventStream
        path: Quickshell.env("NIRI_SOCKET")
        connected: false

        parser: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());

                    if (event.WorkspacesChanged) {
                        recollectWorkspaces(event.WorkspacesChanged.workspaces);
                    } else if (event.WindowOpenedOrChanged) {
                        handleWindowOpenedOrChanged(event.WindowOpenedOrChanged);
                    } else if (event.WindowClosed) {
                        handleWindowClosed(event.WindowClosed);
                    } else if (event.WindowsChanged) {
                        handleWindowsChanged(event.WindowsChanged);
                    } else if (event.WorkspaceActivated) {
                        workspaceUpdateTimer.restart();
                    } else if (event.WindowFocusChanged) {
                        handleWindowFocusChanged(event.WindowFocusChanged);
                    } else if (event.WindowLayoutsChanged) {
                        handleWindowLayoutsChanged(event.WindowLayoutsChanged);
                    } else if (event.OverviewOpenedOrClosed) {
                        handleOverviewOpenedOrClosed(event.OverviewOpenedOrClosed);
                    } else if (event.OutputsChanged) {
                        queryDisplayScales();
                    } else if (event.ConfigLoaded) {
                        queryDisplayScales();
                    } else if (event.KeyboardLayoutsChanged) {
                        handleKeyboardLayoutsChanged(event.KeyboardLayoutsChanged);
                    } else if (event.KeyboardLayoutSwitched) {
                        handleKeyboardLayoutSwitched(event.KeyboardLayoutSwitched);
                    }
                } catch (e) {
                    console.error("NiriService: Error parsing event stream:", e, data);
                }
            }
        }
    }

    function getWindowPosition(layout) {
        if (layout.pos_in_scrolling_layout) {
            return {
                "x": layout.pos_in_scrolling_layout[0],
                "y": layout.pos_in_scrolling_layout[1]
            };
        } else {
            return {
                "x": floatingWindowPosition,
                "y": floatingWindowPosition
            };
        }
    }

    function getWindowOutput(win) {
        for (var i = 0; i < workspaces.count; i++) {
            if (workspaces.get(i).id === win.workspaceId) {
                return workspaces.get(i).output;
            }
        }
        return null;
    }

    function getWindowData(win) {
        return {
            "id": win.id,
            "title": win.title || "",
            "appId": win.app_id || "",
            "workspaceId": win.workspace_id || -1,
            "isFocused": win.is_focused === true,
            "output": getWindowOutput(win) || "",
            "position": getWindowPosition(win.layout)
        };
    }

    function toSortedWindowList(windowList) {
        return windowList.map(win => {
            const workspace = workspaceCache[win.workspaceId];
            const output = (workspace && workspace.output) ? outputCache[workspace.output] : null;

            return {
                window: win,
                workspaceIdx: workspace ? workspace.idx : 0,
                outputX: output ? output.x : 0,
                outputY: output ? output.y : 0
            };
        }).sort((a, b) => {
            if (a.outputX !== b.outputX) {
                return a.outputX - b.outputX;
            }
            if (a.outputY !== b.outputY) {
                return a.outputY - b.outputY;
            }
            if (a.workspaceIdx !== b.workspaceIdx) {
                return a.workspaceIdx - b.workspaceIdx;
            }
            if (a.window.position.x !== b.window.position.x) {
                return a.window.position.x - b.window.position.x;
            }
            if (a.window.position.y !== b.window.position.y) {
                return a.window.position.y - b.window.position.y;
            }
            return a.window.id - b.window.id;
        }).map(info => info.window);
    }

    function recollectWindows(windowsData) {
        const windowsList = [];
        for (const win of windowsData) {
            windowsList.push(getWindowData(win));
        }
        windows = toSortedWindowList(windowsList);
        windowListChanged();

        focusedWindowIndex = -1;
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].isFocused) {
                focusedWindowIndex = i;
                break;
            }
        }
        activeWindowChanged();
    }

    function handleWindowOpenedOrChanged(eventData) {
        try {
            const windowData = eventData.window;
            const existingIndex = windows.findIndex(w => w.id === windowData.id);
            const newWindow = getWindowData(windowData);

            const previouslyFocusedId = focusedWindowIndex >= 0 && focusedWindowIndex < windows.length ? windows[focusedWindowIndex].id : null;

            if (existingIndex >= 0) {
                windows[existingIndex] = newWindow;
            } else {
                windows.push(newWindow);
            }
            windows = toSortedWindowList(windows);

            if (newWindow.isFocused) {
                focusedWindowIndex = windows.findIndex(w => w.id === windowData.id);

                if (previouslyFocusedId !== null && previouslyFocusedId !== windowData.id) {
                    const oldFocusedWindow = windows.find(w => w.id === previouslyFocusedId);
                    if (oldFocusedWindow) {
                        oldFocusedWindow.isFocused = false;
                    }
                }
                activeWindowChanged();
            }

            windowListChanged();
            workspaceUpdateTimer.restart();
        } catch (e) {
            console.error("NiriService: Error handling WindowOpenedOrChanged:", e);
        }
    }

    function handleWindowClosed(eventData) {
        try {
            const windowId = eventData.id;
            const windowIndex = windows.findIndex(w => w.id === windowId);

            if (windowIndex >= 0) {
                if (windowIndex === focusedWindowIndex) {
                    focusedWindowIndex = -1;
                    activeWindowChanged();
                } else if (focusedWindowIndex > windowIndex) {
                    focusedWindowIndex--;
                }

                windows.splice(windowIndex, 1);
                windowListChanged();
                workspaceUpdateTimer.restart();
            }
        } catch (e) {
            console.error("NiriService: Error handling WindowClosed:", e);
        }
    }

    function handleWindowsChanged(eventData) {
        try {
            const windowsData = eventData.windows;
            recollectWindows(windowsData);
        } catch (e) {
            console.error("NiriService: Error handling WindowsChanged:", e);
        }
    }

    function handleWindowFocusChanged(eventData) {
        try {
            const focusedId = eventData.id;

            if (windows[focusedWindowIndex]) {
                windows[focusedWindowIndex].isFocused = false;
            }

            if (focusedId) {
                const newIndex = windows.findIndex(w => w.id === focusedId);

                if (newIndex >= 0 && newIndex < windows.length) {
                    windows[newIndex].isFocused = true;
                }

                focusedWindowIndex = newIndex >= 0 ? newIndex : -1;
            } else {
                focusedWindowIndex = -1;
            }

            activeWindowChanged();
        } catch (e) {
            console.error("NiriService: Error handling WindowFocusChanged:", e);
        }
    }

    function handleWindowLayoutsChanged(eventData) {
        try {
            for (const change of eventData.changes) {
                const windowId = change[0];
                const layout = change[1];
                const window = windows.find(w => w.id === windowId);
                if (window) {
                    window.position = getWindowPosition(layout);
                }
            }

            windows = toSortedWindowList(windows);

            windowListChanged();
        } catch (e) {
            console.error("NiriService: Error handling WindowLayoutChanged:", e);
        }
    }

    function handleOverviewOpenedOrClosed(eventData) {
        try {
            overviewActive = eventData.is_open;
        } catch (e) {
            console.error("NiriService: Error handling OverviewOpenedOrClosed:", e);
        }
    }

    function handleKeyboardLayoutsChanged(eventData) {
        try {
            keyboardLayouts = eventData.keyboard_layouts.names;
        } catch (e) {
            console.error("NiriService: Error handling keyboardLayoutsChanged:", e);
        }
    }

    function handleKeyboardLayoutSwitched(eventData) {
        try {
            const layoutName = keyboardLayouts[eventData.idx];
        } catch (e) {
            console.error("NiriService: Error handling KeyboardLayoutSwitched:", e);
        }
    }

    readonly property var activeWorkspace: {
        workspaceChanged; // подписка на пересчёт
        for (var i = 0; i < workspaces.count; i++) {
            const ws = workspaces.get(i);
            if (ws.isFocused)
                return ws;
        }
        return null;
    }

    function windowCountInWorkspace(workspaceId) {
        windowListChanged;
        workspaceChanged; // подписки на пересчёт
        if (workspaceId === undefined || workspaceId === null || workspaceId < 0) {
            return windows.length;
        }
        return windows.filter(w => w.workspaceId === workspaceId).length;
    }

    function switchToWorkspace(idx) {
        try {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
        } catch (e) {
            console.error("NiriService: Failed to switch workspace:", e);
        }
    }

    function focusWindow(window) {
        try {
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", window.id.toString()]);
        } catch (e) {
            console.error("NiriService: Failed to switch window:", e);
        }
    }

    function closeWindow(window) {
        try {
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", window.id.toString()]);
        } catch (e) {
            console.error("NiriService: Failed to close window:", e);
        }
    }

    function logout() {
        try {
            Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
        } catch (e) {
            console.error("NiriService: Failed to logout:", e);
        }
    }

    function cycleKeyboardLayout() {
        try {
            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
        } catch (e) {
            console.error("NiriService: Failed to cycle keyboard layout:", e);
        }
    }

    function spawn(command) {
        try {
            const niriCommand = ["niri", "msg", "action", "spawn", "--"].concat(command);
            Quickshell.execDetached(niriCommand);
        } catch (e) {
            console.error("NiriService: Failed to spawn command:", e);
        }
    }

    Component.onCompleted: {
        if (available) {
            initialize();
            console.info("[Niri] The service is running");
        } else {
            console.info("[Niri] Session is not niri (Compositor.session=\"" + Compositor.session + "\"), service not started");
        }
    }
}
