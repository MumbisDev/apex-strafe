extends Node3D
## Full match scene: builds map, spawns fighters, runs MatchManager.

var mm: MatchManager
var map_data: Dictionary = {}
var waypoint_graph: WaypointGraph
var pickup_spawner: PickupSpawner
var net_bridge: Node = null
var hud: CanvasLayer
var pause_ui: Control
var debug_on: bool = false
var _debug_label: Label
var world_env: WorldEnvironment

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pickup_spawner = PickupSpawner.new()
	add_child(pickup_spawner)
	mm = MatchManager.new()
	add_child(mm)
	_build_map()
	mm.setup(Game.match_config, self)
	mm.spawn_system.set_spawns(map_data.get("spawns", []))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build_waypoints()
	if not Game.match_config.has_mutator(MatchConfig.Mutator.INSTAGIB):
		pickup_spawner.spawn_from_markers(self, map_data.get("pickups", []))
	if Game.match_config.online:
		var bridge_script: GDScript = load("res://scripts/match/net_bridge.gd") as GDScript
		net_bridge = bridge_script.new()
		add_child(net_bridge)
		net_bridge.call("setup", mm)
	_spawn_fighters()
	mm.freeze_all()
	_build_hud()
	_build_pause()

func _build_waypoints() -> void:
	waypoint_graph = WaypointGraph.new()
	if map_data.is_empty():
		return
	if not waypoint_graph.generate(get_world_3d(), map_data):
		push_warning("WaypointGraph generate failed for %s" % Game.match_config.map_id)

func _build_map() -> void:
	var map_id := Game.match_config.map_id
	var builder_script: Script = null
	match map_id:
		"spire":
			builder_script = load("res://scripts/maps/map_spire.gd")
		"sprawl":
			builder_script = load("res://scripts/maps/map_sprawl.gd")
		"range":
			builder_script = load("res://scripts/maps/map_range.gd")
		_:
			builder_script = load("res://scripts/maps/map_foundry.gd")
	if builder_script:
		var b = builder_script.new()
		if b.has_method("build"):
			map_data = b.build(self)
		elif b.has_method("build_map"):
			map_data = b.build_map(self)
	else:
		map_data = _fallback_box_map()

func _fallback_box_map() -> Dictionary:
	# Minimal greybox if map scripts not ready
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(60, 1, 60)
	mi.mesh = box
	mi.position = Vector3(0, -0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.27, 0.3)
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.4, 0.55, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.environment = e
	add_child(env)
	var spawns: Array = []
	for i in 16:
		var a := TAU * float(i) / 16.0
		spawns.append({"pos": Vector3(cos(a) * 18.0, 1.0, sin(a) * 18.0), "yaw": a + PI})
	var pickups: Array = [
		{"type": "mega_health", "pos": Vector3(0, 1, 0)},
		{"type": "weapon", "weapon_id": 6, "pos": Vector3(10, 1, 0)},
		{"type": "weapon", "weapon_id": 7, "pos": Vector3(-10, 1, 0)},
		{"type": "weapon", "weapon_id": 4, "pos": Vector3(0, 1, 10)},
		{"type": "weapon", "weapon_id": 3, "pos": Vector3(0, 1, -10)},
		{"type": "weapon", "weapon_id": 5, "pos": Vector3(8, 1, 8)},
		{"type": "stim", "pos": Vector3(5, 1, 5)},
		{"type": "stim", "pos": Vector3(-5, 1, 5)},
		{"type": "medkit", "pos": Vector3(5, 1, -5)},
		{"type": "armor_plate", "pos": Vector3(-5, 1, -5)},
		{"type": "armor_shard", "pos": Vector3(12, 1, 4)},
		{"type": "ammo", "pos": Vector3(-12, 1, 4)},
		{"type": "overcharge", "pos": Vector3(0, 1, 14)},
		{"type": "haste", "pos": Vector3(0, 1, -14)},
		{"type": "armor_shard", "pos": Vector3(14, 1, 0)},
		{"type": "medkit", "pos": Vector3(-14, 1, 0)},
		{"type": "ammo", "pos": Vector3(7, 1, -7)},
		{"type": "stim", "pos": Vector3(-7, 1, -7)},
		{"type": "armor_plate", "pos": Vector3(3, 1, 12)},
		{"type": "stim", "pos": Vector3(-3, 1, -12)},
	]
	# Kill volume
	var kv := Area3D.new()
	kv.collision_layer = 64
	kv.collision_mask = 2
	kv.monitoring = true
	var kcs := CollisionShape3D.new()
	var kbox := BoxShape3D.new()
	kbox.size = Vector3(200, 5, 200)
	kcs.shape = kbox
	kv.position = Vector3(0, -20, 0)
	kv.add_child(kcs)
	kv.body_entered.connect(func(b: Node) -> void:
		if b is Fighter:
			mm.auth_void_death((b as Fighter).id)
	)
	add_child(kv)
	return {"spawns": spawns, "pickups": pickups, "name": "Arena"}

func _spawn_fighters() -> void:
	var spawns: Array = map_data.get("spawns", [{"pos": Vector3(0, 2, 0), "yaw": 0.0}])
	if Game.match_config.online:
		_spawn_online_fighters(spawns)
		return
	var player := Fighter.new()
	player.id = mm.alloc_id()
	player.display_name = "You"
	player.color = UITheme.ACCENT
	add_child(player)
	player.setup_player()
	var s0: Dictionary = spawns[0]
	player.global_position = s0["pos"]
	player.movement.yaw = float(s0["yaw"])
	_attach_inventory(player)
	mm.local_player_id = player.id
	mm.auth_register_fighter(player)
	player.frozen = true
	_spawn_bots(spawns, 1)

func _spawn_online_fighters(spawns: Array) -> void:
	var peers: Array[int] = NetSession.peer_ids.duplicate()
	if peers.is_empty():
		peers.append(NetSession.local_client_id())
	peers.sort()
	var local_id := NetSession.local_client_id()
	var idx := 0
	for peer_id in peers:
		var f := Fighter.new()
		f.id = peer_id
		f.display_name = "P%d" % peer_id
		f.color = UITheme.BOT_COLORS[idx % UITheme.BOT_COLORS.size()] if UITheme.BOT_COLORS.size() > 0 else UITheme.ACCENT
		add_child(f)
		var si: Dictionary = spawns[idx % spawns.size()]
		f.global_position = si["pos"]
		f.movement.yaw = float(si["yaw"])
		if peer_id == local_id:
			f.display_name = "You"
			f.color = UITheme.ACCENT
			f.setup_player()
			mm.local_player_id = peer_id
		else:
			var ri := RemoteInput.new()
			f.is_bot = false
			f.input_source = ri
			if f.camera_rig:
				f.camera_rig.set_active(false)
			if f.visual:
				f.visual.set_first_person_hidden(false)
		_attach_inventory(f)
		mm.auth_register_fighter(f)
		f.frozen = true
		idx += 1
	# Only host simulates bot fill
	if NetSession.is_host() and Game.match_config.bot_count > 0:
		mm._next_id = 10000
		_spawn_bots(spawns, idx)

func _spawn_bots(spawns: Array, spawn_offset: int) -> void:
	var bot_count := Game.match_config.bot_count
	for i in bot_count:
		var bot := Fighter.new()
		bot.id = mm.alloc_id()
		bot.display_name = BotNames.name_at(i)
		bot.color = BotNames.color_at(i)
		add_child(bot)
		var input_src: InputSource = _make_bot_input(bot, i)
		bot.setup_bot(input_src)
		var si: Dictionary = spawns[(spawn_offset + i) % spawns.size()]
		bot.global_position = si["pos"]
		bot.movement.yaw = float(si["yaw"])
		_attach_inventory(bot)
		mm.auth_register_fighter(bot)
		bot.frozen = true

func _make_bot_input(bot: Fighter, index: int) -> InputSource:
	var bot_input_script = load("res://scripts/fighter/bot_input.gd")
	if bot_input_script:
		var bi = bot_input_script.new()
		if bi.has_method("configure"):
			bi.configure(bot, mm, Game.match_config.difficulty, index)
		return bi as InputSource
	# Fallback idle
	return InputSource.new()

func _attach_inventory(f: Fighter) -> void:
	var inv := WeaponInventory.new()
	f.add_child(inv)
	f.inventory = inv
	inv.shooter = f
	inv.owner_id = f.id
	inv.camera = f.camera_rig.camera if f.camera_rig else null
	inv.aim_provider = func() -> Transform3D:
		return Transform3D(Basis.from_euler(Vector3(f.movement.pitch, f.movement.yaw, 0)), f.aim_origin())
	inv.damage_sink = func(victim_id: int, info: DamageInfo) -> void:
		if net_bridge != null and Game.match_config.online:
			net_bridge.call("route_damage", victim_id, info)
		else:
			mm.auth_apply_damage(victim_id, info)
	if mm and mm.rng:
		inv.rng = mm.rng
	inv.refresh_excludes()
	if Game.match_config.has_mutator(MatchConfig.Mutator.INSTAGIB):
		inv.reset_loadout()
		for i in inv.owned.size():
			inv.owned[i] = false
		inv.give_weapon(7, true)
		inv.infinite_ammo = true
	elif Game.match_config.has_mutator(MatchConfig.Mutator.ROCKETS_ONLY):
		inv.reset_loadout()
		for i in inv.owned.size():
			inv.owned[i] = false
		inv.give_weapon(6, true)
		inv.infinite_ammo = true
	else:
		inv.reset_loadout()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var hud_script = load("res://scripts/ui/hud.gd")
	if hud_script:
		var h: Control = hud_script.new() as Control
		# Size before enter-tree so _ready/_place see a real viewport rect.
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud.add_child(h)
		if h.has_method("bind"):
			h.bind(mm)
	else:
		var speed := Label.new()
		speed.name = "SpeedFallback"
		speed.position = Vector2(20, 20)
		hud.add_child(speed)
		_debug_label = speed
	_debug_label = Label.new()
	_debug_label.visible = false
	_debug_label.position = Vector2(20, 200)
	hud.add_child(_debug_label)

func _build_pause() -> void:
	var pause_script = load("res://scripts/ui/pause_menu.gd")
	if pause_script:
		pause_ui = pause_script.new()
		pause_ui.visible = false
		pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(pause_ui)

func set_pause_visible(on: bool) -> void:
	if pause_ui:
		pause_ui.visible = on

func try_collect_pickup(f: Fighter, p: GamePickup) -> void:
	p.try_apply(f)

func on_fighter_killed(victim: Fighter) -> void:
	victim.visible = false
	# Debris burst
	var d := Debris.new()
	add_child(d)
	d.burst(victim.global_position, victim.color)
	Audio.play_sfx("death", victim.global_position)
	if victim.inventory is WeaponInventory:
		var inv := victim.inventory as WeaponInventory
		if inv.current_slot > 2 and inv.get_ammo(inv.current_slot) > 0:
			pickup_spawner.spawn_backpack(self, victim.global_position + Vector3.UP, inv.current_slot, int(inv.get_ammo(inv.current_slot) / 2))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		debug_on = not debug_on
		_debug_label.visible = debug_on

func _process(_dt: float) -> void:
	if debug_on and _debug_label:
		var p := mm.get_fighter(mm.local_player_id)
		if p:
			_debug_label.text = "spd %.1f  state %s  fps %d  bots %d" % [
				p.movement.horizontal_speed(p),
				p.movement.state_name(),
				Engine.get_frames_per_second(),
				Game.match_config.bot_count,
			]
