$ErrorActionPreference = "Stop"
$Godot = $env:GODOT
if (-not $Godot) {
  $Godot = "C:\Users\boutt\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
}
if (-not (Test-Path $Godot)) {
  Write-Error "Godot not found. Set GODOT env var."
  exit 1
}
$Root = Split-Path -Parent $PSScriptRoot
& $Godot --headless --path $Root --script res://tests/test_runner.gd
exit $LASTEXITCODE
