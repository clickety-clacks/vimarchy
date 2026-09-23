import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property bool opened: false
  property bool settingsOpen: false
  property var windows: []
  property var monitors: []
  property string swapSourceHint: ""
  property string workspaceSourceHint: ""
  property var workspaceTargets: []
  property real workspaceSpread: 0
  property string holdingHint: ""
  property real holdProgress: 0.0
  property real connectorVisualOpacity: connectorOpacity
  property string selectedHint: ""
  property real selectionPulse: 0.0
  property real exitOpacity: 1.0
  property real otherHintOpacity: 1.0
  property real badgeEntrance: 0.0
  readonly property bool exiting: selectedHint !== ""
  readonly property bool swapMode: swapSourceHint !== ""
  property int loadGeneration: 0
  property string hintKeys: "asdfghjklqwertyuiopzxcvbnm"
  readonly property var hintPalette: [
    "#818cf8", "#a78bfa", "#c084fc", "#e879f9", "#f472b6",
    "#fb7185", "#fb923c", "#facc15", "#a3e635", "#4ade80",
    "#2dd4bf", "#22d3ee", "#38bdf8", "#60a5fa"
  ]
  readonly property string snapshotPath: Qt.resolvedUrl("bin/current").toString().replace("file://", "")
  readonly property string cancelPath: Qt.resolvedUrl("bin/cancel").toString().replace("file://", "")
  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/vimarchy.json"
  property real windowTintOpacity: 0.07
  property real badgeTintOpacity: 0.21
  property real hintScale: 1.0
  readonly property real connectorOpacity: 0.60
  property bool settingsLoaded: false
  property var settingsData: ({})

  function setOpacity(name, value) {
    var next = Math.max(0, Math.min(0.30, Math.round(value * 100) / 100))
    if (name === "window") root.windowTintOpacity = next
    else root.badgeTintOpacity = next
    if (root.settingsLoaded) settingsSaveTimer.restart()
  }

  function colorForHint(hint) {
    var first = root.hintKeys.indexOf(String(hint || "").charAt(0))
    var second = root.hintKeys.indexOf(String(hint || "").charAt(1))
    var index = second < 0 ? first : first * root.hintKeys.length + second
    if (index < 0) index = 0
    return root.hintPalette[index % root.hintPalette.length]
  }

  function loadSettings(raw) {
    var data = {}
    try { data = JSON.parse(raw || "{}") } catch (error) { data = {} }
    root.settingsData = data
    var windowOpacity = Number(data.windowTintOpacity)
    var badgeOpacity = Number(data.badgeTintOpacity)
    var savedHintScale = Number(data.hintScale)
    root.windowTintOpacity = isFinite(windowOpacity) ? Math.max(0, Math.min(0.30, windowOpacity)) : 0.07
    root.badgeTintOpacity = isFinite(badgeOpacity) ? Math.max(0, Math.min(0.30, badgeOpacity)) : 0.21
    root.hintScale = isFinite(savedHintScale) ? Math.max(0.75, Math.min(1.50, savedHintScale)) : 1.0
    root.settingsLoaded = true
  }

  function saveSettings() {
    if (!root.settingsLoaded) return
    var data = {}
    var source = root.settingsData || {}
    for (var key in source) data[key] = source[key]
    data.windowTintOpacity = root.windowTintOpacity
    data.badgeTintOpacity = root.badgeTintOpacity
    data.hintScale = root.hintScale
    root.settingsData = data
    settingsFile.setText(JSON.stringify(data, null, 2) + "\n")
  }

  function adjustHintScale(delta) {
    var next = root.hintScale + Number(delta || 0) * 0.10
    root.hintScale = Math.max(0.75, Math.min(1.50, Math.round(next * 100) / 100))
    if (root.settingsLoaded) settingsSaveTimer.restart()
    return "ok"
  }

  function hintBadgeSize(size) {
    var base = Math.max(Style.space(72), Math.min(Style.space(132),
      Style.space(Math.min(size[0], size[1]) * 0.34)))
    return base * root.hintScale
  }

  function open(payloadJson) {
    try {
      var payload = JSON.parse(String(payloadJson || "{}"))
      if (payload.mode === "selected") {
        root.beginSelection(String(payload.hint || ""))
        return
      }
      if (payload.mode === "settings") {
        root.settingsOpen = true
        return
      }
    } catch (error) { /* A malformed snapshot is handled below. */ }
    if (snapshotProcess.running) return
    root.settingsOpen = false
    root.swapSourceHint = ""
    root.workspaceSourceHint = ""
    root.workspaceTargets = []
    root.holdingHint = ""
    root.holdProgress = 0.0
    root.connectorVisualOpacity = root.connectorOpacity
    root.selectedHint = ""
    root.exitOpacity = 1.0
    root.otherHintOpacity = 1.0
    selectionPulseAnimation.stop()
    root.selectionPulse = 0.0
    badgeEntranceAnimation.stop()
    root.badgeEntrance = 0.0
    selectionFade.stop()
    otherHintsFade.stop()
    selectionCloseTimer.stop()
    holdAnimation.stop()
    connectorFade.stop()
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
    selectionPulseAnimation.stop()
    root.selectionPulse = 0.0
    badgeEntranceAnimation.stop()
    selectionFade.stop()
    otherHintsFade.stop()
    selectionCloseTimer.stop()
    holdAnimation.stop()
    connectorFade.stop()
    root.loadGeneration++
    root.opened = false
    root.settingsOpen = false
    root.windows = []
    root.monitors = []
    root.workspaceSourceHint = ""
    root.workspaceTargets = []
    workspaceAnimation.stop()
    root.swapSourceHint = ""
    root.holdingHint = ""
    root.holdProgress = 0.0
    root.connectorVisualOpacity = root.connectorOpacity
    root.selectedHint = ""
    root.exitOpacity = 1.0
    root.otherHintOpacity = 1.0
  }

  function beginSelection(hint) {
    if (root.exiting) return
    if (!root.opened || !root.windowForHint(hint)) {
      root.close()
      return
    }
    root.settingsOpen = false
    root.swapSourceHint = ""
    badgeEntranceAnimation.stop()
    root.badgeEntrance = 1.0
    root.selectedHint = hint
    root.exitOpacity = 1.0
    root.otherHintOpacity = 1.0
    root.selectionPulse = 0.0
    selectionPulseAnimation.restart()
    otherHintsFade.restart()
    selectionFade.restart()
    selectionCloseTimer.restart()
  }

  function beginHold(hint) {
    if (!root.opened || !root.windowForHint(String(hint || ""))) return "unknown"
    root.holdingHint = String(hint)
    root.holdProgress = 0.0
    holdAnimation.restart()
    return "ok"
  }

  function cancelHold(hint) {
    if (hint && root.holdingHint !== String(hint)) return "ignored"
    holdAnimation.stop()
    root.holdingHint = ""
    root.holdProgress = 0.0
    return "ok"
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
      if (root.opened) badgeEntranceAnimation.restart()
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

  function windowForHint(hint) {
    for (var i = 0; i < root.windows.length; i++)
      if (root.windows[i].hint === hint) return root.windows[i]
    return null
  }

  function enterSwap(hint) {
    if (!root.windowForHint(String(hint || ""))) return "unknown"
    root.swapSourceHint = String(hint)
    root.holdingHint = ""
    root.holdProgress = 0.0
    root.connectorVisualOpacity = 1.0
    connectorFade.restart()
    return "ok"
  }

  function enterWorkspaces(hint) {
    var source = root.windowForHint(String(hint || ""))
    if (!root.opened || !source) return "unknown"
    root.cancelHold("")
    root.workspaceSourceHint = String(hint)
    var current = source.workspace || {}
    var targets = []
    for (var i = 1; i <= 10; i++) {
      if (current.id !== i) targets.push(i === 10 ? "0" : String(i))
    }
    if (current.name !== "special:scratchpad") targets.push("s")
    root.workspaceTargets = targets
    workspaceAnimation.restart()
    return "ok"
  }

  NumberAnimation {
    id: badgeEntranceAnimation
    target: root
    property: "badgeEntrance"
    from: 0.0
    to: 1.0
    duration: 300
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: workspaceAnimation
    target: root
    property: "workspaceSpread"
    from: 0
    to: 1
    duration: 220
    easing.type: Easing.OutCubic
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

  Process {
    id: settingsCancelProcess
    running: false
    command: [root.cancelPath]
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

  SequentialAnimation {
    id: holdAnimation

    PauseAnimation {
      duration: 100
    }

    NumberAnimation {
      target: root
      property: "holdProgress"
      from: 0.0
      to: 1.0
      duration: 250
      easing.type: Easing.Linear
    }
  }

  NumberAnimation {
    id: connectorFade
    target: root
    property: "connectorVisualOpacity"
    from: 1.0
    to: root.connectorOpacity
    duration: 260
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: selectionPulseAnimation
    target: root
    property: "selectionPulse"
    from: 0.0
    to: 1.0
    duration: 320
    easing.type: Easing.OutCubic
  }

  // Clear unrelated hints first, then let the selected badge/checkmark linger
  // briefly before fading. Avoid flashing a bright tint across the full window.
  NumberAnimation {
    id: otherHintsFade
    target: root
    property: "otherHintOpacity"
    from: 1.0
    to: 0.0
    duration: 180
    easing.type: Easing.OutCubic
  }

  SequentialAnimation {
    id: selectionFade
    PauseAnimation { duration: 100 }
    NumberAnimation {
      target: root
      property: "exitOpacity"
      from: 1.0
      to: 0.0
      duration: 320
      easing.type: Easing.OutCubic
    }
  }

  Timer {
    id: selectionCloseTimer
    interval: 440
    repeat: false
    onTriggered: root.close()
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

      readonly property var swapSource: root.windowForHint(root.swapSourceHint)
      readonly property var workspaceSource: root.windowForHint(root.workspaceSourceHint)

      Repeater {
        model: root.swapMode && overlay.swapSource
          ? root.windows.filter(function(window) { return window.hint !== root.swapSourceHint })
          : []

        delegate: Rectangle {
          required property var modelData
          readonly property real sourceX: overlay.swapSource.at[0] + overlay.swapSource.size[0] / 2 - overlay.monitor.x
          readonly property real sourceY: overlay.swapSource.at[1] + overlay.swapSource.size[1] / 2 - overlay.monitor.y
          readonly property real targetX: modelData.at[0] + modelData.size[0] / 2 - overlay.monitor.x
          readonly property real targetY: modelData.at[1] + modelData.size[1] / 2 - overlay.monitor.y
          readonly property real deltaX: targetX - sourceX
          readonly property real deltaY: targetY - sourceY
          readonly property real distance: Math.sqrt(deltaX * deltaX + deltaY * deltaY)
          readonly property real sourceRadius: root.hintBadgeSize(overlay.swapSource.size) / 2
            + Style.space(6) * root.hintScale
          readonly property real targetRadius: root.hintBadgeSize(modelData.size) / 2
            + Style.space(6) * root.hintScale
          readonly property real unitX: distance > 0 ? deltaX / distance : 0
          readonly property real unitY: distance > 0 ? deltaY / distance : 0
          readonly property real startX: sourceX + unitX * sourceRadius
          readonly property real startY: sourceY + unitY * sourceRadius
          readonly property real endX: targetX - unitX * targetRadius
          readonly property real endY: targetY - unitY * targetRadius

          x: (startX + endX) / 2 - width / 2
          y: (startY + endY) / 2 - height / 2
          width: Math.max(0, distance - sourceRadius - targetRadius)
          height: Math.max(2, Style.space(2))
          radius: height / 2
          rotation: Math.atan2(deltaY, deltaX) * 180 / Math.PI
          transformOrigin: Item.Center
          color: root.colorForHint(root.swapSourceHint)
          opacity: root.connectorVisualOpacity * root.exitOpacity
          antialiasing: true
          z: 1
        }
      }

      Repeater {
        model: root.windowsFor(overlay.modelData.name)

        delegate: Item {
          id: windowHint
          required property var modelData
          required property int index
          // Stagger only the badges; keep window outlines steady while hints arrive.
          readonly property real badgeProgress: Math.max(0, Math.min(1,
            (root.badgeEntrance - Math.min(index, 6) * 0.055) / (1 - Math.min(index, 6) * 0.055)))
          readonly property color accentColor: root.colorForHint(modelData.hint)
          readonly property real badgeSize: root.hintBadgeSize(modelData.size)

          x: modelData.at[0] - overlay.monitor.x
          y: modelData.at[1] - overlay.monitor.y
          width: modelData.size[0]
          height: modelData.size[1]
          z: 2
          visible: root.workspaceSourceHint === "" || root.workspaceSourceHint === modelData.hint
          opacity: root.exiting
            ? (modelData.hint === root.selectedHint ? root.exitOpacity : root.otherHintOpacity)
            : 1

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(windowHint.accentColor.r, windowHint.accentColor.g,
              windowHint.accentColor.b,
              windowHint.modelData.hint === root.swapSourceHint ? 0.50 : root.windowTintOpacity)
            radius: Style.cornerRadius
          }

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Math.max(2, Style.space(2))
            border.color: windowHint.accentColor
            radius: Style.cornerRadius
            opacity: root.exiting && windowHint.modelData.hint === root.selectedHint ? 0.55 : 1
          }

          Rectangle {
            anchors.centerIn: parent
            width: windowHint.badgeSize + Style.space(12) * root.hintScale
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(2, Style.space(2))
            border.color: root.colorForHint(root.swapSourceHint)
            opacity: root.holdingHint === windowHint.modelData.hint
              ? 0 : root.connectorVisualOpacity
            visible: root.swapMode
          }

          Shape {
            anchors.centerIn: parent
            width: windowHint.badgeSize + Style.space(12) * root.hintScale
            height: width
            visible: root.holdingHint === windowHint.modelData.hint
            opacity: root.connectorOpacity

            ShapePath {
              strokeWidth: Math.max(2, Style.space(2))
              strokeColor: root.swapMode
                ? root.colorForHint(root.swapSourceHint) : windowHint.accentColor
              fillColor: "transparent"
              capStyle: ShapePath.RoundCap
              startX: (windowHint.badgeSize + Style.space(12) * root.hintScale) / 2
              startY: 0
              PathAngleArc {
                centerX: (windowHint.badgeSize + Style.space(12) * root.hintScale) / 2
                centerY: centerX
                radiusX: centerX - Math.max(2, Style.space(2)) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * root.holdProgress
              }
            }
          }

          Rectangle {
            id: badge
            anchors.centerIn: parent
            width: windowHint.badgeSize
            height: windowHint.badgeSize
            radius: width / 2
            // Start as a visible dot, then expand into the translucent hint circle.
            scale: windowHint.modelData.hint === root.selectedHint
              ? 1 + 0.09 * Math.sin(Math.PI * root.selectionPulse)
              : 0.045 + 0.955 * windowHint.badgeProgress
            color: Qt.rgba(windowHint.accentColor.r, windowHint.accentColor.g,
              windowHint.accentColor.b,
              windowHint.modelData.hint === root.selectedHint ? 0.30
                : root.badgeTintOpacity + (0.85 - root.badgeTintOpacity)
                  * (1 - windowHint.badgeProgress))

            Text {
              anchors.centerIn: parent
              text: windowHint.modelData.hint === root.selectedHint
                ? "✓" : windowHint.modelData.hint.toUpperCase()
              color: windowHint.accentColor
              opacity: Math.max(0, Math.min(1, (windowHint.badgeProgress - 0.35) / 0.5))
              font.family: Style.font.menuFamily
              font.pixelSize: Math.round(badge.height * (text.length > 1 ? 0.46 : 0.62))
              font.bold: true
            }
          }
        }
      }

      Repeater {
        model: overlay.workspaceSource && overlay.monitor
          && overlay.workspaceSource.monitor === overlay.modelData.name
          ? root.workspaceTargets : []

        delegate: Rectangle {
          required property string modelData
          required property int index
          readonly property var source: root.windowForHint(root.workspaceSourceHint)
          readonly property color accent: root.colorForHint(root.workspaceSourceHint)
          readonly property real orbit: Style.space(126) * root.hintScale
          readonly property real angle: -Math.PI / 2 + index * 2 * Math.PI / root.workspaceTargets.length
          readonly property real centerX: source ? source.at[0] + source.size[0] / 2 - overlay.monitor.x : 0
          readonly property real centerY: source ? source.at[1] + source.size[1] / 2 - overlay.monitor.y : 0
          x: Math.max(4, Math.min(overlay.width - width - 4,
            centerX + Math.cos(angle) * orbit * root.workspaceSpread - width / 2))
          y: Math.max(4, Math.min(overlay.height - height - 4,
            centerY + Math.sin(angle) * orbit * root.workspaceSpread - height / 2))
          width: Style.space(48) * root.hintScale
          height: width
          radius: width / 2
          color: Qt.rgba(accent.r, accent.g, accent.b, root.badgeTintOpacity)
          border.width: Math.max(1, Style.space(2) * root.hintScale)
          border.color: accent
          opacity: root.workspaceSpread
          z: 3
          Text {
            anchors.centerIn: parent
            text: parent.modelData.toUpperCase()
            color: parent.accent
            font.family: Style.font.menuFamily
            font.pixelSize: Style.space(28) * root.hintScale
            font.bold: true
          }
        }
      }
    }
  }

  PanelWindow {
    id: settingsWindow
    visible: root.opened && root.settingsOpen
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
      height: settingsContent.implicitHeight + Style.space(36)
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: Color.menu.background
      border.width: Math.max(1, Style.space(1))
      border.color: Color.menu.border

      Column {
        id: settingsContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Style.space(24)
        anchors.leftMargin: Style.space(24)
        anchors.rightMargin: Style.space(24)
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
            Text { text: "Hint circle background"; color: Color.menu.text; font.family: Style.font.menuFamily; width: parent.width - 60 }
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
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!settingsCancelProcess.running) settingsCancelProcess.running = true
          }
        }
      }
    }
  }
}
