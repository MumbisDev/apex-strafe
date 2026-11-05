class_name Fighter
extends CharacterBody3D

var id: int = 0
var display_name: String = "Player"
var color: Color = Color.WHITE
var is_bot: bool = false
var input_source: InputSource
var movement: MovementController
var health: HealthComponent
var visual: FighterVisual
var camera_rig: CameraRig
var inventory: Node ## WeaponInventory when available
var frozen: bool = false
var score: int = 0
var kills: int = 0
var deaths: int = 0
var damage_dealt: float = 0.0
var best_streak: int = 0
var current_streak: int = 0
var accuracy_shots: int = 0
var accuracy_hits: int = 0
var top_speed: float = 0.0
var medals: int = 0
var last_spawn_idx: int = -1
var body_hitbox: Area3D
var head_hitbox: Area3D
var _was_on_floor: bool = true
var _player_input: PlayerInput
var match_manager: Node = null

func _ready() -> void:
	_configure_body()
	movement = MovementController.new()
	health = HealthComponent.new()
	visual = FighterVisual.new()
	add_child(visual)
	visual.build(color)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.build(self)
	_build_hitboxes()
	collision_layer = 2 ## fighters
	collision_mask = 1 ## world only
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5
	floor_stop_on_slope = false
	floor_constant_speed = false
	max_slides = 6
	safe_margin = 0.001
	add_to_group("fighters")

func _configure_body() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

func _build_hitboxes() -> void:
	body_hitbox = Area3D.new()
	body_hitbox.name = "BodyHitbox"
	body_hitbox.collision_layer = 16 ## hitboxes layer 5 = bit 16
	body_hitbox.collision_mask = 0
	body_hitbox.monitoring = false
	body_hitbox.monitorable = true
	body_hitbox.set_meta("fighter", self)
	body_hitbox.set_meta("part", "body")
	var bs := CollisionShape3D.new()
	var bc := CapsuleShape3D.new()
	bc.radius = 0.4
	bc.height = 1.8
	bs.shape = bc
	bs.position = Vector3(0, 0.9, 0)
	body_hitbox.add_child(bs)
	add_child(body_hitbox)

	head_hitbox = Area3D.new()
	head_hitbox.name = "HeadHitbox"
	head_hitbox.collision_layer = 16
	head_hitbox.collision_mask = 0
	head_hitbox.monitoring = false
	head_hitbox.monitorable = true
	head_hitbox.set_meta("fighter", self)
	head_hitbox.set_meta("part", "head")
	var hs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.22
	hs.shape = sp
	hs.position = Vector3(0, 1.62, 0)
	head_hitbox.add_child(hs)
	add_child(head_hitbox)

func setup_player() -> void:
	is_bot = false
	_player_input = PlayerInput.new()
	input_source = _player_input
	camera_rig.set_active(true)
	visual.set_first_person_hidden(true)

func setup_bot(brain_input: InputSource) -> void:
	is_bot = true
	input_source = brain_input
	camera_rig.set_active(false)
	visual.set_first_person_hidden(false)

func _unhandled_input(event: InputEvent) -> void:
	if _player_input and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_player_input.push_look((event as InputEventMouseMotion).relative)

func _physics_process(dt: float) -> void:
	if frozen or not health.alive:
		return
	health.tick(dt)
	if input_source == null:
		return
	var frame := input_source.sample(dt, self)
	var prev_y := velocity.y
	movement.step(self, frame, dt)
	rotation.y = movement.yaw
	var speed := movement.horizontal_speed(self)
	top_speed = maxf(top_speed, speed)
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and prev_y < -1.0:
		Events.fighter_landed.emit(id, absf(prev_y))
		camera_rig.on_landed(absf(prev_y))
		Audio.play_sfx("land_heavy" if absf(prev_y) > 12.0 else "land_light")
	_was_on_floor = on_floor
	var wall_side := 1.0 if movement.wall_normal.x + movement.wall_normal.z > 0.0 else -1.0
	if not is_bot:
		camera_rig.tick(dt, movement, speed, wall_side)
	visual.tick(speed, movement.crouching, movement.state == MovementController.State.SLIDE, not on_floor)
	if inventory and inventory is WeaponInventory:
		var inv := inventory as WeaponInventory
		inv.step(frame, dt)
	elif inventory and inventory.has_method("step"):
		inventory.call("step", frame, dt)

func aim_origin() -> Vector3:
	return global_position + Vector3.UP * movement.eye_height()

func aim_dir() -> Vector3:
	return movement._aim_dir()

func apply_impulse(imp: Vector3) -> void:
	velocity += imp
