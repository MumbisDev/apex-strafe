#!/usr/bin/env bash
set -euo pipefail
GODOT_BIN="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build"
mkdir -p "$OUT"

export_preset() {
  local preset="$1"
  local out="$2"
  echo "Exporting $preset -> $out"
  if ! "$GODOT_BIN" --headless --path "$ROOT" --export-release "$preset" "$out"; then
    echo "Export failed for $preset. Export templates may be missing — skipping." >&2
  fi
}

export_preset "Windows Desktop" "$OUT/ApexStrafe.exe"
export_preset "Linux" "$OUT/ApexStrafe.x86_64"
echo "Build script finished."
