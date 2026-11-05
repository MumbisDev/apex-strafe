class_name Viewmodel
extends Node3D
## First-person weapon models built from primitive meshes with procedural animation
## (recoil springs, raise/lower, sway, bob, slide pose, muzzle flash).
## FALLBACK rendering (GDD 7): every material uses no_depth_test with ascending render_priority,
## so the weapon never clips into walls and no SubViewport is needed.

const BASE_OFFSET: Vector3 = Vector3(0.26, -0.24, -0.5)
const MINIMAL_SCALE: float = 0.6
const PRIORITY_BASE: int = 20
const FLASH_PRIORITY: int = 100
const FLASH_TIME: float = 0.05
const RECOIL_STIFFNESS: float = 240.0
const RECOIL_DAMPING: float = 20.0
const SWAY_LOOK_GAIN: float = 1.2
const SWAY_MOVE_GAIN: float = 0.004
const SWAY_MAX: float = 0.06
const BOB_REFERENCE_SPEED: float = 9.0
const LOWER_DROP: float = 0.38
const LOWER_PITCH: float = 0.9

enum Mode { FULL, MINIMAL, HIDDEN }

var inventory: WeaponInventory
var mode: Mode = Mode.FULL

var _pivot: Node3D
var _models: Array[Node3D] = []
var _muzzles: Array[Node3D] = []
var _flashes: Array[MeshInstance3D] = []
var _flash_light: OmniLight3D
var _flash_timer: float = 0.0
var _part_index: int = 0
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
	_show_slot(WeaponLibrary.SLOT_PISTOL)


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


## Root node of the primitive model for a slot (1..7); empty until the viewmodel is in the tree.
func get_model(slot: int) -> Node3D:
	return _models[slot - 1] if slot >= 1 and slot <= _models.size() else null


func get_muzzle_global_position() -> Vector3:
	var slot: int = inventory.current_slot if inventory != null else WeaponLibrary.SLOT_PISTOL
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
		kick(0.5, 7.0)
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
	_part_index = 0
	var body: Color = def.model_color
	var dark: Color = body.darkened(0.45)
	var glow: Color = def.tracer_color
	var muzzle_z: float = -0.4
	match def.id:
		WeaponLibrary.SLOT_BLADE:
			_box(root, Vector3(0.035, 0.04, 0.14), Vector3(0, 0, 0.04), dark)
			_box(root, Vector3(0.13, 0.025, 0.03), Vector3(0, 0, -0.04), body)
			_box(root, Vector3(0.018, 0.07, 0.46), Vector3(0, 0, -0.30), body.lightened(0.3))
			_box(root, Vector3(0.006, 0.006, 0.44), Vector3(0, 0.038, -0.30), glow, true)
			_box(root, Vector3(0.03, 0.03, 0.03), Vector3(0, 0, 0.12), body)
			muzzle_z = -0.55
		WeaponLibrary.SLOT_PISTOL:
			_box(root, Vector3(0.05, 0.06, 0.26), Vector3(0, 0.03, -0.08), body)
			_box(root, Vector3(0.045, 0.12, 0.06), Vector3(0, -0.06, 0.02), dark)
			_cyl(root, 0.013, 0.1, Vector3(0, 0.03, -0.25), dark)
			_box(root, Vector3(0.052, 0.008, 0.18), Vector3(0, 0.05, -0.08), glow, true)
			_box(root, Vector3(0.02, 0.02, 0.06), Vector3(0, -0.02, -0.06), dark)
			muzzle_z = -0.31
		WeaponLibrary.SLOT_SMG:
			_box(root, Vector3(0.06, 0.08, 0.34), Vector3(0, 0, -0.1), body)
			_box(root, Vector3(0.04, 0.06, 0.14), Vector3(0, -0.01, 0.16), dark)
			_box(root, Vector3(0.04, 0.16, 0.05), Vector3(0, -0.12, -0.08), dark)
			_box(root, Vector3(0.045, 0.1, 0.05), Vector3(0, -0.08, 0.04), dark)
			_cyl(root, 0.015, 0.14, Vector3(0, 0.01, -0.34), dark)
			_box(root, Vector3(0.062, 0.008, 0.28), Vector3(0, 0.044, -0.1), glow, true)
			_box(root, Vector3(0.02, 0.025, 0.05), Vector3(0, 0.055, -0.02), dark)
			muzzle_z = -0.42
		WeaponLibrary.SLOT_SHOTGUN:
			_box(root, Vector3(0.07, 0.09, 0.26), Vector3(0, 0, 0.0), body)
			_cyl(root, 0.024, 0.56, Vector3(0, 0.03, -0.3), dark)
			_cyl(root, 0.018, 0.4, Vector3(0, -0.02, -0.26), dark)
			_box(root, Vector3(0.065, 0.05, 0.14), Vector3(0, -0.02, -0.28), body.lightened(0.15))
			_box(root, Vector3(0.05, 0.08, 0.24), Vector3(0, -0.03, 0.24), dark)
			_box(root, Vector3(0.072, 0.008, 0.2), Vector3(0, 0.048, 0.0), glow, true)
			muzzle_z = -0.6
		WeaponLibrary.SLOT_PLASMA:
			_box(root, Vector3(0.08, 0.09, 0.3), Vector3(0, 0, -0.05), body)
			_cyl(root, 0.034, 0.3, Vector3(0, 0.01, -0.3), dark)
			_cyl(root, 0.016, 0.34, Vector3(0, 0.01, -0.3), glow, true)
			_cyl(root, 0.05, 0.02, Vector3(0, 0.01, -0.22), glow, true)
			_cyl(root, 0.05, 0.02, Vector3(0, 0.01, -0.34), glow, true)
			_box(root, Vector3(0.05, 0.11, 0.06), Vector3(0, -0.09, 0.06), dark)
			_box(root, Vector3(0.05, 0.06, 0.12), Vector3(0, -0.01, 0.2), dark)
			muzzle_z = -0.48
		WeaponLibrary.SLOT_ROCKET:
			_cyl(root, 0.065, 0.7, Vector3(0, 0.03, -0.22), body)
			_cyl(root, 0.08, 0.08, Vector3(0, 0.03, 0.15), dark)
			_cyl(root, 0.072, 0.03, Vector3(0, 0.03, -0.55), glow, true)
			_box(root, Vector3(0.05, 0.1, 0.06), Vector3(0, -0.08, -0.02), dark)
			_box(root, Vector3(0.04, 0.08, 0.05), Vector3(0, -0.07, -0.24), dark)
			_box(root, Vector3(0.02, 0.04, 0.1), Vector3(0, 0.11, -0.2), dark)
			_box(root, Vector3(0.02, 0.008, 0.4), Vector3(0, 0.097, -0.22), glow, true)
			muzzle_z = -0.58
		_:
			_box(root, Vector3(0.05, 0.07, 0.5), Vector3(0, 0, -0.1), body)
			_box(root, Vector3(0.016, 0.03, 0.55), Vector3(0.04, 0.0, -0.3), glow, true)
			_box(root, Vector3(0.016, 0.03, 0.55), Vector3(-0.04, 0.0, -0.3), glow, true)
			_cyl(root, 0.022, 0.2, Vector3(0, 0.075, -0.12), dark)
			_box(root, Vector3(0.05, 0.1, 0.06), Vector3(0, -0.08, 0.05), dark)
			_box(root, Vector3(0.045, 0.08, 0.2), Vector3(0, -0.02, 0.25), dark)
			_cyl(root, 0.012, 0.3, Vector3(0, 0.0, -0.45), dark)
			muzzle_z = -0.6
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, muzzle_z)
	root.add_child(muzzle)
	_muzzles.append(muzzle)
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.28 if def.id != WeaponLibrary.SLOT_ROCKET else 0.4)
	flash.mesh = quad
	flash.material_override = _make_material(Color(glow, 0.9), true, FLASH_PRIORITY, true)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)
	_flashes.append(flash)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_part(parent, mesh, pos, Vector3.ZERO, color, glow)


## Cylinder lying along the Z axis (barrel direction).
func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, glow: bool = false) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	_add_part(parent, mesh, pos, Vector3(deg_to_rad(90.0), 0.0, 0.0), color, glow)


func _add_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, color: Color, glow: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.material_override = _make_material(color, glow, PRIORITY_BASE + _part_index, false)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_part_index += 1
	parent.add_child(instance)


func _make_material(color: Color, glow: bool, priority: int, additive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.no_depth_test = true
	mat.render_priority = clampi(priority, -128, 127)
	mat.roughness = 0.6
	if glow:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = 2.5
	if additive:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat
