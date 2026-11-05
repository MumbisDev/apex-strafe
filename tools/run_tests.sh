#!/usr/bin/env bash
set -euo pipefail
GODOT_BIN="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_runner.gd
