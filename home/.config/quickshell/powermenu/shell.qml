import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Power menu: dimmed backdrop, five rounded cards. Arrows/Tab + Enter, or l/e/s/r/p. Esc closes.
ShellRoot {
    id: root

    property int sel: 2
    property bool going: false

    readonly property var actions: [
        { name: "Lock",     key: "L", icon: "",     col: "#7dcfff", cmd: ["noctalia", "msg", "session", "lock"] },
        { name: "Logout",   key: "E", icon: "",     col: "#9ece6a", cmd: ["loginctl", "terminate-user", Quickshell.env("USER")] },
        { name: "Suspend",  key: "S", icon: "",     col: "#bb9af7", cmd: ["systemctl", "suspend"] },
        { name: "Restart",  key: "R", icon: "",     col: "#e0af68", cmd: ["systemctl", "reboot"] },
        { name: "Shutdown", key: "P", icon: "",     col: "#f7768e", cmd: ["systemctl", "poweroff"] }
    ]

    function run(i) {
        if (going) return
        going = true
        runner.command = actions[i].cmd
        runner.running = true
        quitTimer.start()
    }

    Process { id: runner }
    Timer { id: quitTimer; interval: 350; onTriggered: Qt.quit() }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "powermenu"

        Item {
            id: stage
            anchors.fill: parent
            focus: true

            Keys.onPressed: function(e) {
                var n = root.actions.length
                if (e.key === Qt.Key_Escape || e.key === Qt.Key_Q) Qt.quit()
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.sel = (root.sel + n - 1) % n
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.sel = (root.sel + 1) % n
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.run(root.sel)
                else {
                    var t = e.text.toUpperCase()
                    for (var i = 0; i < n; i++) if (root.actions[i].key === t) { root.sel = i; root.run(i) }
                }
                e.accepted = true
            }

            Rectangle {
                id: dim
                anchors.fill: parent
                color: "#d8101420"
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 26

                Repeater {
                    model: root.actions
                    delegate: Item {
                        id: card
                        readonly property bool on: root.sel === index
                        width: 150; height: 190
                        opacity: 0
                        y: 40

                        Component.onCompleted: intro.start()
                        SequentialAnimation {
                            id: intro
                            PauseAnimation { duration: index * 55 }
                            ParallelAnimation {
                                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
                                NumberAnimation { target: card; property: "y"; to: 0; duration: 420; easing.type: Easing.OutBack }
                            }
                        }

                        scale: on ? 1.1 : 1.0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 30
                            color: card.on ? Qt.rgba(0.10, 0.11, 0.16, 0.92) : Qt.rgba(0.10, 0.11, 0.16, 0.62)
                            border.width: card.on ? 3 : 1
                            border.color: card.on ? modelData.col : "#40ffffff"
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 18
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icon
                                    font.family: "FantasqueSansM Nerd Font Mono"
                                    font.pixelSize: 54
                                    color: card.on ? modelData.col : "#c8d0e0"
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.name
                                    font.pixelSize: 17
                                    font.bold: true
                                    color: card.on ? "#ffffff" : "#9aa5be"
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                width: 22; height: 22; radius: 7
                                color: "transparent"
                                border.width: 1
                                border.color: card.on ? modelData.col : "#40ffffff"
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    font.pixelSize: 11
                                    color: card.on ? modelData.col : "#7a859e"
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.sel = index
                            onClicked: root.run(index)
                        }
                    }
                }
            }
        }
    }
}
