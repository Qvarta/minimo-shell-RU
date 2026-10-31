// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    signal react(string name)
    signal islandCommand(string cmd)
    readonly property var islandIpcTabs: ["menu", "quickactions", "notifications", "clip", "notes", "radio", "power"]
    property int islandIpcTabIndex: 0
    signal gaze(real x, real y, int ms)
    signal pet()
    signal typed()
    signal typingStopped()
    signal squintFor(int ms)
    property int hearts: 0
    readonly property var names: ["hop", "doubleHop", "giggle", "lookAround", "surprise",
                                  "wink", "dizzy", "yawn", "curious", "greet", "happyBounce", "startled"]

    IpcHandler {
        target: "character"
        function react(name: string): string {
            if (root.names.indexOf(name) < 0) return "desconocida: " + name
            root.react(name); return "ok"
        }
        function list(): string { return root.names.join(" ") }
        function look(x: real, y: real): void { root.gaze(x, y, 4000) }
        function pet(): void { root.pet() }
        function squint(ms: int): void { root.squintFor(ms > 0 ? ms : 2000) }
        function sleep(): void { IdleState.sleepNow() }
        function wake(): void { IdleState.wake() }
    }
    IpcHandler {
        target: "island"
        function reveal(): void { root.islandCommand("show") }
        function dismiss(): void { root.islandCommand("hide") }
        function open(): void { root.islandCommand("open") }
        function close(): void { root.islandCommand("close") }
        function toggle(): void { root.islandCommand("toggle") }
        function status(): void { root.islandCommand("status") }
        function apps(): void { root.islandCommand("apps") }
        function clipboard(): void { root.islandCommand("clipboard") }
        function quickactions(): void { root.islandCommand("quickactions") }
        function next(): void {
            const tab = root.islandIpcTabs[root.islandIpcTabIndex]
            root.islandCommand("tab:" + tab)
            root.islandIpcTabIndex = (root.islandIpcTabIndex + 1) % root.islandIpcTabs.length
        }
        // Вкладка питания в острове: qs -c minimo-shell ipc call power toggle
        function power(): void { root.islandCommand("power") }
        function pet(): void { root.islandCommand("pet") }
    }
    // Вкладка питания в острове (Island/sections/PowerView.qml).
    // Вызов: qs -c minimo-shell ipc call power toggle
    // Аналог команды старого окна Power/PowerWindow.qml, которое удалено.
    IpcHandler {
        target: "power"
        function toggle(): void { root.islandCommand("power") }
    }
    IpcHandler {
        target: "radio"
        function play(name: string): string {
            if (!RadioService.stationAt(name)) return "desconocida: " + name
            RadioService.playStation(name); return "ok"
        }
        function stop(): void { RadioService.stop() }
        function toggle(): void { RadioService.toggleCurrent() }
        function prev(): void { RadioService.prev() }
        function next(): void { RadioService.next() }
        function list(): string {
            return RadioService.stations.map(s => s.name).join("\n")
        }
        function current(): string {
            return RadioService.isPlaying ? RadioService.currentPlayingStation : ""
        }
    }
}