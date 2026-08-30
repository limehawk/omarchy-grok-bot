import QtQuick
import Quickshell.Io

Item {
  id: root
  property var shell: null

  Process {
    id: ensureProc
    command: ["/home/limehawk/.config/omarchy/plugins/limehawk.grok-bot/keep.sh", "ensure"]
  }

  Timer {
    interval: 4000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!ensureProc.running) ensureProc.running = true
    }
  }
}
