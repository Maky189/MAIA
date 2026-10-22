import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Cozy launcher: art banner with clock + greeting on the left, search and apps on
// the right. Colours come from the Noctalia theme (kitty's noctalia.conf), so the
// launcher always matches the current wallpaper.
ShellRoot {
    id: root

    property string query: ""
    property var results: []
    // Banner art: "Akiyama Mio" lofi illustration by Riovannes (via wallhaven, wallhaven-rr955q)
    property string banner: Quickshell.env("HOME") + "/.config/quickshell/launcher/banner.jpg"

    // Palette (defaults are overwritten from the theme file)
    property color bg: "#231b1a"
    property color surface: "#302421"
    property color fg: "#f3f2f2"
    property color dim: "#726562"
    property color accent: "#e7b5ab"
    property color accent2: "#deaba1"

    Process {
        command: ["cat", Quickshell.env("HOME") + "/.config/kitty/themes/noctalia.conf"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/)
                    if (p.length >= 2 && p[1].charAt(0) === "#") m[p[0]] = p[1]
                }
                if (m.background) root.bg = m.background
                if (m.color0) root.surface = m.color0
                if (m.foreground) root.fg = m.foreground
                if (m.color8) root.dim = m.color8
                if (m.active_border_color) root.accent = m.active_border_color
                if (m.color5) root.accent2 = m.color5
            }
        }
    }


    function refresh() {
        var q = query.trim().toLowerCase()
        var apps = DesktopEntries.applications.values
        var starts = [], has = [], all = []
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i]
            if (a.noDisplay) continue
            var n = (a.name || "").toLowerCase()
            if (q === "") { all.push(a); continue }
            var hay = n + " " + (a.genericName || "").toLowerCase() + " " + (a.comment || "").toLowerCase()
            if (n.indexOf(q) === 0) starts.push(a)
            else if (hay.indexOf(q) >= 0) has.push(a)
        }
        var byName = function(x, y) { return x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1 }
        results = q === "" ? all.sort(byName) : starts.sort(byName).concat(has.sort(byName))
        list.currentIndex = 0
        list.positionViewAtBeginning()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.refresh() }
    }
    Component.onCompleted: refresh()

    function launch(i) {
        if (i < 0 || i >= results.length) return
        results[i].execute()
        quitTimer.start()
    }
    Timer { id: quitTimer; interval: 120; onTriggered: Qt.quit() }

    function greeting() {
        var h = new Date().getHours()
        if (h < 5) return "Good night"
        if (h < 12) return "Good morning"
        if (h < 18) return "Good afternoon"
        return "Good evening"
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "launcher"

        Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.28)
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 220 } }
                MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
            }

            Item {
                id: panel
                width: 820
                height: 470
                anchors.centerIn: parent
                opacity: 0
                scale: 0.96
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

                MouseArea { anchors.fill: parent }

                RectangularShadow {
                    anchors.fill: bodyRect
                    radius: bodyRect.radius
                    blur: 40
                    spread: 2
                    offset: Qt.vector2d(0, 10)
                    color: Qt.rgba(0, 0, 0, 0.45)
                }

                Rectangle {
                    id: bodyRect
                    anchors.fill: parent
                    radius: 28
                    color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.94)
                    border.width: 2
                    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                }

                // ── Left: wallpaper banner ─────────────────────────────
                Item {
                    id: bannerBox
                    x: 12; y: 12
                    width: 290
                    height: parent.height - 24

                    Image {
                        id: bannerImg
                        anchors.fill: parent
                        source: root.banner ? "file://" + root.banner : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 700
                        asynchronous: true
                        visible: false
                    }
                    Rectangle {
                        id: bannerMask
                        anchors.fill: parent
                        radius: 20
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: bannerImg
                        maskEnabled: true
                        maskSource: bannerMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    // Fade to the panel colour at the bottom so the text reads
                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        gradient: Gradient {
                            GradientStop { position: 0.45; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.92) }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 22
                        spacing: 2
                        Text {
                            id: clock
                            text: Qt.formatTime(new Date(), "HH:mm")
                            font.family: "FantasqueSansM Nerd Font Mono"
                            font.pixelSize: 56
                            font.bold: true
                            color: root.fg
                            Timer { interval: 10000; running: true; repeat: true; onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm") }
                        }
                        Text {
                            text: root.greeting() + ", " + Quickshell.env("USER")
                            font.family: "FantasqueSansM Nerd Font Mono"
                            font.pixelSize: 17
                            color: root.accent
                        }
                        Text {
                            text: Qt.formatDate(new Date(), "dddd, d MMMM")
                            font.family: "FantasqueSansM Nerd Font Mono"
                            font.pixelSize: 14
                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.65)
                        }
                    }
                }

                // ── Right: search + list ───────────────────────────────
                Item {
                    anchors.left: bannerBox.right
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.top: parent.top
                    anchors.topMargin: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18

                    Rectangle {
                        id: searchBox
                        width: parent.width
                        height: 50
                        radius: 25
                        color: root.surface
                        border.width: 1
                        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)

                        Text {
                            id: glass
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            font.family: "FantasqueSansM Nerd Font Mono"
                            font.pixelSize: 20
                            color: root.accent
                        }
                        TextInput {
                            id: search
                            anchors.left: glass.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "FantasqueSansM Nerd Font Mono"
                            font.pixelSize: 17
                            color: root.fg
                            selectionColor: root.accent
                            clip: true
                            focus: true
                            onTextChanged: { root.query = text; root.refresh() }
                            Keys.onPressed: function(e) {
                                if (e.key === Qt.Key_Escape) Qt.quit()
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launch(list.currentIndex)
                                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) list.incrementCurrentIndex()
                                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) list.decrementCurrentIndex()
                                else if (e.key === Qt.Key_PageDown) list.currentIndex = Math.min(root.results.length - 1, list.currentIndex + 6)
                                else if (e.key === Qt.Key_PageUp) list.currentIndex = Math.max(0, list.currentIndex - 6)
                                else return
                                e.accepted = true
                            }
                            Text {
                                visible: search.text === ""
                                text: "What would you like to open?"
                                font: search.font
                                color: root.dim
                            }
                        }
                    }

                    ListView {
                        id: list
                        anchors.top: searchBox.bottom
                        anchors.topMargin: 14
                        anchors.bottom: parent.bottom
                        width: parent.width
                        clip: true
                        spacing: 4
                        model: root.results.length
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 160
                        highlightMoveVelocity: -1
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: height

                        highlight: Rectangle {
                            radius: 16
                            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                            border.width: 1
                            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                        }

                        delegate: Item {
                            id: row
                            required property int index
                            readonly property var app: root.results[index]
                            readonly property bool on: ListView.isCurrentItem
                            width: list.width
                            height: 52

                            Rectangle {
                                id: iconBg
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 38; height: 38; radius: 12
                                color: row.on ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : root.surface
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Image {
                                    anchors.centerIn: parent
                                    width: 26; height: 26
                                    sourceSize: Qt.size(64, 64)
                                    source: row.app ? Quickshell.iconPath(row.app.icon, "application-x-executable") : ""
                                    smooth: true
                                    asynchronous: true
                                }
                            }
                            Column {
                                anchors.left: iconBg.right
                                anchors.leftMargin: 14
                                anchors.right: arrow.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: row.app ? row.app.name : ""
                                    font.family: "FantasqueSansM Nerd Font Mono"
                                    font.pixelSize: 16
                                    font.bold: row.on
                                    color: row.on ? root.accent : root.fg
                                }
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                    text: row.app ? (row.app.genericName || row.app.comment || "") : ""
                                    font.family: "FantasqueSansM Nerd Font Mono"
                                    font.pixelSize: 12
                                    color: root.dim
                                }
                            }
                            Text {
                                id: arrow
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                font.family: "FantasqueSansM Nerd Font Mono"
                                font.pixelSize: 14
                                color: root.accent
                                opacity: row.on ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: list.currentIndex = row.index
                                onClicked: root.launch(row.index)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.results.length === 0
                            text: "Nothing here…"
                            font.family: "FantasqueSansM Nerd Font Mono"
                            font.pixelSize: 16
                            color: root.dim
                        }
                    }
                }
            }
        }
    }
}
