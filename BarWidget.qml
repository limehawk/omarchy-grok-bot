import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "limehawk.grok-bot"

  property string statusText: "Grok Bot: stopped"
  property bool running: false
  property bool hidden: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function toggle() {
    if (!toggleProc.running) toggleProc.running = true
  }

  Process {
    id: statusProc
    command: ["/home/limehawk/.config/omarchy/plugins/limehawk.grok-bot/keep.sh", "status"]
    stdout: StdioCollector {
      id: statusOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      try {
        var data = JSON.parse(String(statusOut.text || "").trim())
        root.statusText = data.tooltip || ""
        root.running = !!data.running
        root.hidden = !!data.hidden
      } catch (e) {}
    }
  }

  Process {
    id: toggleProc
    command: ["/home/limehawk/.config/omarchy/plugins/limehawk.grok-bot/keep.sh", "toggle"]
    stdout: StdioCollector {
      id: toggleOut
      waitForEnd: true
    }
    onExited: function() {
      try {
        var data = JSON.parse(String(toggleOut.text || "").trim())
        root.statusText = data.tooltip || root.statusText
        root.running = !!data.running
        root.hidden = !!data.hidden
      } catch (e) {
        root.refresh()
      }
    }
  }

  Timer {
    interval: 4000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component {
    id: blobIcon
    Item {
      // Match dropbox/tailscale: glyph-sized mark inside the 16px canvas,
      // not a full-bleed image. The pebble reads bigger than a stroke icon
      // at the same box, so keep it at iconFont (13) rather than the canvas.
      Image {
        id: blobSrc
        anchors.centerIn: parent
        width: Style.bar.iconFont
        height: Style.bar.iconFont
        source: Qt.resolvedUrl("assets/blob-symbolic.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
        layer.enabled: true
        sourceSize.width: width * 2
        sourceSize.height: height * 2
      }
      MultiEffect {
        anchors.centerIn: parent
        width: blobSrc.width
        height: blobSrc.height
        source: blobSrc
        colorization: 1.0
        colorizationColor: button.foreground
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: blobIcon
    tooltipText: root.statusText
    dimmed: !root.running
    onPressed: root.toggle()
  }
}
