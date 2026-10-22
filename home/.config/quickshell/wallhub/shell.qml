import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Wallhub: transparent full-screen wallpaper carousel. Just the cards.
ShellRoot {
    id: root

    readonly property string helper: Quickshell.env("HOME") + "/.config/quickshell/wallhub/list.sh"

    property var allItems: []
    property var view: []
    property string filter: "all"     // all | image | video
    property string currentPath: ""
    property int cur: 0
    property real shift: 0
    property bool ready: false

    function wrap(i, n) { return ((i % n) + n) % n }

    function rebuild(keepPath) {
        var out = []
        for (var i = 0; i < allItems.length; i++) {
            var it = allItems[i]
            if (filter === "all" || it.kind === filter) out.push(it)
        }
        view = out
        cur = 0
        if (keepPath) {
            for (var j = 0; j < out.length; j++) {
                if (out[j].path === keepPath) { cur = j; break }
            }
        }
    }

    function step(d) {
        if (view.length === 0) return
        cur = wrap(cur + d, view.length)
        shift = Math.max(-4, Math.min(4, shift + d))
        slide.restart()
    }

    function apply(item) {
        if (!item) return
        applier.command = ["noctalia", "msg", "plugin", "local/wallpaper-hub:service", "all", "set", item.path]
        applier.running = true
    }

    function cycleFilter() {
        var keep = view.length > 0 ? view[cur].path : currentPath
        filter = filter === "all" ? "image" : (filter === "image" ? "video" : "all")
        rebuild(keep)
    }

    function parse(text) {
        var lines = text.split("\n")
        var arr = []
        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split("|")
            if (p.length >= 3) arr.push({ kind: p[0], path: p[1], thumb: p[2] })
        }
        return arr
    }

    property bool gotList: false
    property bool gotCurrent: false
    function maybeReady() {
        if (!gotList || !gotCurrent) return
        rebuild(currentPath)
        ready = true
        gen.running = true
    }

    Process {
        id: lister
        command: [root.helper, "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.allItems = root.parse(text); root.gotList = true; root.maybeReady() }
        }
    }

    Process {
        id: currentProc
        command: [root.helper, "current"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.currentPath = text.trim(); root.gotCurrent = true; root.maybeReady() }
        }
    }

    // Builds any missing thumbnails in the background; cards are re-created once if any were made.
    Process {
        id: gen
        command: [root.helper, "gen"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (parseInt(text) > 0) { root.cardsOn = false; Qt.callLater(function() { root.cardsOn = true }) }
            }
        }
    }
    property bool cardsOn: true

    Process {
        id: applier
        onExited: Qt.quit()
    }

    NumberAnimation {
        id: slide
        target: root
        property: "shift"
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
    }

    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "wallhub"

        Item {
            id: stage
            anchors.fill: parent
            focus: true

            // Layout constants
            readonly property real centerW: Math.min(width * 0.27, 520)
            readonly property real centerH: Math.min(height * 0.62, 620)
            readonly property real sideW: centerW * 0.36
            readonly property real sideH: centerH * 0.78
            readonly property real gap: 12
            readonly property real firstStep: centerW / 2 + sideW / 2 + gap
            readonly property real sideStep: sideW * 0.86
            readonly property real skew: -0.16

            Keys.onPressed: function(e) {
                if (e.key === Qt.Key_Escape) Qt.quit()
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_H || e.key === Qt.Key_Up) root.step(-1)
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_L || e.key === Qt.Key_Down) root.step(1)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.apply(root.view[root.cur])
                else if (e.key === Qt.Key_Space) {
                    if (root.view.length > 0) root.apply(root.view[Math.floor(Math.random() * root.view.length)])
                }
                else if (e.key === Qt.Key_Tab) root.cycleFilter()
                e.accepted = true
            }

            // Click on empty space closes the picker.
            MouseArea {
                anchors.fill: parent
                z: -100
                onClicked: Qt.quit()
                onWheel: function(w) { root.step(w.angleDelta.y > 0 ? -1 : 1) }
            }

            // One delegate per wallpaper; only those within 6 slots of the centre are loaded.
            // Cards keep their image while sliding, so nothing blinks out and back in.
            Repeater {
                model: root.ready ? root.view.length : 0

                delegate: Item {
                    id: holder
                    readonly property int n: root.view.length
                    readonly property int d: {
                        var x = ((index - root.cur) % n + n) % n
                        return x > n / 2 ? x - n : x
                    }
                    Loader {
                        active: root.cardsOn && Math.abs(holder.d) <= 6
                        sourceComponent: card
                    }
                    Component {
                        id: card
                        Item {
                    id: slot
                    readonly property real o: holder.d + root.shift
                    readonly property real ao: Math.abs(o)
                    readonly property var item: root.view[index]
                    readonly property bool active: item && item.path === root.currentPath

                    width: ao < 1 ? stage.centerW + (stage.sideW - stage.centerW) * ao : stage.sideW
                    height: ao < 1 ? stage.centerH + (stage.sideH - stage.centerH) * ao : stage.sideH
                    x: stage.width / 2 + (o < 0 ? -1 : 1) * (ao <= 1 ? ao * stage.firstStep : stage.firstStep + (ao - 1) * stage.sideStep) - width / 2
                    y: (stage.height - height) / 2
                    z: 100 - ao * 10
                    opacity: Math.max(0, Math.min(1, 1.15 - ao * 0.2)) * (ao > 4.5 ? 0 : 1)
                    visible: opacity > 0.01

                    transform: Matrix4x4 {
                        // x' = x + skew * (y - h/2): parallelogram that stays centred
                        matrix: Qt.matrix4x4(1, stage.skew, 0, -stage.skew * slot.height / 2,
                                             0, 1, 0, 0,
                                             0, 0, 1, 0,
                                             0, 0, 0, 1)
                    }

                    Item {
                        anchors.fill: parent
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: slot.item ? "file://" + slot.item.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 720
                            smooth: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: slot.active ? 4 : (slot.ao < 0.5 ? 2 : 0)
                            border.color: slot.active ? "#f4b8a0" : "#ddffffff"
                        }

                        // Badges: kind + active
                        Row {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            spacing: 6
                            visible: slot.ao < 1.5
                            Rectangle {
                                visible: slot.item && slot.item.kind === "video"
                                radius: 11; height: 22; width: liveText.width + 18
                                color: "#cc1e1b24"
                                Text {
                                    id: liveText
                                    anchors.centerIn: parent
                                    text: "▶  Live"
                                    color: "#f4b8a0"
                                    font.pixelSize: 12; font.bold: true
                                }
                            }
                            Rectangle {
                                visible: slot.item && slot.item.kind === "image"
                                radius: 11; height: 22; width: imgText.width + 18
                                color: "#cc1e1b24"
                                Text {
                                    id: imgText
                                    anchors.centerIn: parent
                                    text: "Image"
                                    color: "#e6dfe8"
                                    font.pixelSize: 12; font.bold: true
                                }
                            }
                            Rectangle {
                                visible: slot.active
                                radius: 11; height: 22; width: actText.width + 18
                                color: "#f4b8a0"
                                Text {
                                    id: actText
                                    anchors.centerIn: parent
                                    text: "✓  Active"
                                    color: "#2a1a1a"
                                    font.pixelSize: 12; font.bold: true
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (slot.ao < 0.5) root.apply(slot.item)
                            else root.step(Math.round(slot.o))
                        }
                    }
                        }
                    }
                }
            }
        }
    }
}
