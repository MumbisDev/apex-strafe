#!/usr/bin/env bash
# Runs the headless test suite. Exit code mirrors the runner (0 = all green, 1 = failures).
# Env: GODOT = path to the Godot executable, SKIP_IMPORT=1 skips the class-cache/import refresh.
set -uo pipefail

DEFAULT_GODOT='C:\Users\boutt\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
GODOT_BIN="${GODOT:-$DEFAULT_GODOT}"
if [[ ! -e "$GODOT_BIN" ]] && ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    echo "Godot not found at '$GODOT_BIN'. Set the GODOT environment variable." >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${SKIP_IMPORT:-0}" != "1" ]]; then
    # Refreshes the global class cache and imports new assets (GDD Appendix A, items 1 and 15).
    "$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
fi

"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_runner.gd
exit $?
