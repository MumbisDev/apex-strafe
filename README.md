# APEX STRAFE

Fast, movement-driven free-for-all arena shooter (Quake / UT / Titanfall lineage). Built entirely in Godot with code-generated content — no imported asset packs.

**Engine:** Godot **4.7.2.stable.official** (Forward+)

## Run

1. Open this folder in Godot 4.7.2.
2. Press Play (main scene: `scenes/boot.tscn`).

CLI:

```powershell
$env:GODOT = "C:\Users\boutt\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
& $env:GODOT --path .
```

## Controls

| Action | Default |
| --- | --- |
| Move | WASD |
| Jump / bhop | Space (hold for auto-bhop) |
| Crouch / slide | Ctrl or C |
| Fire / Alt | Mouse1 / Mouse2 |
| Grapple | E |
| Weapons | 1–7, wheel, Q last |
| Scoreboard | Tab |
| Pause | Esc |
| Debug overlay | F3 |

## Modes

- **Deathmatch** vs 1–11 bots (maps: Foundry, Spire, Sprawl)
- **Practice Range** — movement course + shooting gallery

## Tests

```powershell
./tools/run_tests.ps1
```

```bash
./tools/run_tests.sh
```

## Audio generation

```powershell
& $env:GODOT --headless --path . --script res://tools/generate_audio.gd
& $env:GODOT --headless --path . --import
```

## Export

```powershell
./tools/build.ps1
```

Templates missing → scripts log and skip without failing.

## Docs

- `docs/GDD.md` — full design
- `docs/DECISIONS.md` — agent decisions
- `docs/TUNING.md` — balance numbers
- `PROGRESS.md` — milestone / DoD checklist
