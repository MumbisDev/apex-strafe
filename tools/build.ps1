$ErrorActionPreference = "Stop"
$Godot = $env:GODOT
if (-not $Godot) {
  $Godot = "C:\Users\boutt\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
}
$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "build"
New-Item -ItemType Directory -Force -Path $Out | Out-Null

function Export-Preset([string]$preset, [string]$outFile) {
  Write-Host "Exporting $preset -> $outFile"
  & $Godot --headless --path $Root --export-release $preset $outFile
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Export failed for $preset (exit $LASTEXITCODE). Export templates may be missing — skipping without failing the run."
  }
}

Export-Preset "Windows Desktop" (Join-Path $Out "ApexStrafe.exe")
Export-Preset "Linux" (Join-Path $Out "ApexStrafe.x86_64")
Write-Host "Build script finished."
