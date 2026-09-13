#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 LOG_DIR" >&2
    exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUN_CASE="$SCRIPT_DIR/../run_godot_case.sh"
LOG_DIR=$1
mkdir -p "$LOG_DIR"

expect_rejected() {
    local fixture=$1
    local case_name=$2
    local timeout_seconds=${3:-5}
    if "$RUN_CASE" "$SCRIPT_DIR/fixtures/$fixture" "$case_name" "$timeout_seconds" "$LOG_DIR/$case_name.log"; then
        echo "FAIL: gate accepted negative control $case_name" >&2
        return 1
    fi
    echo "CONTROL_REJECTED gd-env $case_name"
}

# A known-good control establishes that the gate itself can pass.
"$RUN_CASE" "$SCRIPT_DIR/fixtures/valid.gd" valid 5 "$LOG_DIR/valid-before.log"

expect_rejected push_error_zero.gd push_error_zero
expect_rejected overwritten_exit.gd overwritten_exit
expect_rejected parse_failure.gd parse_failure
expect_rejected hang.gd hang 1
expect_rejected unexpected_error.gd unexpected_error
expect_rejected unreachable.gd unreachable

if "$RUN_CASE" "$SCRIPT_DIR/fixtures/does_not_exist.gd" missing_script 5 "$LOG_DIR/missing_script.log"; then
    echo "FAIL: gate accepted missing test script" >&2
    exit 1
fi
echo "CONTROL_REJECTED gd-env missing_script"

# Restore the valid fixture after every negative control and prove reachability.
"$RUN_CASE" "$SCRIPT_DIR/fixtures/valid.gd" valid 5 "$LOG_DIR/valid-restored.log"
echo "REACHED gd-env gate_controls assertions=9"
echo "PASS gd-env gate_controls"
