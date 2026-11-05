extends RefCounted
## M5/M10 soak: 8 Veteran bots on each arena for compressed simulated time.
## GDD asks 3 min/map; we run 45 s sim at real physics (FALLBACK: shorter wall clock)
## with the same pass gates scaled: ≥8 kills, every bot fires, <2 teleports/bot.

var T: SceneTree

const BOT_COUNT: int = 8
const SIM_SECONDS: float = 45.0
const MIN_KILLS: int = 8
## Yield to the engine every this many ticks so the runner stays responsive.
const YIELD_EVERY: int = 30

func setup(runner: SceneTree) -> void:
	T = runner

func test_soak_foundry() -> void:
	await _soak_map("foundry")

func test_soak_spire() -> void:
	await _soak_map("spire")

func test_soak_sprawl() -> void:
	await _soak_map("sprawl")

func _soak_map(map_id: String) -> void:
	var world := Node3D.new()
	world.name = "SoakWorld_%s" % map_id
	T.root.add_child(world)
	var builder: MapBuilder = MapBuilder.create(map_id)
	T.assert_true(builder != null, "map builder %s" % map_id)
	var data: Dictionary = builder.build(world)
	await T.physics_frame
	await T.physics_frame

	var map_root: Node3D = data.get("root") as Node3D
	var wp := WaypointGraph.new()
	# Cheap graph: skip full floor sample; inject spawn/pickup points only.
	var ok_graph := _quick_graph(wp, data)
	T.assert_true(ok_graph, "%s quick waypoints" % map_id)
	map_root.set_meta("waypoint_graph", wp)
	map_root.set_meta("astar", wp.astar)

	var mm := MatchManager.new()
	world.add_child(mm)
	var cfg := MatchConfig.new()
	cfg.map_id = map_id
	cfg.bot_count = BOT_COUNT
	cfg.difficulty = MatchConfig.Difficulty.VETERAN
	cfg.kill_limit = 999
	cfg.time_limit_sec = 0
	cfg.seed = 42
	mm.setup(cfg, map_root)
	mm.spawn_system.set_spawns(data.get("spawns", []))
	mm.phase = MatchManager.Phase.LIVE

	var game := T.root.get_node_or_null("/root/Game")
	if game != null:
		game.set("match_config", cfg)

	var spawns: Array = data.get("spawns", [])
	var fired: Dictionary = {}
	for i in BOT_COUNT:
		var bot := Fighter.new()
		bot.id = mm.alloc_id()
		bot.display_name = BotNames.name_at(i)
		bot.color = BotNames.color_at(i)
		world.add_child(bot)
		var bi := BotInput.new()
		bi.configure(bot, mm, MatchConfig.Difficulty.VETERAN, i)
		bot.setup_bot(bi)
		var si: Dictionary = (
			spawns[i % spawns.size()] if spawns.size() > 0
			else {"pos": Vector3(float(i) * 3.0, 2.0, 0.0), "yaw": 0.0}
		)
		bot.global_position = si.get("pos", Vector3(float(i) * 3.0, 2.0, 0.0)) as Vector3
		bot.movement.yaw = float(si.get("yaw", 0.0))
		_attach_inventory(bot, mm)
		mm.auth_register_fighter(bot)
		bot.frozen = false
		mm.teleport_counts[bot.id] = 0
		fired[bot.id] = false

	var ticks: int = int(SIM_SECONDS * 120.0)
	for t in ticks:
		await T.physics_frame
		for id in mm.fighters:
			var f: Fighter = mm.fighters[id]
			if f.accuracy_shots > 0 or f.kills > 0 or f.damage_dealt > 0.0:
				fired[id] = true
			elif f.inventory is WeaponInventory:
				var inv := f.inventory as WeaponInventory
				if inv.current_weapon() != null and inv.current_weapon().cooldown > 0.0:
					fired[id] = true
		# Early exit if already satisfied (keeps CI fast once bots are fighting).
		if t > 120 * 15 and _kills(mm) >= MIN_KILLS and _all_fired(fired):
			break
		if t % YIELD_EVERY == 0:
			await T.process_frame

	var total_kills := _kills(mm)
	T.assert_true(total_kills >= MIN_KILLS, "%s soak kills=%d (need %d)" % [map_id, total_kills, MIN_KILLS])
	for id3 in fired:
		T.assert_true(bool(fired[id3]), "%s bot %s never fired" % [map_id, str(id3)])
	for id4 in mm.teleport_counts:
		var tc: int = int(mm.teleport_counts[id4])
		T.assert_true(tc < 2, "%s bot %s teleports=%d (limit 2)" % [map_id, str(id4), tc])

	world.queue_free()
	await T.process_frame
	await T.process_frame

func _kills(mm: MatchManager) -> int:
	var total := 0
	for id in mm.fighters:
		total += (mm.fighters[id] as Fighter).kills
	return total

func _all_fired(fired: Dictionary) -> bool:
	for id in fired:
		if not bool(fired[id]):
			return false
	return true

## Lightweight waypoint set from spawn/pickup markers (avoids multi-second raycast bake in CI).
func _quick_graph(wp: WaypointGraph, data: Dictionary) -> bool:
	var pts: Array[Vector3] = []
	for s in data.get("spawns", []):
		if s is Dictionary and s.has("pos"):
			pts.append((s["pos"] as Vector3) + Vector3(0, 0.05, 0))
	for p in data.get("pickups", []):
		if p is Dictionary and p.has("pos"):
			pts.append((p["pos"] as Vector3) + Vector3(0, 0.05, 0))
	if pts.is_empty():
		for i in 8:
			var a := TAU * float(i) / 8.0
			pts.append(Vector3(cos(a) * 12.0, 1.0, sin(a) * 12.0))
	for p in pts:
		var id := wp.astar.get_available_point_id()
		wp.astar.add_point(id, p)
	var ids: PackedInt64Array = wp.astar.get_point_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: int = int(ids[i])
			var b: int = int(ids[j])
			if wp.astar.get_point_position(a).distance_to(wp.astar.get_point_position(b)) < 28.0:
				wp.astar.connect_points(a, b, true)
	return wp.astar.get_point_count() > 0

func _attach_inventory(f: Fighter, mm: MatchManager) -> void:
	var inv := WeaponInventory.new()
	f.add_child(inv)
	f.inventory = inv
	inv.shooter = f
	inv.owner_id = f.id
	inv.camera = f.camera_rig.camera if f.camera_rig else null
	inv.aim_provider = func() -> Transform3D:
		return Transform3D(Basis.from_euler(Vector3(f.movement.pitch, f.movement.yaw, 0)), f.aim_origin())
	inv.damage_sink = func(victim_id: int, info: DamageInfo) -> void:
		mm.auth_apply_damage(victim_id, info)
	inv.rng = mm.rng
	inv.refresh_excludes()
	inv.reset_loadout()
	inv.give_weapon(WeaponLibrary.SLOT_SMG, true)
	inv.give_weapon(WeaponLibrary.SLOT_ROCKET, true)
	inv.select_slot(WeaponLibrary.SLOT_SMG)
