import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// AI chat panel for the bar: talk to Claude or Codex (switch at the top).
// Backend: ~/.local/bin/aichat-send. Colours follow the Noctalia theme.
ShellRoot {
    id: root

    readonly property string backend: Quickshell.env("HOME") + "/.local/bin/aichat-send"

    property bool shown: false
    property string provider: "claude"          // claude | codex
    property bool busy: false
    property string status: ""
    property string errorText: ""
    property string convId: ""
    property bool showHistory: false
    property bool confirmClear: false
    readonly property string icons: "FantasqueSansM Nerd Font"

    // Palette (overwritten from the theme file)
    property color bg: "#1c1a23"
    property color surface: "#242130"
    property color fg: "#f2f2f3"
    property color dim: "#8a8794"
    property color accent: "#9286c5"
    readonly property color claudeColor: "#e0916a"
    readonly property color codexColor: "#6cc4d8"
    readonly property color brand: provider === "claude" ? claudeColor : codexColor
    readonly property string brandName: provider === "claude" ? "Claude" : "Codex"

    component ToolTipLabel: Rectangle {
        property bool shown: false
        property string label: ""
        visible: shown
        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: tipText.implicitWidth + 16; height: 24; radius: 12
        color: root.fg
        z: 50
        Text { id: tipText; anchors.centerIn: parent; text: parent.label; color: root.bg; font.pixelSize: 11; font.bold: true }
    }

    ListModel { id: chat }
    ListModel { id: convs }

    // The panel stays loaded in the background; the bar button just shows/hides it.
    function show() { shown = true; input.forceActiveFocus() }
    function hide() { shown = false }
    IpcHandler {
        target: "aichat"
        function toggle(): void { root.shown ? root.hide() : root.show() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
    }

    function addMsg(role, text) { chat.append({ role: role, text: text }) }

    function fillChat(d) {
        chat.clear()
        convId = d && d.id ? d.id : ""
        if (d && d.messages) for (var i = 0; i < d.messages.length; i++) addMsg(d.messages[i].role, d.messages[i].text)
        list.positionViewAtEnd()
    }

    // Opens the newest conversation of the current provider (or an empty chat).
    function loadHistory() {
        chat.clear()
        convId = ""
        errorText = ""
        status = ""
        loader.mode = "latest"
        loader.command = [backend, "latest", provider]
        loader.running = true
    }

    function switchTo(p) {
        if (busy || p === provider) return
        provider = p
        showHistory = false
        loadHistory()
    }

    function openHistory() {
        if (showHistory) { showHistory = false; return }
        confirmClear = false
        lister.running = true
        showHistory = true
    }

    function openConv(id) {
        if (busy) return
        loader.mode = "open"
        loader.command = [backend, "load", id]
        loader.running = true
    }

    function deleteConv(id) {
        delProc.command = [backend, "delete", id]
        delProc.running = true
        for (var i = 0; i < convs.count; i++) if (convs.get(i).id === id) { convs.remove(i); break }
        if (id === convId) { chat.clear(); convId = "" }
    }

    function clearChat() {
        if (chat.count === 0 && convId === "") return
        if (!confirmClear) { confirmClear = true; clearTimer.restart(); return }
        confirmClear = false
        if (busy) stop()
        if (convId !== "") deleteConv(convId)
        chat.clear()
        convId = ""
        errorText = ""
        status = ""
    }

    function relTime(ts) {
        var d = Math.max(0, Date.now() / 1000 - ts)
        if (d < 60) return "just now"
        if (d < 3600) return Math.floor(d / 60) + " min ago"
        if (d < 86400) return Math.floor(d / 3600) + " h ago"
        if (d < 172800) return "yesterday"
        return Math.floor(d / 86400) + " days ago"
    }

    function send() {
        var t = input.text.trim()
        if (t === "" || busy) return
        addMsg("user", t)
        addMsg("assistant", "")
        input.text = ""
        errorText = ""
        status = "Thinking…"
        busy = true
        showHistory = false
        confirmClear = false
        sender.command = [backend, "send", provider, convId]
        sender.environment = { "AICHAT_PROMPT": t }
        sender.running = true
        list.positionViewAtEnd()
    }

    function stop() {
        if (!busy) return
        sender.running = false
    }

    function newChat() {
        if (busy) stop()
        chat.clear()
        convId = ""
        errorText = ""
        status = ""
        showHistory = false
        input.forceActiveFocus()
    }

    function onLine(line) {
        var e
        try { e = JSON.parse(line) } catch (x) { return }
        var last = chat.count - 1
        if (e.t === "conv") {
            convId = e.id
        } else if (e.t === "delta") {
            status = ""
            if (last >= 0) chat.setProperty(last, "text", chat.get(last).text + e.text)
        } else if (e.t === "status") {
            status = e.text
        } else if (e.t === "error") {
            errorText = e.text
            if (last >= 0 && chat.get(last).text === "") chat.remove(last)
        }
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
            }
        }
    }

    Process {
        id: loader
        property string mode: "latest"
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.fillChat(d)
                    if (loader.mode === "open") {
                        if (d.provider) root.provider = d.provider
                        root.showHistory = false
                        input.forceActiveFocus()
                    }
                } catch (x) {}
            }
        }
    }

    Process {
        id: lister
        command: [root.backend, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                convs.clear()
                try {
                    var a = JSON.parse(text)
                    for (var i = 0; i < a.length; i++) convs.append(a[i])
                } catch (x) {}
            }
        }
    }

    Process { id: delProc }
    Timer { id: clearTimer; interval: 3000; onTriggered: root.confirmClear = false }

    Process {
        id: sender
        stdout: SplitParser { onRead: function(data) { root.onLine(data) } }
        onExited: {
            root.busy = false
            root.status = ""
            input.forceActiveFocus()
        }
    }

    Component.onCompleted: loadHistory()
    onShownChanged: if (shown) focusTimer.restart()
    Timer { id: focusTimer; interval: 60; onTriggered: input.forceActiveFocus() }

    PanelWindow {
        id: win
        visible: root.shown
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "aichat"

        // Click outside the panel closes it.
        MouseArea { anchors.fill: parent; onClicked: root.hide() }

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            Keys.onPressed: function(e) {
                if (e.key === Qt.Key_Escape) { root.hide(); e.accepted = true }
            }

            RectangularShadow {
                anchors.fill: panel
                radius: panel.radius
                blur: 40
                spread: 2
                offset: Qt.vector2d(0, 10)
                color: "#99000000"
            }

            Rectangle {
                id: panel
                width: 470
                height: Math.min(stage.height - 70, 680)
                x: stage.width - width - 14
                y: 46
                radius: 24
                color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(root.brand.r, root.brand.g, root.brand.b, 0.45)
                clip: true

                MouseArea { anchors.fill: parent }   // swallow clicks inside the panel

                // ── Header ──
                Item {
                    id: header
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 64

                    // Provider switch
                    Rectangle {
                        id: track
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 196; height: 38; radius: 19
                        color: root.surface

                        Rectangle {
                            id: thumb
                            width: parent.width / 2 - 4; height: parent.height - 8; radius: 15
                            y: 4
                            x: root.provider === "claude" ? 4 : parent.width / 2
                            color: root.brand
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: [{ id: "claude", name: "Claude" }, { id: "codex", name: "Codex" }]
                                delegate: Item {
                                    width: track.width / 2; height: track.height
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        font.pixelSize: 14; font.bold: true
                                        color: root.provider === modelData.id ? root.bg : root.dim
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.switchTo(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Repeater {
                            model: [
                                { id: "history", g: "\uf1da", tip: "History" },
                                { id: "new",     g: "\uf067", tip: "New chat" },
                                { id: "clear",   g: "\uf1f8", tip: "Clear chat" },
                                { id: "close",   g: "\uf00d", tip: "Close" }
                            ]
                            delegate: Rectangle {
                                readonly property bool on: (modelData.id === "history" && root.showHistory)
                                readonly property bool warn: (modelData.id === "clear" && root.confirmClear)
                                width: 34; height: 34; radius: 17
                                color: warn ? "#f7768e" : (on ? Qt.rgba(root.brand.r, root.brand.g, root.brand.b, 0.25)
                                       : (hit.containsMouse ? root.surface : "transparent"))
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.g
                                    font.family: root.icons
                                    font.pixelSize: 15
                                    color: warn ? root.bg : (on ? root.brand : (hit.containsMouse ? root.fg : root.dim))
                                }
                                MouseArea {
                                    id: hit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.id === "history") root.openHistory()
                                        else if (modelData.id === "new") root.newChat()
                                        else if (modelData.id === "clear") root.clearChat()
                                        else root.hide()
                                    }
                                }
                                ToolTipLabel { shown: hit.containsMouse; label: warn ? "Click again to confirm" : modelData.tip }
                            }
                        }
                    }

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16 }
                        height: 1
                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                    }
                }

                // ── Messages ──
                ListView {
                    id: list
                    anchors { top: header.bottom; bottom: composer.top; left: parent.left; right: parent.right }
                    anchors.topMargin: 6
                    clip: true
                    spacing: 12
                    model: chat
                    leftMargin: 16; rightMargin: 16; topMargin: 10; bottomMargin: 10
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: if (root.busy) positionViewAtEnd()

                    delegate: Item {
                        width: list.width - 32
                        height: bubble.height

                        readonly property bool mine: model.role === "user"

                        readonly property real maxW: parent.width * 0.9

                        Rectangle {
                            id: bubble
                            x: mine ? parent.width - width : 0
                            width: mine ? Math.min(maxW, userText.implicitWidth + 28)
                                        : Math.max(54, aiText.contentWidth + 28)
                            height: (mine ? userText.implicitHeight : Math.max(aiText.implicitHeight, 20)) + 22
                            radius: 18
                            color: mine ? Qt.rgba(root.brand.r, root.brand.g, root.brand.b, 0.92)
                                        : root.surface
                            border.width: mine ? 0 : 1
                            border.color: Qt.rgba(root.brand.r, root.brand.g, root.brand.b, 0.22)

                            Text {
                                id: userText
                                visible: mine
                                x: 14; y: 11
                                width: maxW - 28
                                text: model.text
                                wrapMode: Text.Wrap
                                color: root.bg
                                font.pixelSize: 14
                            }

                            Text {
                                id: aiText
                                visible: !mine
                                x: 14; y: 11
                                width: maxW - 28
                                text: model.text === "" ? "···" : model.text
                                textFormat: model.text === "" ? Text.PlainText : Text.MarkdownText
                                wrapMode: Text.Wrap
                                color: model.text === "" ? root.dim : root.fg
                                font.pixelSize: 14
                                lineHeight: 1.18
                                linkColor: root.brand
                                onLinkActivated: function(l) { Qt.openUrlExternally(l) }
                            }
                        }
                    }

                    // Empty state
                    Column {
                        visible: chat.count === 0
                        anchors.centerIn: parent
                        spacing: 10
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 56; height: 56; radius: 28
                            color: Qt.rgba(root.brand.r, root.brand.g, root.brand.b, 0.16)
                            Text { anchors.centerIn: parent; text: "✦"; font.pixelSize: 26; color: root.brand }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Chat with " + root.brandName
                            color: root.fg; font.pixelSize: 18; font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ask anything — Enter to send"
                            color: root.dim; font.pixelSize: 13
                        }
                    }
                }

                // ── History ──
                Rectangle {
                    id: historyView
                    visible: root.showHistory
                    anchors { top: header.bottom; bottom: composer.top; left: parent.left; right: parent.right }
                    anchors.topMargin: 1
                    color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 1)

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        spacing: 8
                        model: convs
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: card
                            width: ListView.view.width
                            height: 64
                            radius: 16
                            readonly property color pc: model.provider === "claude" ? root.claudeColor : root.codexColor
                            readonly property bool current: model.id === root.convId
                            color: cardHit.containsMouse ? Qt.lighter(root.surface, 1.25) : root.surface
                            border.width: current ? 1 : 0
                            border.color: pc

                            Rectangle {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                width: 10; height: 10; radius: 5; color: card.pc
                            }
                            Column {
                                anchors { left: parent.left; leftMargin: 36; right: delBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 4
                                Text {
                                    width: parent.width
                                    text: model.title
                                    color: root.fg; font.pixelSize: 14; font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: (model.provider === "claude" ? "Claude" : "Codex") + "  ·  " + Math.ceil(model.count / 2) + " msg  ·  " + root.relTime(model.updated)
                                    color: root.dim; font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: cardHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openConv(model.id)
                            }
                            Rectangle {
                                id: delBtn
                                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                width: 32; height: 32; radius: 16
                                opacity: cardHit.containsMouse || delHit.containsMouse ? 1 : 0
                                color: delHit.containsMouse ? "#f7768e" : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf1f8"
                                    font.family: root.icons; font.pixelSize: 14
                                    color: delHit.containsMouse ? root.bg : root.dim
                                }
                                MouseArea {
                                    id: delHit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteConv(model.id)
                                }
                            }
                        }

                        Text {
                            visible: convs.count === 0
                            anchors.centerIn: parent
                            text: "No conversations yet"
                            color: root.dim; font.pixelSize: 14
                        }
                    }
                }

                // ── Composer ──
                Item {
                    id: composer
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: box.height + statusLine.height + 26

                    Text {
                        id: statusLine
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 20; rightMargin: 20 }
                        height: text === "" ? 0 : 20
                        text: root.errorText !== "" ? "⚠  " + root.errorText : (root.busy ? "●  " + root.status : "")
                        color: root.errorText !== "" ? "#f7768e" : root.brand
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: box
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 14 }
                        height: Math.min(150, Math.max(48, inputFlick.contentHeight + 22))
                        radius: 24
                        color: root.surface
                        border.width: input.activeFocus ? 1 : 0
                        border.color: Qt.rgba(root.brand.r, root.brand.g, root.brand.b, 0.7)

                        Flickable {
                            id: inputFlick
                            anchors { left: parent.left; right: sendBtn.left; top: parent.top; bottom: parent.bottom; leftMargin: 18; rightMargin: 8; topMargin: 11; bottomMargin: 11 }
                            contentWidth: width
                            contentHeight: input.contentHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: input
                                width: inputFlick.width
                                color: root.fg
                                font.pixelSize: 14
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                selectionColor: root.brand
                                selectedTextColor: root.bg
                                focus: true
                                Component.onCompleted: forceActiveFocus()
                                Keys.onPressed: function(e) {
                                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                                        root.send(); e.accepted = true
                                    } else if (e.key === Qt.Key_Escape) {
                                        root.hide(); e.accepted = true
                                    } else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_N) {
                                        root.newChat(); e.accepted = true
                                    } else if (e.key === Qt.Key_Tab) {
                                        root.switchTo(root.provider === "claude" ? "codex" : "claude"); e.accepted = true
                                    }
                                }
                                Text {
                                    visible: input.text === ""
                                    text: "Message " + root.brandName + "…"
                                    color: root.dim
                                    font: input.font
                                }
                            }
                        }

                        Rectangle {
                            id: sendBtn
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 34; height: 34; radius: 17
                            color: root.busy ? root.dim : root.brand
                            opacity: (root.busy || input.text.trim() !== "") ? 1 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: root.busy ? "■" : "↑"
                                color: root.bg
                                font.pixelSize: root.busy ? 12 : 18
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.busy ? root.stop() : root.send()
                            }
                        }
                    }
                }
            }
        }
    }
}
