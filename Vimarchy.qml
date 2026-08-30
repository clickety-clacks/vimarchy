import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons

Item {
  id: root

  property bool opened: false
  property var windows: []
  property var monitors: []
  property int loadGeneration: 0
  property string hintKeys: "asdfghjklqwertyuiopzxcvbnm"
  readonly property string snapshotPath: Qt.resolvedUrl("bin/current").toString().replace("file://", "")

  function open(payloadJson) {
    if (snapshotProcess.running) return
    root.opened = false
    root.loadGeneration++
    if (payloadJson && payloadJson !== "{}") {
      root.applySnapshot(payloadJson, root.loadGeneration)
      return
    }
    snapshotProcess.generation = root.loadGeneration
    snapshotProcess.command = [root.snapshotPath]
    snapshotProcess.running = true
  }

  function close() {
    root.loadGeneration++
    root.opened = false
    root.windows = []
    root.monitors = []
  }

  function toggle(payloadJson) {
    if (root.opened) root.close()
    else root.open(payloadJson || "{}")
  }

  function applySnapshot(raw, generation) {
    if (generation !== root.loadGeneration) return
    try {
      var data = JSON.parse(String(raw || "{}"))
      var nextWindows = data.windows || []
      var available = root.hintKeys.length * root.hintKeys.length

      root.monitors = data.monitors || []
      root.windows = nextWindows.filter(function(window) { return !!window.hint }).slice(0, available)
      root.opened = root.windows.length > 0
    } catch (error) {
      console.warn("vimarchy: could not parse Hyprland snapshot:", error)
      root.close()
    }
  }

  function monitorFor(name) {
    for (var i = 0; i < root.monitors.length; i++)
      if (root.monitors[i].name === name) return root.monitors[i]
    return null
  }

  function windowsFor(name) {
    var result = []
    for (var i = 0; i < root.windows.length; i++)
      if (root.windows[i].monitor === name) result.push(root.windows[i])
    return result
  }

  Process {
    id: snapshotProcess
    property int generation: 0
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySnapshot(text, snapshotProcess.generation)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") console.warn("vimarchy:", message)
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.close()
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: overlay
      required property var modelData
      screen: modelData
      visible: root.opened

      readonly property var monitor: root.monitorFor(modelData.name)
      readonly property bool focusedMonitor: monitor ? monitor.focused : false

      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "vimarchy"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Repeater {
        model: root.windowsFor(overlay.modelData.name)

        delegate: Item {
          id: windowHint
          required property var modelData
          readonly property color accentColor: modelData.focused
            ? Color.menu.selectedText : Color.menu.text
          readonly property int badgeSize: Math.max(72, Math.min(132,
            Math.min(modelData.size[0], modelData.size[1]) * 0.34))

          x: modelData.at[0] - overlay.monitor.x
          y: modelData.at[1] - overlay.monitor.y
          width: modelData.size[0]
          height: modelData.size[1]

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(windowHint.accentColor.r, windowHint.accentColor.g,
              windowHint.accentColor.b, 0.03)
            border.width: Math.max(2, Style.space(2))
            border.color: windowHint.accentColor
            radius: Style.cornerRadius
          }

          Rectangle {
            id: badge
            anchors.centerIn: parent
            width: windowHint.badgeSize
            height: windowHint.badgeSize
            radius: Math.min(Style.cornerRadius, width / 5)
            color: Qt.rgba(windowHint.accentColor.r, windowHint.accentColor.g,
              windowHint.accentColor.b, 0.10)

            Text {
              anchors.centerIn: parent
              text: windowHint.modelData.hint.toUpperCase()
              color: windowHint.accentColor
              font.family: Style.font.menuFamily
              font.pixelSize: Math.round(badge.height * (text.length > 1 ? 0.46 : 0.62))
              font.bold: true
            }
          }
        }
      }
    }
  }
}
