import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.Commons

Item {
  id: root

  property bool opened: false
  property bool settingsMode: false
  property var windows: []
  property var monitors: []
  property int loadGeneration: 0
  property string hintKeys: "asdfghjklqwertyuiopzxcvbnm"
  readonly property string snapshotPath: Qt.resolvedUrl("bin/current").toString().replace("file://", "")
  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/vimarchy.json"
  property real windowTintOpacity: 0.03
  property real badgeTintOpacity: 0.10
  property bool settingsLoaded: false

  function setOpacity(name, value) {
    var next = Math.max(0, Math.min(0.30, Math.round(value * 100) / 100))
    if (name === "window") root.windowTintOpacity = next
    else root.badgeTintOpacity = next
    if (root.settingsLoaded) settingsSaveTimer.restart()
  }

  function loadSettings(raw) {
    var data = {}
    try { data = JSON.parse(raw || "{}") } catch (error) { data = {} }
    var windowOpacity = Number(data.windowTintOpacity)
    var badgeOpacity = Number(data.badgeTintOpacity)
    root.windowTintOpacity = isFinite(windowOpacity) ? Math.max(0, Math.min(0.30, windowOpacity)) : 0.03
    root.badgeTintOpacity = isFinite(badgeOpacity) ? Math.max(0, Math.min(0.30, badgeOpacity)) : 0.10
    root.settingsLoaded = true
  }

  function saveSettings() {
    if (!root.settingsLoaded) return
    settingsFile.setText(JSON.stringify({
      windowTintOpacity: root.windowTintOpacity,
      badgeTintOpacity: root.badgeTintOpacity
    }, null, 2) + "\n")
  }

  function open(payloadJson) {
    try {
      var payload = JSON.parse(String(payloadJson || "{}"))
      if (payload.mode === "settings") {
        root.settingsMode = true
        root.opened = true
        return
      }
    } catch (error) { /* A malformed snapshot is handled below. */ }
    if (snapshotProcess.running) return
    root.settingsMode = false
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
    root.settingsMode = false
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

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
    onFileChanged: reload()
  }

  Timer {
    id: settingsSaveTimer
    interval: 150
    repeat: false
    onTriggered: root.saveSettings()
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: overlay
      required property var modelData
      screen: modelData
      visible: root.opened && !root.settingsMode

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
              windowHint.accentColor.b, root.windowTintOpacity)
            border.width: Math.max(2, Style.space(2))
            border.color: windowHint.accentColor
            radius: Style.cornerRadius
          }

          Rectangle {
            id: badge
            anchors.centerIn: parent
            width: windowHint.badgeSize
            height: windowHint.badgeSize
            radius: width / 2
            color: Qt.rgba(windowHint.accentColor.r, windowHint.accentColor.g,
              windowHint.accentColor.b, root.badgeTintOpacity)

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

  PanelWindow {
    id: settingsWindow
    visible: root.opened && root.settingsMode
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vimarchy-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: settingsCard }

    Rectangle {
      id: settingsCard
      width: 440
      height: 250
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      border.width: Math.max(1, Style.space(1))
      border.color: Color.menu.border

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(24)
        spacing: Style.space(18)

        Text {
          text: "Vimarchy opacity"
          color: Color.menu.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.heading
          font.bold: true
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          Row {
            width: parent.width
            Text { text: "Window background"; color: Color.menu.text; font.family: Style.font.menuFamily; width: parent.width - 60 }
            Text { text: Math.round(root.windowTintOpacity * 100) + "%"; color: Color.menu.text; font.family: Style.font.menuFamily; width: 60; horizontalAlignment: Text.AlignRight }
          }
          Slider {
            width: parent.width
            from: 0; to: 0.30; stepSize: 0.01
            value: root.windowTintOpacity
            onMoved: root.setOpacity("window", value)
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          Row {
            width: parent.width
            Text { text: "Hint box background"; color: Color.menu.text; font.family: Style.font.menuFamily; width: parent.width - 60 }
            Text { text: Math.round(root.badgeTintOpacity * 100) + "%"; color: Color.menu.text; font.family: Style.font.menuFamily; width: 60; horizontalAlignment: Text.AlignRight }
          }
          Slider {
            width: parent.width
            from: 0; to: 0.30; stepSize: 0.01
            value: root.badgeTintOpacity
            onMoved: root.setOpacity("badge", value)
          }
        }

        Rectangle {
          width: 84
          height: 34
          anchors.right: parent.right
          radius: Style.cornerRadius
          color: Color.menu.selectedBackground
          Text { anchors.centerIn: parent; text: "Done"; color: Color.menu.selectedText; font.family: Style.font.menuFamily }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
        }
      }
    }
  }
}
