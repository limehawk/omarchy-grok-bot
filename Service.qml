import QtQuick
import Quickshell
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

  function ipcClass(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : ({})
    var klass = String(ipc["class"] || ipc.initialClass || "")
    if (klass !== "") return klass
    if (toplevel && toplevel.wayland && toplevel.wayland.appId)
      return String(toplevel.wayland.appId)
    return ""
  }

  function isGrok(toplevel) {
    if (root.ipcClass(toplevel) === root.appClass) return true
    return String(toplevel && toplevel.title || "") === "Grok Bot"
  }

  function collectToplevels() {
    var out = []
    var seen = ({})
    function add(t) {
      if (!t) return
      var addr = String(t.address || "")
      var key = addr || String(t.title || "")
      if (key && seen[key]) return
      if (key) seen[key] = true
      out.push(t)
    }
    var values = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < values.length; i++) add(values[i])
    var wss = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var w = 0; w < wss.length; w++) {
      var tops = wss[w].toplevels ? wss[w].toplevels.values : []
      for (var j = 0; j < tops.length; j++) add(tops[j])
    }
    return out
  }

  function grokWindows() {
    var values = root.collectToplevels()
    var out = []
    for (var i = 0; i < values.length; i++) {
      if (root.isGrok(values[i])) out.push(values[i])
    }
    return out
  }

  function waylandRunning() {
    try {
      var values = ToplevelManager.toplevels.values
      for (var i = 0; i < values.length; i++) {
        var t = values[i]
        if (!t) continue
        if (String(t.appId || "") === root.appClass) return true
        if (String(t.title || "") === "Grok Bot") return true
      }
    } catch (e) {}
    return false
  }

  function workspaceName(toplevel) {
    var ws = toplevel && toplevel.workspace ? toplevel.workspace : null
    return ws ? String(ws.name || "") : ""
  }

  function isSpecial(toplevel) {
    return root.workspaceName(toplevel) === root.specialWorkspace
  }

  function allSpecial(wins) {
    if (!wins || wins.length === 0) return false
    for (var i = 0; i < wins.length; i++) {
      if (!root.isSpecial(wins[i])) return false
    }
    return true
  }

  function addressOf(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : ({})
    var addr = String(ipc.address || (toplevel && toplevel.address) || "")
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
    var wins = root.windows.length ? root.windows : root.grokWindows()
    for (var i = 0; i < wins.length; i++)
      root.dispatchMove(root.addressOf(wins[i]), root.specialWorkspace)
  }

  function show() {
    var wins = root.windows.length ? root.windows : root.grokWindows()
    if (wins.length === 0) return
    root.dispatchMove(root.addressOf(wins[0]), root.currentWorkspace())
  }

  function start(reveal) {
    if (root.grokWindows().length > 0 || root.waylandRunning()) {
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

  function ensure() {
    if (root.grokWindows().length > 0 || root.waylandRunning() || root.launching) return
    root.start(false)
  }

  function toggle() {
    var wins = root.grokWindows()
    if (wins.length === 0) {
      root.start(true)
      return
    }
    root.windows = wins
    if (root.allSpecial(wins)) root.show()
    else root.hide()
  }

  function sync() {
    var wins = root.grokWindows()
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
    root.running = hasWin || root.launching || root.waylandRunning()
    root.hidden = hasWin && root.allSpecial(wins)
    root.statusText = !root.running
      ? "Grok Bot: stopped"
      : (root.hidden ? "Grok Bot: hidden" : "Grok Bot: visible")
    if (root.ready && !hasWin && !root.waylandRunning() && !root.launching && !restartTimer.running)
      restartTimer.restart()
  }

  Timer {
    id: restartTimer
    interval: 800
    repeat: false
    onTriggered: root.ensure()
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

  // Hyprland.toplevels is empty until IPC connects. Wait before treating
  // "no grok-bot window" as "not running" or we spawn a second instance.
  Timer {
    id: bootTimer
    interval: 750
    running: true
    repeat: false
    onTriggered: {
      root.ready = true
      root.sync()
      root.ensure()
    }
  }

  Connections {
    target: Hyprland.toplevels
    function onValuesChanged() { root.sync() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = String(event && event.name || "")
      if (n.indexOf("window") !== -1) root.sync()
    }
  }

  Component.onCompleted: root.sync()
}
