// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../../Common"
import "../../Services"

Item {
    id: root
    readonly property var players: Mpris.players.values

    function usable(p) {
        if (!p || (p.dbusName || "").indexOf("playerctld") >= 0) return false
        if (p.isPlaying) return true
        return p.playbackState === MprisPlaybackState.Paused && (p.trackTitle || "") !== ""
    }
    readonly property MprisPlayer player: {
        for (const p of players) if (p.isPlaying && usable(p)) return p
        for (const p of players) if (usable(p)) return p
        return null
    }
    visible: player !== null || RadioService.isPlaying
    implicitHeight: visible ? 64 : 0

    readonly property bool playerIsVlc: {
        if (!player) return false
        var id = (player.identity || "").toLowerCase()
        var name = (player.dbusName || "").toLowerCase()
        return id.indexOf("vlc") >= 0 || name.indexOf("vlc") >= 0
    }

    readonly property bool radioActive: RadioService.isPlaying
        && RadioService.currentPlayingStation !== ""
        && (player === null || playerIsVlc)

    readonly property url radioArtUrl: RadioService.currentPlayingStation !== ""
        ? Qt.resolvedUrl("../../assets/png/" + RadioService.currentPlayingStation + ".png")
        : ""

    readonly property bool showTitleLine: {
        if (radioActive) return RadioService.currentTrack !== ""
        return player !== null
    }

    readonly property string displayTitle: {
        if (radioActive) return RadioService.currentTrack
        if (!player) return ""
        return player.trackTitle || I18n.tr("Untitled")
    }

    readonly property string displayArtist: {
        if (radioActive) {
            if (RadioService.currentTrack === "" && RadioService.currentArtist === "")
                return RadioService.currentPlayingStation
            return RadioService.currentArtist || ""
        }
        if (!player) return ""
        return player.trackArtist || player.identity || ""
    }

    Timer {
        running: root.visible && root.player !== null && root.player.isPlaying
        interval: 1000; repeat: true
        onTriggered: root.player.positionChanged()
    }

    Item {
        id: art
        width: 48; height: 48
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool hasArt: cover.status === Image.Ready

        property real angle: 0

        NumberAnimation {
            target: art; property: "angle"
            running: root.visible && (root.radioActive || (root.player !== null && root.player.isPlaying)) && art.hasArt
            paused: running && !(root.radioActive || (root.player !== null && root.player.isPlaying))
            from: art.angle; to: art.angle + 360
            duration: 8000; loops: Animation.Infinite
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.field
            visible: !art.hasArt
            Icon { anchors.centerIn: parent; name: "music"; tone: "gray"; size: 20 }
        }

        Item {
            id: coverLayer
            anchors.fill: parent
            visible: false
            layer.enabled: art.hasArt && root.visible
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(width * 2, height * 2)

            Image {
                id: cover
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                rotation: art.angle
                source: {
                    if (root.radioActive && root.radioArtUrl.toString() !== "")
                        return root.radioArtUrl
                    return root.player ? root.player.trackArtUrl : ""
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                antialiasing: true
                sourceSize: Qt.size(art.width * 2, art.height * 2)
            }
        }

        Item {
            id: circleMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            Rectangle { anchors.fill: parent; radius: width / 2; antialiasing: true }
        }

        MultiEffect {
            id: coverRounded
            anchors.fill: parent
            visible: art.hasArt && !root.radioActive
            source: coverLayer
            maskEnabled: true
            maskSource: circleMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        // Пайплайн для радио — обложка через шейдер кольца
        ShaderEffect {
            id: radioRingShader
            anchors.fill: parent
            visible: root.radioActive && art.hasArt
            property var source: ShaderEffectSource {
                sourceItem: coverLayer
                hideSource: true
                live: true
            }
            property real time: shaderAnimator.animTime
            property color bgWidget: Theme.card
            property vector2d resolution: Qt.vector2d(width, height)
            property color bgColor1: "#2C7BFF"
            fragmentShader: Qt.resolvedUrl("../../shaders/ring.qsb")

            Item {
                id: shaderAnimator
                property real animTime: 0
                NumberAnimation on animTime {
                    loops: Animation.Infinite
                    from: 0; to: 1000; duration: 60000
                    running: radioRingShader.visible
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 7; height: 7; radius: 3.5
            color: Theme.raised; opacity: 0.85
            antialiasing: true
            visible: art.hasArt && !root.radioActive
        }
    }

    Column {
        anchors.left: art.right; anchors.leftMargin: 16
        anchors.right: controls.left; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width; elide: Text.ElideRight
            visible: root.showTitleLine
            text: root.displayTitle
            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            visible: text !== ""
            text: root.displayArtist
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
        }
        Item { width: 1; height: 6 }
        Rectangle {
            width: parent.width; height: 3; radius: 1.5; color: Theme.track
            visible: root.player !== null && !root.radioActive && root.player.lengthSupported && root.player.length > 0
            Rectangle {
                height: parent.height; radius: 1.5; color: Theme.fill
                width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
            }
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Repeater {
            model: [
                {
                    i: "prev", a: "prev",
                    ok: root.radioActive ? RadioService.stations.length > 0
                                         : (root.player !== null && root.player.canGoPrevious)
                },
                {
                    i: root.radioActive
                        ? (RadioService.isPlaying ? "pause" : "play")
                        : (root.player && root.player.isPlaying ? "pause" : "play"),
                    a: "play",
                    ok: root.radioActive ? true
                                         : (root.player !== null && root.player.canTogglePlaying)
                },
                {
                    i: "next", a: "next",
                    ok: root.radioActive ? RadioService.stations.length > 0
                                         : (root.player !== null && root.player.canGoNext)
                }
            ]
            delegate: Item {
                required property var modelData
                width: 32; height: 32
                Icon { anchors.centerIn: parent; name: modelData.i; size: 20; tone: modelData.ok ? "dark" : "gray" }
                MouseArea {
                    anchors.fill: parent
                    enabled: modelData.ok
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.radioActive) {
                            if (modelData.a === "prev") RadioService.prev()
                            else if (modelData.a === "next") RadioService.next()
                            else RadioService.toggleCurrent()
                        } else if (root.player) {
                            if (modelData.a === "prev") root.player.previous()
                            else if (modelData.a === "next") root.player.next()
                            else root.player.togglePlaying()
                        }
                    }
                }
            }
        }
    }
}