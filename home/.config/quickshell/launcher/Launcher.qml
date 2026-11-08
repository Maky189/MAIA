pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Cozy launcher: art banner with clock + greeting on the left, search and apps on
// the right. Colours come from the Noctalia theme (kitty's noctalia.conf), so the
// launcher always matches the current wallpaper.
ShellRoot {
    id: root

    property bool gridMode: false
    readonly property var appView: gridMode ? grid : list
    property string query: ""
    property var results: []
    readonly property string uiFont: "Noto Sans"
    readonly property string monoFont: "FantasqueSansM Nerd Font Mono"
    readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.58)
    readonly property color outline: Qt.rgba(fg.r, fg.g, fg.b, 0.09)

    function tint(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity)
    }

    function appId(app) {
        return (app.id || "").replace(/\.desktop$/, "")
    }

    function displayName(app) {
        if (!app) return ""
        if (appId(app) === "spotify-launcher") return "Spotify"
        // Toolbox puts build numbers in its launcher names; keep labels calm.
        return app.name.replace(/\s+\d{4}\.\d+(?:\.\d+)*$/, "")
    }
    // launcher-toggle chooses artwork before opening either layout.
    // Original fallback: "Akiyama Mio" by Riovannes (wallhaven-rr955q).
    property string banner: Quickshell.env("MAIA_LAUNCHER_BANNER")
        || Quickshell.env("HOME") + "/.config/quickshell/launcher/banner.jpg"

    // Palette (defaults are overwritten from the theme file)
    property color bg: "#231b1a"
    property color surface: "#302421"
    property color fg: "#f3f2f2"
    property color dim: "#726562"
    property color accent: "#e7b5ab"
    property color accent2: "#deaba1"

    IpcHandler {
        target: "launcher"
        function close(): void { Qt.quit() }
    }

    function moveSelection(delta) {
        if (results.length === 0) return
        appView.currentIndex = Math.max(0, Math.min(results.length - 1, appView.currentIndex + delta))
        appView.positionViewAtIndex(appView.currentIndex, ListView.Contain)
    }

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
            if (a.noDisplay || appId(a) === "maia-launcher-grid") continue
            var n = (a.name || "").toLowerCase()
            if (q === "") { all.push(a); continue }
            var hay = n + " " + (a.genericName || "").toLowerCase() + " " + (a.comment || "").toLowerCase()
            if (n.indexOf(q) === 0) starts.push(a)
            else if (hay.indexOf(q) >= 0) has.push(a)
        }
        var byName = function(x, y) { return x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1 }
        results = q === "" ? all.sort(byName) : starts.sort(byName).concat(has.sort(byName))
        appView.currentIndex = results.length > 0 ? 0 : -1
        appView.positionViewAtBeginning()
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
                color: root.tint(root.bg, 0.42)
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 180 } }
                MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
            }

            Item {
                id: panel
                width: Math.min(root.gridMode ? 1160 : 940, parent.width - 64)
                height: Math.min(root.gridMode ? 720 : 660, parent.height - 80)
                anchors.centerIn: parent
                opacity: 0
                scale: 0.98
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                MouseArea { anchors.fill: parent }

                RectangularShadow {
                    anchors.fill: bodyRect
                    radius: bodyRect.radius
                    blur: 64
                    spread: 4
                    offset: Qt.vector2d(0, 18)
                    color: Qt.rgba(0, 0, 0, 0.42)
                }

                Rectangle {
                    id: bodyRect
                    anchors.fill: parent
                    radius: 32
                    color: root.tint(root.bg, 0.985)
                    border.width: 1
                    border.color: root.outline
                }

                // Artwork has its own generous inset, separate from the app area.
                Item {
                    id: bannerBox
                    visible: panel.width >= 900
                    x: 20; y: 20
                    width: visible ? (root.gridMode ? 280 : 260) : 0
                    height: parent.height - 40

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
                        radius: 22
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
                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        gradient: Gradient {
                            GradientStop { position: 0.30; color: "transparent" }
                            GradientStop { position: 0.70; color: root.tint(root.bg, 0.30) }
                            GradientStop { position: 1.0; color: root.tint(root.bg, 0.96) }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: "transparent"
                        border.color: root.tint(root.fg, 0.07)
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 26
                        spacing: 8
                        Text {
                            id: clock
                            text: Qt.formatTime(new Date(), "HH:mm")
                            font.family: root.monoFont
                            font.pixelSize: 50
                            font.bold: true
                            color: root.fg
                            Timer { interval: 10000; running: true; repeat: true; onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm") }
                        }
                        Text {
                            width: parent.width
                            text: root.greeting() + ", " + Quickshell.env("USER")
                            elide: Text.ElideRight
                            font.family: root.uiFont
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: root.fg
                        }
                        Text {
                            text: Qt.formatDate(new Date(), "dddd, d MMMM")
                            font.family: root.uiFont
                            font.pixelSize: 12
                            color: root.muted
                        }
                    }
                }

                Item {
                    id: content
                    anchors.left: parent.left
                    anchors.leftMargin: bannerBox.visible ? bannerBox.x + bannerBox.width + 32 : 32
                    anchors.right: parent.right
                    anchors.rightMargin: 32
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24

                    Item {
                        id: heading
                        width: parent.width
                        height: 52
                        Column {
                            spacing: 4
                            Text {
                                text: "Applications"
                                font.family: root.uiFont
                                font.pixelSize: 26
                                font.weight: Font.DemiBold
                                font.letterSpacing: -0.6
                                color: root.fg
                            }
                            Text {
                                text: root.query.trim() !== "" ? "Search across your apps" : "Everything on your desktop"
                                font.family: root.uiFont
                                font.pixelSize: 12
                                color: root.muted
                            }
                        }
                        Rectangle {
                            width: 34; height: 34; radius: 12
                            anchors.right: parent.right
                            anchors.top: parent.top
                            color: closeMouse.containsMouse ? root.tint(root.fg, 0.10) : root.tint(root.fg, 0.04)
                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.family: root.uiFont
                                font.pixelSize: 24
                                color: root.muted
                            }
                            Accessible.name: "Close launcher"
                            Accessible.role: Accessible.Button
                            Accessible.onPressAction: Qt.quit()
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }
                    }

                    Rectangle {
                        id: searchBox
                        anchors.top: heading.bottom
                        anchors.topMargin: 24
                        width: parent.width
                        height: 56
                        radius: 18
                        color: root.tint(root.surface, 0.70)
                        border.width: 1
                        border.color: search.activeFocus ? root.tint(root.accent, 0.30) : root.outline
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            id: glass
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            font.family: root.monoFont
                            font.pixelSize: 17
                            color: root.accent
                        }
                        TextInput {
                            id: search
                            objectName: "launcherSearch"
                            anchors.left: glass.right
                            anchors.leftMargin: 14
                            anchors.right: clearButton.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: root.uiFont
                            font.pixelSize: 15
                            color: root.fg
                            selectionColor: root.tint(root.accent, 0.35)
                            selectedTextColor: root.fg
                            clip: true
                            focus: true
                            selectByMouse: true
                            Accessible.name: "Search applications"
                            onTextChanged: { root.query = text; root.refresh() }
                            Keys.onPressed: function(e) {
                                if (e.key === Qt.Key_Escape) Qt.quit()
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launch(root.appView.currentIndex)
                                else if (e.key === Qt.Key_Down) root.moveSelection(root.gridMode ? grid.columns : 1)
                                else if (e.key === Qt.Key_Up) root.moveSelection(root.gridMode ? -grid.columns : -1)
                                else if (e.key === Qt.Key_Tab) root.moveSelection(e.modifiers & Qt.ShiftModifier ? -1 : 1)
                                else if (e.key === Qt.Key_Backtab) root.moveSelection(-1)
                                else if (root.gridMode && text === "" && e.key === Qt.Key_Right) root.moveSelection(1)
                                else if (root.gridMode && text === "" && e.key === Qt.Key_Left) root.moveSelection(-1)
                                else if (e.key === Qt.Key_PageDown) root.moveSelection(root.gridMode ? grid.columns * Math.max(1, Math.floor(grid.height / grid.cellHeight)) : 5)
                                else if (e.key === Qt.Key_PageUp) root.moveSelection(root.gridMode ? -grid.columns * Math.max(1, Math.floor(grid.height / grid.cellHeight)) : -5)
                                else return
                                e.accepted = true
                            }
                            Text {
                                visible: search.text === ""
                                text: "Search your apps…"
                                font: search.font
                                color: root.muted
                            }
                        }
                        Item {
                            id: clearButton
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30; height: 30
                            visible: search.text !== ""
                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.family: root.uiFont
                                font.pixelSize: 20
                                color: root.muted
                            }
                            Accessible.name: "Clear search"
                            Accessible.role: Accessible.Button
                            Accessible.onPressAction: search.clear()
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { search.clear(); search.forceActiveFocus() }
                            }
                        }
                    }

                    Item {
                        id: toolbar
                        anchors.top: searchBox.bottom
                        anchors.topMargin: 22
                        width: parent.width
                        height: 24
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.query.trim() !== "" ? "Search results" : "All apps"
                            font.family: root.uiFont
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: root.muted
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.results.length + (root.results.length === 1 ? " app" : " apps")
                            font.family: root.uiFont
                            font.pixelSize: 12
                            color: root.muted
                        }
                    }

                    ListView {
                        id: list
                        objectName: "launcherList"
                        visible: !root.gridMode
                        anchors.top: toolbar.bottom
                        anchors.topMargin: 16
                        width: parent.width
                        height: Math.max(0, Math.floor((footer.y - y - 18 + spacing) / (62 + spacing)) * (62 + spacing) - spacing)
                        clip: true
                        spacing: 8
                        model: root.gridMode ? 0 : root.results.length
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 130
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: height
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                        delegate: Item {
                            id: row
                            required property int index
                            readonly property var app: root.results[index]
                            readonly property bool selected: ListView.isCurrentItem
                            width: list.width - 12
                            height: 62
                            Accessible.name: app ? app.name : ""
                            Accessible.role: Accessible.Button
                            Accessible.onPressAction: root.launch(index)
                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: row.selected ? root.tint(root.accent, 0.10) : root.tint(root.surface, 0.22)
                                border.color: row.selected ? root.tint(root.accent, 0.20) : "transparent"
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                            Image {
                                id: rowIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34; height: 34
                                sourceSize: Qt.size(80, 80)
                                source: row.app ? Quickshell.iconPath(row.app.icon, "application-x-executable") : ""
                                smooth: true
                                asynchronous: true
                            }
                            Column {
                                anchors.left: rowIcon.right
                                anchors.leftMargin: 18
                                anchors.right: parent.right
                                anchors.rightMargin: 38
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    width: parent.width
                                    text: root.displayName(row.app)
                                    elide: Text.ElideRight
                                    font.family: root.uiFont
                                    font.pixelSize: 14
                                    font.weight: row.selected ? Font.DemiBold : Font.Medium
                                    color: root.fg
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: row.app ? (row.app.genericName || row.app.comment || "") : ""
                                    elide: Text.ElideRight
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    color: root.muted
                                }
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↵"
                                font.family: root.uiFont
                                font.pixelSize: 18
                                color: root.accent
                                opacity: row.selected ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: list.currentIndex = row.index
                                onClicked: root.launch(row.index)
                            }
                        }
                    }

                    GridView {
                        id: grid
                        objectName: "launcherGrid"
                        visible: root.gridMode
                        anchors.top: toolbar.bottom
                        anchors.topMargin: 16
                        anchors.bottom: footer.top
                        anchors.bottomMargin: 18
                        width: parent.width
                        clip: true
                        readonly property int columns: Math.max(1, Math.floor((width - 8) / 142))
                        cellWidth: (width - 8) / columns
                        readonly property int visibleRows: Math.max(1, Math.floor(height / 126))
                        cellHeight: height / visibleRows
                        model: root.gridMode ? root.results.length : 0
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        highlightRangeMode: GridView.ApplyRange
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: height
                        highlightMoveDuration: 130
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                        delegate: Item {
                            id: tile
                            required property int index
                            readonly property var app: root.results[index]
                            readonly property bool selected: GridView.isCurrentItem
                            width: grid.cellWidth
                            height: grid.cellHeight
                            Accessible.name: app ? app.name : ""
                            Accessible.role: Accessible.Button
                            Accessible.onPressAction: root.launch(index)

                            Rectangle {
                                anchors.fill: parent
                                anchors.rightMargin: 12
                                anchors.bottomMargin: 12
                                radius: 20
                                color: tile.selected ? root.tint(root.accent, 0.10) : tileMouse.containsMouse ? root.tint(root.surface, 0.70) : root.tint(root.surface, 0.28)
                                border.width: 1
                                border.color: tile.selected ? root.tint(root.accent, 0.24) : "transparent"
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Column {
                                    y: 18
                                    width: parent.width - 20
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 12
                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 48; height: 48
                                        sourceSize: Qt.size(112, 112)
                                        source: tile.app ? Quickshell.iconPath(tile.app.icon, "application-x-executable") : ""
                                        smooth: true
                                        asynchronous: true
                                        scale: tile.selected ? 1.06 : 1
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    }
                                    Text {
                                        width: parent.width
                                        height: 36
                                        text: root.displayName(tile.app)
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                        font.weight: tile.selected ? Font.DemiBold : Font.Medium
                                        color: root.fg
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignTop
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                anchors.rightMargin: 12
                                anchors.bottomMargin: 12
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: grid.currentIndex = tile.index
                                onClicked: root.launch(tile.index)
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: root.appView
                        width: root.appView.width
                        visible: root.results.length === 0
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No apps found"
                            font.family: root.uiFont
                            font.pixelSize: 18
                            font.weight: Font.Medium
                            color: root.fg
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Try a different name or clear your search."
                            font.family: root.uiFont
                            font.pixelSize: 12
                            color: root.muted
                        }
                    }

                    Item {
                        id: footer
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 24
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: -12
                            width: parent.width
                            height: 1
                            color: root.tint(root.fg, 0.06)
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 16
                            Repeater {
                                model: [{ key: "↑ ↓", label: "Navigate" }, { key: "↵", label: "Open" }, { key: "esc", label: "Close" }]
                                delegate: Row {
                                    required property var modelData
                                    spacing: 6
                                    Rectangle {
                                        width: hintKey.implicitWidth + 10
                                        height: 22
                                        radius: 6
                                        color: root.tint(root.fg, 0.05)
                                        Text {
                                            id: hintKey
                                            anchors.centerIn: parent
                                            text: modelData.key
                                            font.family: root.uiFont
                                            font.pixelSize: 10
                                            color: root.muted
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        font.family: root.uiFont
                                        font.pixelSize: 10
                                        color: root.muted
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
