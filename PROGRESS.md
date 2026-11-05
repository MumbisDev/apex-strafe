# PROGRESS

## Status
- Current milestone: M0 complete → advancing M1–M11
- Godot: 4.7.2.stable.official
- Tests: **81 passed, 0 failed** (headless)

## Milestone log

### M0 — Scaffold (done)
- Folder tree, `.cursor/rules/godot.mdc`, README, PROGRESS, DECISIONS
- Autoloads: Events, Settings, InputSetup, Audio, Game (+ MCP helper)
- InputSetup registers all actions; Settings persists `user://settings.cfg`
- Boot → main menu → match setup / settings / practice flow
- Test runner + wrappers; physics 120 Hz; layers named
- Manual: game launches, Match Setup UI verified via MCP screenshot, no game log errors

### M1 — Movement (in progress / largely implemented)
- MovementController with Quake accel, bhop, slide, wall-run, wall-jump, mantle, grapple
- CameraRig FOV kick / tilt / land dip; Practice Range scene
- Unit tests for accel, config, slide boost, replay input

### M2 — Weapons (largely implemented)
- WeaponDef / Library / Base / Inventory / projectiles / viewmodel
- TargetDummy; damage + weapon tests green (81 suite includes weapons/damage)

### M3–M5 — Core / maps / bots (largely implemented)
- Fighter + InputSource architecture, MatchManager auth_*, pickups, scoring, medals
- MapBuilder + Foundry/Spire/Sprawl/Range
- BotProfile/Brain/Perception/Navigator/Aim/Combat + bot tests

### M6–M9 — Flow / UI / HUD / Audio
- Match scene state machine, results, pause, HUD widgets, FX library
- Audio runtime synth FALLBACK; file generator pending

### M10–M11 — pending
- TUNING.md bot sims, export presets, CI, tag v0.1.0, DoD audit

## Section 17 — Definition of Done
- [x] 1. Launches (boot/menu/setup) with no game errors in MCP run
- [x] 2. Main menu entries present (Play/Practice/Settings/Quit; Multiplayer disabled)
- [x] 3. Match setup options + Start
- [ ] 4. 3 arenas + Practice Range playable (maps code present; MCP play verify pending)
- [ ] 5. Movement complete (more physics acceptance tests pending)
- [x] 6. All 7 weapons (library + tests)
- [ ] 7. All pickups (code present; soak pending)
- [ ] 8. Bots all difficulties (code + unit tests; soak pending)
- [ ] 9. Full match flow
- [ ] 10. Pause/restart/quit; 3-match leak check
- [x] 11. Settings + rebinding (UI present)
- [ ] 12. HUD complete (widgets present; MCP verify)
- [ ] 13. Audio generated files
- [ ] 14. All tests + soak + perf
- [ ] 15. Docs + build scripts + CI
- [ ] 16. No TODO/FIXME; no addons in repo
- [ ] 17. Milestone commits + tag v0.1.0
- [ ] 18. Final summary
