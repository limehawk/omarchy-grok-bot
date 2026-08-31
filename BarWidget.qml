import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "limehawk.grok-bot"

  property bool menuOpen: false

  readonly property var service: bar && bar.shell && bar.shell.serviceFor
    ? bar.shell.serviceFor("limehawk.grok-bot") : null
  readonly property bool running: service ? service.running : false
  readonly property bool hidden: service ? service.hidden : false
  readonly property string statusText: service ? service.statusText : "Grok Bot: stopped"
  readonly property bool keepAlive: service ? service.keepAlive : true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function close() { root.menuOpen = false }

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
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        root.menuOpen = !root.menuOpen
        return
      }
      root.menuOpen = false
      root.toggle()
    }
  }

  PopupCard {
    id: menu
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.menuOpen
    contentWidth: menu.fittedContentWidth(Style.space(280))
    contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      width: parent.width
      spacing: Style.space(8)

      Toggle {
        width: parent.width
        label: "Keep alive"
        description: "Restart Grok Bot if the window closes."
        checked: root.keepAlive
        foreground: root.bar ? root.bar.barForeground : Color.foreground
        accent: Color.accent
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        onClicked: {
          if (!root.service) return
          root.service.keepAlive = !root.service.keepAlive
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Button {
          width: (parent.width - parent.spacing) / 2
          text: "Relaunch"
          bordered: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          accent: Color.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: {
            if (root.service && typeof root.service.relaunch === "function")
              root.service.relaunch()
            root.close()
          }
        }

        Button {
          width: (parent.width - parent.spacing) / 2
          text: "Quit"
          bordered: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          accent: Color.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: {
            if (root.service && typeof root.service.quit === "function")
              root.service.quit()
            root.close()
          }
        }
      }
    }
  }
}
