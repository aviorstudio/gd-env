#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "usage: $0 TEST_SCRIPT CASE_NAME TIMEOUT_SECONDS LOG_FILE" >&2
    exit 2
fi

test_script=$1
case_name=$2
timeout_seconds=$3
log_file=$4
godot=${GODOT_BIN:-godot}

if [ ! -f "$test_script" ]; then
    echo "FAIL: missing test script: $test_script" >&2
    exit 1
fi
if ! command -v "$godot" >/dev/null 2>&1 && [ ! -x "$godot" ]; then
    echo "FAIL: Godot binary is unavailable: $godot" >&2
    exit 1
fi

mkdir -p "$(dirname "$log_file")"
set +e
timeout --signal=TERM --kill-after=2 "$timeout_seconds" \
    "$godot" --headless --path "$(cd "$(dirname "$test_script")/.." && pwd)" \
    --script "$test_script" >"$log_file" 2>&1
status=$?
set -e

while IFS= read -r line; do printf '%s\n' "$line"; done <"$log_file"

if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
    echo "FAIL: $case_name timed out after ${timeout_seconds}s" >&2
    exit 1
fi
if [ "$status" -ne 0 ]; then
    echo "FAIL: $case_name exited with status $status" >&2
    exit 1
fi
if grep -Eq '^(ERROR:|SCRIPT ERROR:|FAIL:)' "$log_file"; then
    echo "FAIL: $case_name emitted an unexpected engine/test error" >&2
    exit 1
fi
if [ "$(grep -Ec "^REACHED gd-env ${case_name} assertions=[1-9][0-9]*$" "$log_file")" -ne 1 ]; then
    echo "FAIL: $case_name did not prove its assertions were reached exactly once" >&2
    exit 1
fi
if [ "$(grep -Ec "^PASS gd-env ${case_name}$" "$log_file")" -ne 1 ]; then
    echo "FAIL: $case_name did not emit exactly one PASS marker" >&2
    exit 1
fi
