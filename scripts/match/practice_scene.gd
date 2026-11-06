extends Node3D

var player: Fighter
var mm: MatchManager
var speed_label: Label
var debug_on: bool = false
var pause_ui: Control = null

func _ready() -> void:
	name = "Practice"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mm = MatchManager.new()
	add_child(mm)
	var cfg := MatchConfig.new()
	cfg.practice = true
	cfg.map_id = "range"
	cfg.bot_count = 0
	cfg.seed = 1
	Game.match_config = cfg
	var map_data: Dictionary = {}
	var map_script = load("res://scripts/maps/map_range.gd")
	if map_script:
		var b = map_script.new()
		map_data = b.build(self)
	else:
		map_data = _simple_range()
	mm.setup(cfg, self)
	mm.spawn_system.set_spawns(map_data.get("spawns", [{"pos": Vector3(0, 2, 0), "yaw": 0.0}]))
	mm.phase = MatchManager.Phase.LIVE
	player = Fighter.new()
	player.id = mm.alloc_id()
	player.display_name = "You"
	player.color = UITheme.ACCENT
	add_child(player)
	player.setup_player()
	var s: Dictionary = mm.spawn_system.spawns[0] if not mm.spawn_system.spawns.is_empty() else {"pos": Vector3(0, 2, 0), "yaw": 0.0}
	player.global_position = s["pos"]
	player.movement.yaw = float(s.get("yaw", 0.0))
	var inv := WeaponInventory.new()
	player.add_child(inv)
	player.inventory = inv
	inv.shooter = player
	inv.owner_id = player.id
	inv.camera = player.camera_rig.camera
	inv.aim_provider = func() -> Transform3D:
		return Transform3D(Basis.from_euler(Vector3(player.movement.pitch, player.movement.yaw, 0)), player.aim_origin())
	inv.damage_sink = func(victim_id: int, info: DamageInfo) -> void:
		mm.auth_apply_damage(victim_id, info)
	for slot in range(1, WeaponLibrary.SLOT_COUNT + 1):
		inv.give_weapon(slot, false)
	inv.select_slot(WeaponLibrary.SLOT_PISTOL)
	inv.refresh_excludes()
	var vm_script: GDScript = load("res://scripts/weapons/viewmodel.gd") as GDScript
	var vm: Node3D = vm_script.new() as Node3D
	vm.call("attach", player.camera_rig.camera, inv)
	player.viewmodel = vm
	mm.local_player_id = player.id
	mm.auth_register_fighter(player)
	_build_hud()
	_build_pause()

func set_pause_visible(on: bool) -> void:
	if pause_ui:
		pause_ui.visible = on

func _build_pause() -> void:
	var pause_script: GDScript = load("res://scripts/ui/pause_menu.gd") as GDScript
	if pause_script == null:
		return
	pause_ui = pause_script.new() as Control
	pause_ui.visible = false
	pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_ui)

func _simple_range() -> Dictionary:
	var floor_mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(80, 1, 50)
	floor_mi.mesh = box
	floor_mi.position = Vector3(0, -0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.35)
	floor_mi.material_override = mat
	add_child(floor_mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	body.add_child(cs)
	floor_mi.add_child(body)
	# Wall-run corridor walls
	_wall(Vector3(20, 3, -8), Vector3(30, 6, 0.5))
	_wall(Vector3(20, 3, -12), Vector3(30, 6, 0.5))
	# Mantle crates
	for h in [1.0, 1.4, 1.8]:
		_box_obs(Vector3(-10, h * 0.5, 5 + h), Vector3(1.2, h, 1.2))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 20, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.5, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.35, 0.4)
	env.environment = e
	add_child(env)
	return {"spawns": [{"pos": Vector3(0, 1.0, 0), "yaw": 0.0}], "pickups": []}

func _wall(pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.42, 0.48)
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)

func _box_obs(pos: Vector3, size: Vector3) -> void:
	_wall(pos, size)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	speed_label = Label.new()
	speed_label.position = Vector2(40, 40)
	speed_label.add_theme_font_size_override("font_size", 28)
	speed_label.add_theme_color_override("font_color", UITheme.ACCENT)
	layer.add_child(speed_label)
	var hint := Label.new()
	hint.text = "PRACTICE  |  R reset  |  Esc pause / leave  |  F3 debug"
	hint.position = Vector2(40, 80)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	layer.add_child(hint)

func _physics_process(_dt: float) -> void:
	if player and speed_label:
		var ups := player.movement.horizontal_speed(player) * (39.37 / 3.28) ## rough Quake ups aesthetic: use m/s*10 display
		speed_label.text = "SPEED  %.1f m/s   %s" % [player.movement.horizontal_speed(player), player.movement.state_name()]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("practice_reset") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_R):
		player.global_position = Vector3(0, 2, 0)
		player.velocity = Vector3.ZERO
	if event.is_action_pressed("debug_overlay"):
		debug_on = not debug_on
