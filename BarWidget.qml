import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "limehawk.grok-bot"

  readonly property var service: bar && bar.shell && bar.shell.serviceFor
    ? bar.shell.serviceFor("limehawk.grok-bot") : null
  readonly property bool running: service ? service.running : false
  readonly property bool hidden: service ? service.hidden : false
  readonly property string statusText: service ? service.statusText : "Grok Bot: stopped"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function toggle() {
    if (root.service && typeof root.service.toggle === "function")
      root.service.toggle()
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
