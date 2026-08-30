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
  property string hintKeys: "123456789"
  readonly property string snapshotPath: Qt.resolvedUrl("bin/current").toString().replace("file://", "")

  function open(payloadJson) {
    if (snapshotProcess.running) return
    root.opened = false
    root.loadGeneration++
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
      var available = root.hintKeys.length

      for (var i = 0; i < nextWindows.length && i < available; i++)
        nextWindows[i].hint = root.hintKeys.charAt(i)

      root.monitors = data.monitors || []
      root.windows = nextWindows.slice(0, available)
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

        delegate: Rectangle {
          id: badge
          required property var modelData
          readonly property int badgeSize: Math.max(72, Math.min(132,
            Math.min(modelData.size[0], modelData.size[1]) * 0.34))

          width: badgeSize
          height: badgeSize
          radius: Math.min(Style.cornerRadius, badgeSize / 5)
          x: modelData.at[0] - overlay.monitor.x + (modelData.size[0] - width) / 2
          y: modelData.at[1] - overlay.monitor.y + (modelData.size[1] - height) / 2
          color: modelData.focused ? Color.menu.selectedBackground : Color.menu.background
          border.width: Math.max(2, Style.space(2))
          border.color: Color.menu.border

          Text {
            anchors.centerIn: parent
            text: badge.modelData.hint.toUpperCase()
            color: badge.modelData.focused ? Color.menu.selectedText : Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Math.round(badge.height * 0.62)
            font.bold: true
          }
        }
      }
    }
  }
}
