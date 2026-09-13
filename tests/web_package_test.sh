#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GODOT=${GODOT_BIN:-godot}
ARCHIVE=${1:-"$ROOT_DIR/dist/@aviorstudio_gd-env.zip"}
OUTPUT=${WEB_EXPORT_DIR:-"$ROOT_DIR/dist/web"}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/project/addons/@aviorstudio_gd-env" "$OUTPUT"
unzip -q "$ARCHIVE" -d "$WORK/project/addons/@aviorstudio_gd-env"
cp "$ROOT_DIR/tests/web_fixture/project.godot" "$ROOT_DIR/tests/web_fixture/main.gd" \
    "$ROOT_DIR/tests/web_fixture/main.tscn" "$ROOT_DIR/tests/web_fixture/export_presets.cfg" "$WORK/project/"

log="$WORK/export.log"
set +e
timeout --signal=TERM --kill-after=5 120 "$GODOT" --headless --path "$WORK/project" \
    --export-release Web "$OUTPUT/index.html" >"$log" 2>&1
status=$?
set -e
while IFS= read -r line; do printf '%s\n' "$line"; done <"$log"
if [ "$status" -ne 0 ] || grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|FAIL:)' "$log"; then
    echo "FAIL: packaged web export failed with status $status" >&2
    exit 1
fi
test -s "$OUTPUT/index.html"
test -s "$OUTPUT/index.wasm"
echo "REACHED gd-env packaged_web_export assertions=2"
echo "PASS gd-env packaged_web_export"
