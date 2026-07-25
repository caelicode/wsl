#!/usr/bin/env bash
# CaeliCode WSL — shared test helpers
# Sourced by every test-*.sh. Callers set: set -euo pipefail
#
# History note: the previous per-file check_version captured stderr and
# passed on ANY non-empty output, so "command not found" counted as a
# pass and CI could never fail on a missing tool. These helpers assert
# on exit status and binary presence instead.

PASS=0
FAIL=0

# check <name> <cmd> [args...] — passes only when the command exits 0.
check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ ${name}"; PASS=$((PASS + 1))
    else
        echo "  ✗ ${name}"; FAIL=$((FAIL + 1))
    fi
}

# check_version <name> <cmd string> — passes only when the binary exists
# AND the command exits 0.
# Output is captured whole, not piped through head: under pipefail,
# head exiting early SIGPIPEs tools with long version output (az, gcloud)
# and would turn healthy tools into failures.
check_version() {
    local name="$1" cmd="$2"
    local bin="${cmd%% *}"
    local out
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "  ✗ ${name}: ${bin} not found"; FAIL=$((FAIL + 1)); return 0
    fi
    # shellcheck disable=SC2086  # intentional word-splitting of the command string
    if out="$($cmd 2>&1)"; then
        echo "  ✓ ${name}: $(printf '%s\n' "$out" | head -1)"; PASS=$((PASS + 1))
    else
        echo "  ✗ ${name}: '${cmd}' exited non-zero: $(printf '%s\n' "$out" | head -1)"
        FAIL=$((FAIL + 1))
    fi
    return 0
}

# summarize <suite label> — print results; exit 1 if anything failed.
summarize() {
    echo ""
    echo "$1: ${PASS} passed, ${FAIL} failed"
    [ "$FAIL" -eq 0 ] || exit 1
}
