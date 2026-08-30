import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
  id: root
  property var shell: null

  readonly property string appClass: "grok-bot"
  readonly property string specialWorkspace: "special:grokbot"
  readonly property string keepBin: "/usr/bin/grok-bot"

  property var windows: []
  property bool running: false
  property bool hidden: false
  property string statusText: "Grok Bot: stopped"
  property bool launching: false
  property bool revealOnMap: false
  property bool ready: false
  property int startAttempts: 0
  property alias keepAlive: persisted.keepAlive

  PersistentProperties {
    id: persisted
    reloadableId: "limehawk.grok-bot"
    property bool keepAlive: true
  }

  onKeepAliveChanged: {
    if (!root.keepAlive) restartTimer.stop()
    else if (root.ready) root.ensure(false)
  }

  function grokClients(list) {
    var out = []
    if (!Array.isArray(list)) return out
    for (var i = 0; i < list.length; i++) {
      var c = list[i]
      if (c && String(c["class"] || "") === root.appClass) out.push(c)
    }
    return out
  }

  function workspaceName(client) {
    var ws = client && client.workspace ? client.workspace : null
    return ws ? String(ws.name || "") : ""
  }

  function isParked(client) {
    return root.workspaceName(client) === root.specialWorkspace
  }

  function allParked(wins) {
    if (!wins || wins.length === 0) return false
    for (var i = 0; i < wins.length; i++) {
      if (!root.isParked(wins[i])) return false
    }
    return true
  }

  function addressOf(client) {
    var addr = client ? String(client.address || "") : ""
    if (!addr) return ""
    if (addr.indexOf("0x") !== 0 && addr.indexOf("0X") !== 0)
      addr = "0x" + addr
    return addr
  }

  function currentWorkspace() {
    var ws = Hyprland.focusedWorkspace
    if (!ws) return "1"
    var name = String(ws.name || "")
    if (name.indexOf("special") === 0) return "previous"
    if (ws.id > 0) return String(ws.id)
    return "1"
  }

  function dispatchMove(addr, workspace) {
    if (!addr) return
    Hyprland.dispatch(
      "hl.dsp.window.move({ workspace = \"" + workspace
        + "\", window = \"address:" + addr
        + "\", follow = false })"
    )
  }

  function hide() {
    var wins = root.windows
    for (var i = 0; i < wins.length; i++)
      root.dispatchMove(root.addressOf(wins[i]), root.specialWorkspace)
  }

  function show() {
    var wins = root.windows
    if (wins.length === 0) return
    root.dispatchMove(root.addressOf(wins[0]), root.currentWorkspace())
  }

  function start(reveal) {
    if (root.windows.length > 0) {
      if (reveal) root.show()
      return
    }
    if (root.launching) {
      if (reveal) root.revealOnMap = true
      return
    }
    if (root.startAttempts > 8) return
    root.startAttempts += 1
    root.launching = true
    root.revealOnMap = !!reveal
    Quickshell.execDetached(["uwsm-app", "--", root.keepBin])
    launchWatchdog.restart()
    root.sync()
  }

  function ensure(reveal) {
    if (!root.keepAlive) return
    if (root.windows.length > 0 || root.launching) return
    root.start(reveal === true)
  }

  function quit() {
    root.keepAlive = false
    restartTimer.stop()
    root.launching = false
    var wins = root.windows
    if (wins.length === 0) {
      Quickshell.execDetached(["pkill", "-x", "grok-bot"])
      root.sync()
      return
    }
    for (var i = 0; i < wins.length; i++) {
      var addr = root.addressOf(wins[i])
      if (addr)
        Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + addr + "\" })")
    }
  }

  function toggle() {
    if (root.windows.length === 0) {
      root.start(true)
      return
    }
    if (root.allParked(root.windows)) root.show()
    else root.hide()
  }

  function applyClients(raw) {
    var list = []
    try { list = JSON.parse(String(raw || "")) } catch (e) { list = [] }
    var wins = root.grokClients(list)
    root.windows = wins
    var hasWin = wins.length > 0
    if (hasWin) {
      root.startAttempts = 0
      root.launching = false
      launchWatchdog.stop()
      if (root.revealOnMap) {
        root.revealOnMap = false
        root.show()
      }
    }
    root.running = hasWin || root.launching
    root.hidden = hasWin && root.allParked(wins)
    root.statusText = !root.running
      ? "Grok Bot: stopped"
      : (root.hidden ? "Grok Bot: hidden" : "Grok Bot: visible")
    if (root.ready && root.keepAlive && !hasWin && !root.launching && !restartTimer.running)
      restartTimer.restart()
  }

  function sync() {
    if (!clientsProc.running) clientsProc.running = true
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      id: clientsOut
      waitForEnd: true
    }
    onExited: root.applyClients(clientsOut.text)
  }

  Timer {
    id: restartTimer
    interval: 400
    repeat: false
    onTriggered: root.ensure(true)
  }

  Timer {
    id: launchWatchdog
    interval: 10000
    repeat: false
    onTriggered: {
      root.launching = false
      root.sync()
    }
  }

  Timer {
    id: bootTimer
    interval: 750
    running: true
    repeat: false
    onTriggered: {
      root.ready = true
      root.sync()
      if (root.keepAlive) root.ensure(false)
    }
  }

  Connections {
    target: Hyprland.toplevels
    function onValuesChanged() { root.sync() }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.sync() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = String(event && event.name || "")
      if (n.indexOf("window") !== -1 || n.indexOf("close") !== -1 || n.indexOf("destroy") !== -1)
        root.sync()
    }
  }

  Component.onCompleted: root.sync()
}
