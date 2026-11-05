# Runs the headless test suite. Exit code mirrors the runner (0 = all green, 1 = failures).
# Env: GODOT = path to the Godot executable, SKIP_IMPORT=1 skips the class-cache/import refresh.

$DefaultGodot = "C:\Users\boutt\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
$Godot = if ($env:GODOT) { $env:GODOT } else { $DefaultGodot }
if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Error "Godot not found at '$Godot'. Set the GODOT environment variable."
    exit 2
}

$Root = Split-Path -Parent $PSScriptRoot

if ($env:SKIP_IMPORT -ne "1") {
    # Refreshes the global class cache and imports new assets (GDD Appendix A, items 1 and 15).
    & $Godot --headless --path $Root --import *> $null
}

& $Godot --headless --path $Root --script res://tests/test_runner.gd
exit $LASTEXITCODE
