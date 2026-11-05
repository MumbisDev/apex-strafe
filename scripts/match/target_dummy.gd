class_name TargetDummy
extends Node3D
## Practice-range target: 100 health, body capsule + head sphere hitboxes (layer 5, hitboxes),
## floating damage numbers, respawns after 2 s. Not a Fighter: weapons damage it directly
## through take_damage(info) instead of MatchManager.

signal damaged(amount: float, is_head: bool)
signal died
signal respawned

enum Mode { STATIC, MOVING, STRAFING, POPUP }

const BODY_HEIGHT: float = 1.8
const BODY_RADIUS: float = 0.4
const HEAD_RADIUS: float = 0.22
const HEAD_HEIGHT: float = 1.62
const HITBOX_LAYER: int = 16 ## Physics layer 5 (hitboxes) as a bit value.
const NUMBER_POOL_SIZE: int = 4
const NUMBER_LIFETIME: float = 0.8
const NUMBER_RISE_SPEED: float = 1.4
const FLASH_TIME: float = 0.06
const DUMMY_COLOR: Color = Color(0.9, 0.35, 0.25)
const HEAD_NUMBER_COLOR: Color = Color(1.0, 0.82, 0.2)

static var _next_id: int = -1000

@export var mode: Mode = Mode.STATIC
@export var max_health: float = 100.0
@export var respawn_time: float = 2.0
@export var travel_axis: Vector3 = Vector3.RIGHT
@export var travel_distance: float = 6.0 ## Half length of the rail / strafe lane.
@export var travel_speed: float = 3.0 ## m/s along the lane (moving) or 2x for strafing.
@export var popup_up_time: float = 2.0
@export var popup_down_time: float = 1.5

var id: int = 0
var health: float = 100.0
var alive: bool = true
var hits_taken: int = 0
var total_damage_taken: float = 0.0
var last_info: DamageInfo
var last_impulse: Vector3 = Vector3.ZERO
var body_area: Area3D
var head_area: Area3D

var _origin: Vector3 = Vector3.ZERO
var _clock: float = 0.0
var _respawn_timer: float = 0.0
var _flash_timer: float = 0.0
var _targetable: bool = true
var _visual: Node3D
var _material: StandardMaterial3D
var _numbers: Array[Label3D] = []
var _number_ages: Array[float] = []
var _next_number: int = 0


func _init() -> void:
	id = _next_id
	_next_id -= 1


func _ready() -> void:
	add_to_group(WeaponUtils.GROUP_DUMMY)
	health = max_health
	_origin = position
	_build_hitboxes()
	_build_visual()
	_build_number_pool()
	_apply_targetable(mode != Mode.POPUP or _popup_is_up())


func get_center_position() -> Vector3:
	return global_position + Vector3.UP * WeaponUtils.BODY_CENTER_HEIGHT


func get_head_position() -> Vector3:
	return global_position + Vector3.UP * HEAD_HEIGHT


## Applies damage; returns true when this hit killed the dummy.
func take_damage(info: DamageInfo) -> bool:
	if not alive or not _targetable:
		return false
	last_info = info
	last_impulse = info.impulse
	hits_taken += 1
	total_damage_taken += info.amount
	health -= info.amount
	_flash_timer = FLASH_TIME
	_show_number(info.amount, info.is_head)
	damaged.emit(info.amount, info.is_head)
	if health <= 0.0:
		_die()
		return true
	return false


## Restores full health immediately and clears the damage counters.
func reset() -> void:
	health = max_health
	hits_taken = 0
	total_damage_taken = 0.0
	last_info = null
	_respawn()


func _die() -> void:
	alive = false
	_respawn_timer = respawn_time
	_apply_targetable(false)
	_visual.visible = false
	died.emit()


func _respawn() -> void:
	alive = true
	health = max_health
	_respawn_timer = 0.0
	_apply_targetable(mode != Mode.POPUP or _popup_is_up())
	_visual.visible = _targetable
	respawned.emit()


func _physics_process(delta: float) -> void:
	_clock += delta
	if not alive:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return
	match mode:
		Mode.MOVING:
			position = _origin + travel_axis.normalized() * _ping_pong(travel_speed)
		Mode.STRAFING:
			position = _origin + travel_axis.normalized() * _ping_pong(travel_speed * 2.0)
		Mode.POPUP:
			var up: bool = _popup_is_up()
			if up != _targetable:
				_apply_targetable(up)
				_visual.visible = up


## Triangle wave in [-travel_distance, travel_distance] driven by the physics clock.
func _ping_pong(speed: float) -> float:
	var span: float = maxf(travel_distance, 0.01) * 4.0
	var phase: float = fposmod(_clock * speed, span)
	return (phase if phase < span * 0.5 else span - phase) - travel_distance


func _popup_is_up() -> bool:
	return fposmod(_clock, popup_up_time + popup_down_time) < popup_up_time


func _apply_targetable(value: bool) -> void:
	_targetable = value
	var layer: int = HITBOX_LAYER if value else 0
	body_area.collision_layer = layer
	head_area.collision_layer = layer


# ---------------------------------------------------------------- construction

func _build_hitboxes() -> void:
	body_area = _make_area("BodyHitbox", &"body")
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	_add_shape(body_area, capsule, Vector3(0.0, BODY_HEIGHT * 0.5, 0.0))
	head_area = _make_area("HeadHitbox", &"head")
	var sphere := SphereShape3D.new()
	sphere.radius = HEAD_RADIUS
	_add_shape(head_area, sphere, Vector3(0.0, HEAD_HEIGHT, 0.0))


func _make_area(area_name: String, part: StringName) -> Area3D:
	var area := Area3D.new()
	area.name = area_name
	area.collision_layer = HITBOX_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta(WeaponUtils.OWNER_META, self)
	area.set_meta(WeaponUtils.PART_META, String(part))
	add_child(area)
	return area


func _add_shape(area: Area3D, shape: Shape3D, offset: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = offset
	area.add_child(collision)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_material = StandardMaterial3D.new()
	_material.albedo_color = DUMMY_COLOR
	_material.emission_enabled = true
	_material.emission = DUMMY_COLOR
	_material.emission_energy_multiplier = 0.4
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT - 0.3
	torso.mesh = capsule
	torso.position = Vector3(0.0, (BODY_HEIGHT - 0.3) * 0.5, 0.0)
	torso.material_override = _material
	_visual.add_child(torso)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = HEAD_RADIUS
	sphere.height = HEAD_RADIUS * 2.0
	head.mesh = sphere
	head.position = Vector3(0.0, HEAD_HEIGHT, 0.0)
	head.material_override = _material
	_visual.add_child(head)


func _build_number_pool() -> void:
	for i in NUMBER_POOL_SIZE:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.top_level = true
		label.font_size = 64
		label.pixel_size = 0.006
		label.outline_size = 12
		label.visible = false
		add_child(label)
		_numbers.append(label)
		_number_ages.append(NUMBER_LIFETIME)


func _show_number(amount: float, is_head: bool) -> void:
	var slot: int = _next_number
	_next_number = (_next_number + 1) % NUMBER_POOL_SIZE
	var label: Label3D = _numbers[slot]
	label.text = str(roundi(amount))
	label.modulate = HEAD_NUMBER_COLOR if is_head else Color.WHITE
	label.global_position = get_head_position() + Vector3.UP * 0.4
	label.visible = true
	_number_ages[slot] = 0.0


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		_material.albedo_color = Color.WHITE if _flash_timer > 0.0 else DUMMY_COLOR
	for i in NUMBER_POOL_SIZE:
		if _number_ages[i] >= NUMBER_LIFETIME:
			continue
		_number_ages[i] += delta
		var label: Label3D = _numbers[i]
		label.global_position += Vector3.UP * NUMBER_RISE_SPEED * delta
		label.modulate.a = clampf(1.0 - _number_ages[i] / NUMBER_LIFETIME, 0.0, 1.0)
		if _number_ages[i] >= NUMBER_LIFETIME:
			label.visible = false
