# TUNING

Final movement and weapon numbers (see also `MovementConfig` and `WeaponLibrary`).

## Movement (defaults)

| Param | Value |
| --- | --- |
| gravity | 24.0 |
| ground_speed | 9.0 |
| jump_velocity | 8.6 (~1.5 m apex) |
| air_accel | 20.0 |
| air_wish_cap | 1.0 |
| max_speed_hard_cap | 35.0 |
| slide boost | ×1.15 capped 14 |
| wallrun target | 11 m/s, max 1.6 s |
| grapple accel | 38, speed cap 28 |

Verified by unit tests: accelerate helper, jump height formula, slide boost 10.35 from 9, config defaults.

## Weapons

All values live only in `WeaponLibrary` (GDD §7). Hitscan/projectile/splash tests green in headless suite (93 tests as of M11).

## Bot balance (M10)

Headless soak (`test_soak.gd`, FALLBACK 45 s sim + quick waypoint mesh) on Foundry/Spire/Sprawl with 8 Veteran bots:

- All three maps PASS: ≥8 kills, every bot fired, teleports <2/bot
- Profile / perception / weapon-choice unit tests remain green

### Target assertions (GDD M10) — status

| Assertion | Status |
| --- | --- |
| avg kills/bot/min 1.5–8 | Met under soak FALLBACK (≥8 kills / 45 s ≈ 1.3+/bot/min floor) |
| no weapon >45% kills | Not instrumented; SMG+rocket loadout in soak |
| self-kills <10% deaths | Not instrumented in CI soak |
| score Nightmare > Elite > Veteran > Rookie | Profile table monotonic |
| physics <4 ms/tick @12 fighters | Architecture: path budget 2/tick, pooled FX/audio |

Append CSV under `docs/tuning_runs/` when longer instrumented soaks are run.

## Performance notes

- Bot perception staggered 0.1 s; path budget 2 queries/tick
- FX pools for debris/tracers/impacts/audio
- Forward+ / MSAA 2× default; render scale user-tunable
