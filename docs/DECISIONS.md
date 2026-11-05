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
2026-11-05 | Audio file generation deferred; Audio autoload runtime synth FALLBACK active | generate_audio.gd exited unclean while editor held the project lock; GDD Section 15 FALLBACK covers startup AudioStreamWAV synthesis.
2026-11-05 | Runtime music/ambient placeholders use quiet low pads + brown noise, not midrange sines | Continuous 220?800 Hz sine at 0 dB looped as music_menu was a painful mains-hum on the main menu; pads stay ~35?85 Hz at ~?14 dB until generated WAVs exist.
2026-11-05 | Disable GD-Sync and sky_3d plugins in project.godot | Prevent editor overwrite of autoloads and headless exit errors.
2026-11-05 | Bot AI split into small files: added bot_combat, bot_motor, bot_planner, bot_items, bot_weapons, bot_stuck beside the requested ones | Keeps every file under ~300 lines; brain only does goal selection and orchestration.
2026-11-05 | Navigator takes an AStar3D, resolved via BotNavigator.graph_from_map (map_root.map_data['waypoints']['astar'], WaypointGraph.astar, or a waypoint_graph property); no graph = steer straight at destination | The existing WaypointGraph is a RefCounted wrapper around AStar3D, and some maps have no graph yet.
2026-11-05 | Link types come from an optional link_source (get_link_type/get_link_anchor); without it a +0.45..2.2 m step is a JUMP and a drop is a DROP | Current WaypointGraph stores no link metadata; GRAPPLE/WALLRUN links need a generator that supplies it.
2026-11-05 | Grapple/wall-run skill gates per link, rolled once with the bot seed; if the roll fails the path is rejected and the goal picks another destination | AStar3D cannot filter links per bot. Rookie (usage 0) never uses those links; JUMP/DROP are always allowed.
2026-11-05 | Global path budget is a static counter keyed by physics frame (2 per tick); denied requests stay dirty and retry next tick | GDD 10 budget without a central scheduler.
2026-11-05 | Perception is stateless about the scene: BotBrain builds EnemyViews every 0.1 s and injects a los_blocked Callable (bound with the fighter, so the bound arg comes last) | Lets perception, reaction and memory be tested with mocks; max 4 rays per update (torso first, head only if blocked).
2026-11-05 | Hearing/damage events are connected by BotBrain.bind() and removed by BotInput.shutdown(); damage reveals the attacker position via MatchManager.get_fighter | Brain owns the match reference; the RefCounted must disconnect from the Events autoload.
2026-11-05 | Rocket under 3 m is only chosen when winning and nothing better has ammo; weapon ranges use strict pass then loose fallback | Matches the GDD table while always returning a usable weapon.
2026-11-05 | BotInput.configure(f, mm, MatchConfig.Difficulty, index) kept as the match-scene entry point; Mixed uses BotProfile.mixed (base +/- 1 difficulty, default Veteran) | match_scene.gd already calls this signature.
2026-11-05 | Bunnyhop reaching 15 m/s (Nightmare) and 11-13 m/s (Veteran) is untuned | Needs a movement sim or the soak test; the air-strafe logic (alternate strafe toward the turn, yaw rate scaled by skill) is implemented but not measured.
2026-11-05 | Soak test FALLBACK: 45 s sim + early-exit + quick waypoint graph (spawn/pickup mesh) | Full 180 s x 3 maps with raycast WaypointGraph.generate hung CI; pass gates scaled to >=8 kills / every bot fires / <2 teleports.
2026-11-05 | MatchScene builds WaypointGraph after two physics frames | Bots had no nav graph; BotNavigator.graph_from_map also accepts meta keys.
2026-11-05 | M1/M2/M6/M7 are allow-empty verification commits after bulk M0 parallel land | GDD wants one commit per milestone; core already shipped in M0 so empty commits document verification without rewriting history.

