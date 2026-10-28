// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import "../../Common"
import "../../Common/confirm.js" as Confirm
import "../../Services"
import ".."


Row {
    id: root
    signal done
    signal quickActions

    readonly property var commands: ({
            reboot: "systemctl reboot",
            poweroff: "systemctl poweroff"
        })
        
    readonly property var logoutCommands: ({
            hyprland: "hyprctl dispatch 'hl.dsp.exit()'",
            niri: "niri msg action quit --skip-confirmation"
        })
    property var st: Confirm.initial()
    readonly property string armed: st.armed

    function press(id) {
        const r = Confirm.press(st, id, Date.now(), 3000, 2000);
        st = r.state;
        if (r.state.armed !== "")
            disarm.restart();
        if (r.run !== "") {
            const cmd = r.run === "logout" ? (logoutCommands[Compositor.session] || "") : commands[r.run];
            if (cmd !== "")
                Quickshell.execDetached(["sh", "-c", cmd]);
            root.done();
        }
    }
    function reset() {
        disarm.stop();
        st = Confirm.disarm(st);
    }
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.st = Confirm.disarm(root.st)
    }

    MenuButton {
        icon: "logout"
        label: I18n.tr("Log out")
        armed: root.armed === "logout"
        onActivated: root.press("logout")
    }
    MenuButton {
        icon: "restart"
        label: I18n.tr("Restart")
        armed: root.armed === "reboot"
        onActivated: root.press("reboot")
    }
    MenuButton {
        icon: "power"
        label: I18n.tr("Shut down")
        armed: root.armed === "poweroff"
        onActivated: root.press("poweroff")
    }
    MenuButton {
        icon: "apps"
        label: I18n.tr("Quick actions")
        onActivated: root.quickActions()
    }
}
