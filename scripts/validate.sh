#!/bin/bash
# Same checks as `omarchy plugin validate`. Kept in-repo so CI does not need Omarchy.
set -euo pipefail

fail() { echo "validate: $*" >&2; exit 1; }

PLUGIN_DIR="${1:-.}"
[[ -d $PLUGIN_DIR ]] || fail "plugin folder not found: $PLUGIN_DIR"

MANIFEST="$PLUGIN_DIR/manifest.json"
[[ -f $MANIFEST ]] || fail "missing manifest.json"
jq -e . "$MANIFEST" >/dev/null || fail "manifest.json is not valid JSON"
jq -e '.schemaVersion == 1' "$MANIFEST" >/dev/null || fail "schemaVersion must be 1"

for field in id name version kinds entryPoints; do
  jq -e --arg f "$field" 'has($f)' "$MANIFEST" >/dev/null || fail "missing field '$field'"
done

ID=$(jq -r '.id // ""' "$MANIFEST")
[[ -n $ID ]] || fail "id is empty"
[[ $ID =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "invalid id '$ID'"
[[ $ID != *".."* ]] || fail "invalid id '$ID'"
[[ $ID != omarchy.* ]] || fail "id '$ID' uses reserved omarchy.*"

jq -e '(.kinds | type) == "array" and (.kinds | length) > 0' "$MANIFEST" >/dev/null \
  || fail "kinds must be a non-empty array"
jq -e '(.entryPoints | type) == "object"' "$MANIFEST" >/dev/null \
  || fail "entryPoints must be an object"
jq -e '
  if ((.barWidget? | type) == "object" and (.barWidget | has("defaultSection"))) then
    .barWidget.defaultSection as $section
    | ($section | type) == "string"
      and (["left", "center", "right"] | index($section)) != null
  else true end
' "$MANIFEST" >/dev/null || fail "barWidget.defaultSection must be left, center, or right"

while IFS= read -r ep_json; do
  [[ -n $ep_json ]] || continue
  ep=$(jq -r '.' <<<"$ep_json")
  [[ -n $ep ]] || fail "empty entry point"
  [[ $ep != /* ]] || fail "entry point must be relative: '$ep'"
  [[ $ep != *".."* ]] || fail "entry point may not contain '..': '$ep'"
  [[ -f "$PLUGIN_DIR/$ep" ]] || fail "entry point not found: '$ep'"
done < <(jq -c '.entryPoints | to_entries[] | .value' "$MANIFEST")

for kind_entry_point in bar:bar bar-widget:barWidget menu:menu overlay:overlay panel:panel service:service; do
  kind="${kind_entry_point%%:*}"
  entry_point="${kind_entry_point##*:}"
  jq -e --arg kind "$kind" '(.kinds | index($kind)) != null' "$MANIFEST" >/dev/null || continue
  jq -e --arg ep "$entry_point" '.entryPoints | has($ep)' "$MANIFEST" >/dev/null \
    || fail "kind '$kind' needs entryPoints.$entry_point"
done

[[ -f $PLUGIN_DIR/LICENSE ]] || fail "missing LICENSE"
[[ -f $PLUGIN_DIR/README.md ]] || fail "missing README.md"

link=$(find "$PLUGIN_DIR" -name .git -prune -o -type l -print -quit)
[[ -z $link ]] || fail "symlinks are not allowed: $link"

echo "ok $ID $(jq -r .version "$MANIFEST")"
