# Decisions Log

Format: `YYYY-MM-DD | decision | reason`

2026-11-05 | Keep `godot_ai` editor plugin and `_mcp_game_helper` autoload | Required for agent MCP verification; not shipped as game content.
2026-11-05 | Disable/remove GD-Sync and sky_3d from game runtime | GDD forbids game addons; unused for single-player concept.
2026-11-05 | Copy source prompt to `docs/GDD.md` | Human instructions require that path; original long filename retained as alias.
2026-11-05 | Godot path recorded as Downloads installer binary | Not on PATH; CLI wrappers use absolute path env `GODOT`.
2026-11-05 | Physics engine remains Jolt (project default) | Compatible with CharacterBody3D APIs used by GDD; no reason to switch.
2026-11-05 | Weapon ids are slot numbers 1-7 (WeaponDef.id) and used as weapon_id in DamageInfo/Events | One stable key across HUD, kill feed, pickups and tests.
2026-11-05 | Added scripts/weapons/weapon_utils.gd (static helpers: layer masks, hitbox lookup, spread, damage routing) | Keeps weapon_base.gd and projectile_rocket.gd small and avoids duplicated routing code.
2026-11-05 | Damage routing order: inventory.damage_sink Callable(victim_id, DamageInfo) -> node in group "match_manager" with auth_apply_damage -> victim.take_damage(info) | Matches the later MatchManager.auth_apply_damage signature; TargetDummy (group "target_dummy") is always damaged directly because it is not a registered fighter.
2026-11-05 | Hitbox Area3D contract: meta "fighter" (owner node, falls back to parent) and meta "part" ("head"/"body"); owners expose id, optional get_center_position() | Lets weapons resolve owner/head without depending on the Fighter class.
2026-11-05 | Headshots resolved with a second ray that excludes the body Area3D; if the same owner's head is next it is a headshot | Head sphere sits inside the body capsule, so the first ray normally reports the body.
2026-11-05 | Rocket direct hit deals 85 to the victim (no extra splash entry, still gets splash knockback); other fighters in 4.5 m take 80 splash with linear falloff to 15 percent and LOS check | One DamageInfo per victim per explosion; direct victim needs no LOS.
2026-11-05 | Self damage = splash x 0.35 flagged is_self; DamageInfo.NO_ID (-1) means no attacker | Dummy ids are negative (<= -1000) so is_self compares ids, not sign.
2026-11-05 | Semi-auto weapons repeat while fire is held at the fire interval and buffer one press for 0.12 s; SMG and Plasma are full-auto with no buffer | GDD says held fire repeats for semi-auto weapons; buffering keeps clicking responsive.
2026-11-05 | Fire cooldown carries sub-tick remainder (cooldown += interval, floor at -dt) | Average fire rate matches spec exactly at 120 Hz; each gap is within one tick.
2026-11-05 | Weapon switch sets the new slot immediately and blocks firing for switch_time (0.25 s); direct selection and wheel only pick owned weapons with ammo | Matches GDD handling rules; best-weapon fallback prefers highest slot, Blade last.
2026-11-05 | Viewmodel uses the FALLBACK renderer (no_depth_test materials, ascending render_priority) instead of a SubViewport | GDD-sanctioned simpler option; no extra viewport, lighting stays consistent.
2026-11-05 | Weapons never read autoload identifiers directly (WeaponUtils.get_autoload / emit_event by node path) | Weapon scripts and tests compile and run even when Events/Settings are not registered (headless tests, MCP tooling).
2026-11-05 | Added tests/weapon_test_world.gd fixture (no test_ prefix so the runner skips it) shared by test_weapons.gd and test_damage.gd | Avoids duplicating world/shooter/dummy setup across test files.
2026-11-05 | TargetDummy supports STATIC/MOVING/STRAFING/POPUP modes with a physics-clock driven lane, 4 pooled floating damage labels, id < 0 | Covers GDD 11.4 practice gallery; deterministic motion for tests.

2026-11-05 | Exclude addons/ from git (godot_ai kept locally for MCP) | GDD forbids shipping addons; editor MCP tooling stays local-only.
2026-11-05 | Access Settings/Audio via get_node when registering autoloads | Bare autoload identifiers fail parse until registered; deferred lookup unblocks bootstrap.
2026-11-05 | Skip surf ramps on Sprawl | Section 6 FALLBACK — defer until core systems pass.
2026-11-05 | Main menu attract uses parallax grid FALLBACK | Full bot attract mode deferred until match systems stable.
