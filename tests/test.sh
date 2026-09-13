#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
MANIFEST="$SCRIPT_DIR/suite_manifest.txt"
RUN_CASE="$SCRIPT_DIR/run_godot_case.sh"
FAILURES=0
LOG_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_DIR"' EXIT

export XDG_DATA_HOME="$LOG_DIR/data"
export XDG_CONFIG_HOME="$LOG_DIR/config"

if [ ! -s "$MANIFEST" ]; then
    echo "FAIL: missing or empty Godot suite manifest: $MANIFEST" >&2
    exit 1
fi

mapfile -t tests < <(grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST")
if [ "${#tests[@]}" -eq 0 ]; then
    echo "FAIL: Godot suite manifest has no reachable tests" >&2
    exit 1
fi

for relative_test in "${tests[@]}"; do
    test_path="$ROOT_DIR/$relative_test"
    case_name=$(basename "$relative_test" .gd)
    echo "Running $relative_test..."
    if ! "$RUN_CASE" "$test_path" "$case_name" 30 "$LOG_DIR/$case_name.log"; then
        FAILURES=$((FAILURES + 1))
    fi
done

if ! "$SCRIPT_DIR/gate/test_gate.sh" "$LOG_DIR/gate"; then
    FAILURES=$((FAILURES + 1))
fi

if [ "$FAILURES" -ne 0 ]; then
    echo "FAIL: $FAILURES gd-env suite group(s) failed" >&2
    exit 1
fi

echo "REACHED gd-env suite assertions=${#tests[@]}"
echo "PASS gd-env suite"
