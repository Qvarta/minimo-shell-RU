// SPDX-License-Identifier: MIT

pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool isHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property bool isNiri: !!Quickshell.env("NIRI_SOCKET")
    readonly property string session: isHyprland ? "hyprland" : (isNiri ? "niri" : "")

    Component.onCompleted: {
        if (isNiri)
            console.info("[Compositor] Niri session detected");
        else if (isHyprland)
            console.info("[Compositor] Hyprland session detected");
    }
}
