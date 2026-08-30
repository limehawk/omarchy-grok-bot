#!/bin/bash
# Helper for the limehawk.grok-bot Omarchy plugin.
set -euo pipefail

CLASS=grok-bot
SPECIAL=special:grokbot
KEEP_BIN=/usr/bin/grok-bot

running() {
  pgrep -x grok-bot >/dev/null
}

windows_json() {
  hyprctl clients -j | jq -c --arg c "$CLASS" '[.[] | select(.class == $c)]'
}

is_hidden() {
  hyprctl clients -j | jq -e --arg c "$CLASS" '
    [.[] | select(.class == $c)] as $w
    | ($w | length) > 0
      and (all($w[]; (.workspace.name | tostring | startswith("special"))))
  ' >/dev/null
}

dispatch() {
  hyprctl dispatch "$1" >/dev/null
}

hide() {
  hyprctl clients -j | jq -r --arg c "$CLASS" '.[] | select(.class == $c) | .address' | while read -r addr; do
    [[ -n ${addr:-} ]] || continue
    dispatch "hl.dsp.window.move({ workspace = \"$SPECIAL\", window = \"address:$addr\", follow = false })"
  done
}

show() {
  local ws addr
  ws=$(hyprctl activeworkspace -j | jq -r '.id')
  addr=$(hyprctl clients -j | jq -r --arg c "$CLASS" '.[] | select(.class == $c) | .address' | head -n1)
  if [[ -z ${addr:-} ]]; then
    if ! running; then
      setsid uwsm-app -- "$KEEP_BIN" >/dev/null 2>&1 &
    fi
    return
  fi
  dispatch "hl.dsp.window.move({ workspace = \"$ws\", window = \"address:$addr\", follow = true })"
  dispatch "hl.dsp.focus({ window = \"address:$addr\" })"
}

status() {
  local state running_js hidden_js
  if running; then
    if is_hidden; then
      state=hidden
      hidden_js=true
    else
      state=visible
      hidden_js=false
    fi
    running_js=true
  else
    state=stopped
    running_js=false
    hidden_js=false
  fi
  printf '{"class":"%s","tooltip":"Grok Bot: %s","running":%s,"hidden":%s}\n' \
    "$state" "$state" "$running_js" "$hidden_js"
}

ensure() {
  if running; then
    return
  fi
  setsid uwsm-app -- "$KEEP_BIN" >/dev/null 2>&1 &
  local i
  for i in $(seq 1 20); do
    if hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class == $c)' >/dev/null; then
      hide
      return
    fi
    sleep 0.25
  done
}

toggle() {
  if ! running; then
    ensure
    sleep 0.2
    show
    status
    return
  fi
  if is_hidden; then
    show
  else
    hide
  fi
  status
}

case ${1:-status} in
  status) status ;;
  hide) hide; status ;;
  show) show; status ;;
  toggle) toggle ;;
  ensure) ensure; status ;;
  *) echo "usage: keep.sh status|hide|show|toggle|ensure" >&2; exit 2 ;;
esac
