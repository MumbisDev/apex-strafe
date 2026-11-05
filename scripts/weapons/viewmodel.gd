class_name Viewmodel
extends Node3D
## First-person weapon models built from primitive meshes with procedural animation
## (recoil springs, raise/lower, sway, bob, slide pose, muzzle flash).
## FALLBACK rendering (GDD 7): every material uses no_depth_test with ascending render_priority,
## so the weapon never clips into walls and no SubViewport is needed.

const BASE_OFFSET: Vector3 = Vector3(0.26, -0.24, -0.5)
const MINIMAL_SCALE: float = 0.6
const FLASH_PRIORITY: int = 100
const MESHES_SCRIPT: String = "res://scripts/weapons/viewmodel_meshes.gd"
const FLASH_TIME: float = 0.05
const RECOIL_STIFFNESS: float = 240.0
const RECOIL_DAMPING: float = 20.0
const SWAY_LOOK_GAIN: float = 1.2
const SWAY_MOVE_GAIN: float = 0.004
const SWAY_MAX: float = 0.06
const BOB_REFERENCE_SPEED: float = 9.0
const LOWER_DROP: float = 0.38
const LOWER_PITCH: float = 0.9
const SWING_DURATION: float = 0.42
## Idle hold: blade upright, tip up, slight lean into view.
const BLADE_REST_ROT: Vector3 = Vector3(0.12, -0.22, -0.18)
const BLADE_REST_POS: Vector3 = Vector3(0.04, -0.06, 0.08)
## Swing keyframes as offsets from rest. −Z is away from the camera into the world.
## Columns: time (0..1), position offset, rotation offset (radians).
const SWING_KEYS: Array[Dictionary] = [
	{"t": 0.00, "pos": Vector3(0.10, 0.08, 0.14), "rot": Vector3(0.55, 0.55, 0.70)},
	{"t": 0.18, "pos": Vector3(0.12, 0.14, -0.12), "rot": Vector3(-0.35, 0.40, 0.35)},
	{"t": 0.42, "pos": Vector3(-0.02, 0.02, -0.58), "rot": Vector3(-1.45, -0.15, -0.55)},
	{"t": 0.62, "pos": Vector3(-0.28, -0.16, -0.42), "rot": Vector3(-0.85, -0.85, -1.55)},
	{"t": 1.00, "pos": Vector3.ZERO, "rot": Vector3.ZERO},
]

enum Mode { FULL, MINIMAL, HIDDEN }

var inventory: WeaponInventory
var mode: Mode = Mode.FULL

var _pivot: Node3D
var _models: Array[Node3D] = []
var _muzzles: Array[Node3D] = []
var _flashes: Array[MeshInstance3D] = []
var _flash_light: OmniLight3D
var _flash_timer: float = 0.0
var _clock: float = 0.0
var _bob_phase: float = 0.0
var _rec_z: Vector2 = Vector2.ZERO ## (position, velocity) of the backwards recoil spring.
var _rec_pitch: Vector2 = Vector2.ZERO
var _rec_yaw: Vector2 = Vector2.ZERO
var _sway: Vector3 = Vector3.ZERO
var _look_delta: Vector2 = Vector2.ZERO
var _local_velocity: Vector3 = Vector3.ZERO
var _sliding: bool = false
var _slide_blend: float = 0.0
var _swing_t: float = 1.0 ## 0 = swing start, 1 = idle


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	for def in WeaponLibrary.all():
		_build_model(def)
	_flash_light = OmniLight3D.new()
	_flash_light.light_energy = 2.0
	_flash_light.omni_range = 6.0
	_flash_light.visible = false
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	var settings := WeaponUtils.get_autoload(&"Settings")
	if settings != null and settings.get("viewmodel_mode") != null:
		set_mode(int(settings.get("viewmodel_mode")) as Mode)
	_show_slot(WeaponLibrary.SLOT_BLADE)


## Parents the viewmodel to the player camera and follows the inventory's current weapon.
func attach(camera: Camera3D, weapon_inventory: WeaponInventory) -> void:
	if get_parent() != camera:
		if get_parent() != null:
			get_parent().remove_child(self)
		camera.add_child(self)
	inventory = weapon_inventory
	inventory.weapon_changed.connect(_show_slot)
	inventory.weapon_fired.connect(_on_weapon_fired)
	inventory.muzzle_provider = get_muzzle_global_position
	if not _models.is_empty():
		_show_slot(inventory.current_slot)


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	visible = mode != Mode.HIDDEN


## Feed once per tick: look delta (radians), velocity in camera space (x right, z back).
func set_motion(look_delta: Vector2, local_velocity: Vector3, sliding: bool) -> void:
	_look_delta = look_delta
	_local_velocity = local_velocity
	_sliding = sliding


## Root node of the primitive model for a slot; empty until the viewmodel is in the tree.
func get_model(slot: int) -> Node3D:
	return _models[slot - 1] if slot >= 1 and slot <= _models.size() else null


func get_muzzle_global_position() -> Vector3:
	var slot: int = inventory.current_slot if inventory != null else WeaponLibrary.SLOT_BLADE
	return _muzzles[slot - 1].global_position


## Adds a recoil impulse; strength 1.0 is a typical rifle shot.
func kick(strength: float, swing: float = 0.0) -> void:
	_rec_z.y += 1.4 * strength
	_rec_pitch.y += 4.0 * strength
	_rec_yaw.y += swing


func _show_slot(slot: int) -> void:
	for i in _models.size():
		_models[i].visible = (i + 1) == slot
		_flashes[i].visible = false


func _on_weapon_fired(slot: int) -> void:
	var def: WeaponDef = WeaponLibrary.get_def(slot)
	if def.is_melee():
		_swing_t = 0.0
		kick(0.35, 0.0)
		return
	kick(0.6 + def.kick_pitch_deg * 0.5)
	_flash_timer = FLASH_TIME
	_flashes[slot - 1].visible = true
	_flashes[slot - 1].rotation.z = randf() * TAU
	_flash_light.light_color = def.tracer_color
	_flash_light.global_position = _muzzles[slot - 1].global_position
	_flash_light.visible = true


# ---------------------------------------------------------------- animation

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	_clock += dt
	_rec_z = _step_spring(_rec_z, dt)
	_rec_pitch = _step_spring(_rec_pitch, dt)
	_rec_yaw = _step_spring(_rec_yaw, dt)
	if _swing_t < 1.0:
		_swing_t = minf(_swing_t + dt / SWING_DURATION, 1.0)
	if _flash_timer > 0.0:
		_flash_timer -= dt
		if _flash_timer <= 0.0:
			_flash_light.visible = false
			for flash in _flashes:
				flash.visible = false
	var sway_target := Vector3(
		clampf(-_look_delta.x * SWAY_LOOK_GAIN - _local_velocity.x * SWAY_MOVE_GAIN, -SWAY_MAX, SWAY_MAX),
		clampf(_look_delta.y * SWAY_LOOK_GAIN, -SWAY_MAX, SWAY_MAX),
		clampf(_local_velocity.z * SWAY_MOVE_GAIN * 0.5, -SWAY_MAX, SWAY_MAX))
	_sway = _sway.lerp(sway_target, 1.0 - exp(-12.0 * dt))
	_slide_blend = move_toward(_slide_blend, 1.0 if _sliding else 0.0, dt * 6.0)
	var speed: float = Vector2(_local_velocity.x, _local_velocity.z).length()
	var speed_scale: float = clampf(speed / BOB_REFERENCE_SPEED, 0.0, 1.0)
	_bob_phase += dt * (2.0 + speed * 1.1)
	var bob := Vector3(
		sin(_bob_phase) * 0.003 * speed_scale,
		sin(_clock * 1.6) * 0.0015 + absf(cos(_bob_phase)) * 0.006 * speed_scale,
		0.0)
	var lower: float = 0.0
	if inventory != null:
		var raised: float = inventory.raise_progress()
		lower = 1.0 - raised * raised * (3.0 - 2.0 * raised)
		visible = mode != Mode.HIDDEN and not inventory.zoomed
	var scale_factor: float = MINIMAL_SCALE if mode == Mode.MINIMAL else 1.0
	_pivot.scale = Vector3.ONE * scale_factor
	_pivot.position = BASE_OFFSET * scale_factor + _sway + bob \
			+ Vector3(0.0, -LOWER_DROP * lower - 0.05 * _slide_blend, _rec_z.x + 0.1 * lower)
	_pivot.rotation = Vector3(
		_rec_pitch.x - LOWER_PITCH * lower,
		_rec_yaw.x + deg_to_rad(8.0) * _slide_blend,
		deg_to_rad(-24.0) * _slide_blend - _sway.x * 2.0)
	_update_blade_pose()


## Arc slash: cock back, drive the tip away from the camera, cut across, recover.
func _update_blade_pose() -> void:
	var blade: Node3D = get_model(WeaponLibrary.SLOT_BLADE)
	if blade == null:
		return
	if _swing_t >= 1.0:
		blade.rotation = BLADE_REST_ROT
		blade.position = BLADE_REST_POS
		return
	var sample: Dictionary = _sample_swing(_swing_t)
	blade.position = BLADE_REST_POS + (sample["pos"] as Vector3)
	blade.rotation = BLADE_REST_ROT + (sample["rot"] as Vector3)


func _sample_swing(t: float) -> Dictionary:
	var i: int = 0
	while i + 1 < SWING_KEYS.size() and float(SWING_KEYS[i + 1]["t"]) < t:
		i += 1
	var a: Dictionary = SWING_KEYS[i]
	var b: Dictionary = SWING_KEYS[mini(i + 1, SWING_KEYS.size() - 1)]
	var t0: float = float(a["t"])
	var t1: float = float(b["t"])
	var u: float = 0.0 if t1 <= t0 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	return {
		"pos": (a["pos"] as Vector3).lerp(b["pos"] as Vector3, u),
		"rot": (a["rot"] as Vector3).lerp(b["rot"] as Vector3, u),
	}


## One semi-implicit Euler step of a damped spring pulling x (v.x) back to zero.
func _step_spring(state: Vector2, dt: float) -> Vector2:
	var accel: float = -RECOIL_STIFFNESS * state.x - RECOIL_DAMPING * state.y
	var vel: float = state.y + accel * dt
	return Vector2(state.x + vel * dt, vel)


# ---------------------------------------------------------------- model construction

func _build_model(def: WeaponDef) -> void:
	var root := Node3D.new()
	root.name = String(def.key).capitalize().replace(" ", "")
	_pivot.add_child(root)
	_models.append(root)
	var meshes_script: GDScript = load(MESHES_SCRIPT) as GDScript
	var meshes: RefCounted = meshes_script.new() as RefCounted
	var tip: float = float(meshes.call("build", root, def))
	var glow: Color = def.tracer_color
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	# Blade is vertical (+Y); guns point forward (−Z).
	if def.is_melee():
		muzzle.position = Vector3(0.0, tip, 0.0)
		root.rotation = BLADE_REST_ROT
		root.position = BLADE_REST_POS
	else:
		muzzle.position = Vector3(0.0, 0.02, tip)
	root.add_child(muzzle)
	_muzzles.append(muzzle)
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.28 if def.id != WeaponLibrary.SLOT_ROCKET else 0.4)
	flash.mesh = quad
	flash.material_override = _make_flash_material(Color(glow, 0.9))
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)
	_flashes.append(flash)


func _make_flash_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.no_depth_test = true
	mat.render_priority = FLASH_PRIORITY
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 3.0
	return mat
