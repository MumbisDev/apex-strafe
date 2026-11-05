class_name FxLibrary
extends Node3D
## World-space cosmetic FX hub. Pre-warms ring-buffer pools and reacts to Events:
## explosions, hitscan tracers + world impacts + decals, fighter hit sparks, grapple ropes.

const GROUP: String = "fx_library"
const WORLD_MASK: int = 1
const HITBOX_MASK: int = 16
const TRACE_RANGE: float = 200.0
const SHOTGUN_VISUAL_PELLETS: int = 4
const SHOTGUN_SPREAD_DEG: float = 4.5
const RAIL_LINGER: float = 0.8
const SHOTGUN_SLOT: int = 4
const RAIL_SLOT: int = 7
## Weapon slot -> tracer color. Slots without an entry (blade, plasma, rocket) spawn no tracer.
const TRACER_COLORS: Dictionary = {
	2: Color("#19E3FF"), 3: Color("#FFE033"), 4: Color("#FFFFFF"), 7: Color("#FF33E6"),
}
const POOL_EXPLOSIONS: int = 6
const POOL_TRACERS: int = 24
const POOL_IMPACTS: int = 16
const POOL_DECALS: int = 48
const POOL_ROPES: int = 12

var _explosions: Ring = Ring.new()
var _tracers: Ring = Ring.new()
var _impacts: Ring = Ring.new()
var _decals: Ring = Ring.new()
var _ropes: Dictionary = {} ## fighter id -> GrappleRope
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

class Ring:
	var items: Array[Node3D] = []
	var cursor: int = 0

	func next() -> Node3D:
		var n := items[cursor]
		cursor = (cursor + 1) % items.size()
		return n

func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = 777
	_fill(_explosions, POOL_EXPLOSIONS, Explosion)
	_fill(_tracers, POOL_TRACERS, Tracer)
	_fill(_impacts, POOL_IMPACTS, Impact)
	_fill(_decals, POOL_DECALS, BulletDecal)
	Events.explosion.connect(_on_explosion)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.fighter_damaged.connect(_on_fighter_damaged)
	Events.grapple_attached.connect(_on_grapple_attached)
	Events.grapple_released.connect(_on_grapple_released)

# -- public spawn API (also used by tests) ------------------------------------

func spawn_explosion(pos: Vector3, radius: float) -> void:
	(_explosions.next() as Explosion).play(pos, radius)

func spawn_tracer(from: Vector3, to: Vector3, color: Color, linger: float = 0.0) -> void:
	(_tracers.next() as Tracer).play(from, to, color, linger)

func spawn_impact(pos: Vector3, normal: Vector3, flesh: bool) -> void:
	(_impacts.next() as Impact).play(pos, normal, flesh)
	if not flesh:
		(_decals.next() as BulletDecal).place(pos, normal)

func pool_node_count() -> int:
	return get_child_count()

# -- event handlers -----------------------------------------------------------

func _on_explosion(pos: Vector3, radius: float, _owner_id: int) -> void:
	spawn_explosion(pos, radius)

func _on_fighter_damaged(_victim_id: int, _attacker_id: int, _amount: float, hit_pos: Vector3, _is_head: bool) -> void:
	spawn_impact(hit_pos, Vector3.UP, true)

func _on_weapon_fired(id: int, weapon_id: int, origin: Vector3, dir: Vector3) -> void:
	if not TRACER_COLORS.has(weapon_id):
		return
	var color := TRACER_COLORS[weapon_id] as Color
	var rail := weapon_id == RAIL_SLOT
	var pellets := SHOTGUN_VISUAL_PELLETS if weapon_id == SHOTGUN_SLOT else 1
	var space := get_world_3d().direct_space_state
	var exclude := _hitbox_rids(id)
	var right := dir.cross(Vector3.UP).normalized()
	var muzzle := origin + dir * 0.7 + right * 0.18 - Vector3.UP * 0.16
	for p in pellets:
		var d := dir if pellets == 1 else _spread(dir, SHOTGUN_SPREAD_DEG)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + d * TRACE_RANGE,
			WORLD_MASK if rail else (WORLD_MASK | HITBOX_MASK))
		query.collide_with_areas = true
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			spawn_tracer(muzzle, origin + d * TRACE_RANGE, color, RAIL_LINGER if rail else 0.0)
			continue
		var end := hit["position"] as Vector3
		spawn_tracer(muzzle, end, color, RAIL_LINGER if rail else 0.0)
		if not (hit["collider"] is Area3D):
			spawn_impact(end, hit["normal"] as Vector3, false)

func _on_grapple_attached(id: int, anchor: Vector3) -> void:
	var source := _fighter_node(id)
	if source == null:
		return
	if not _ropes.has(id):
		if _ropes.size() >= POOL_ROPES:
			return
		var rope := GrappleRope.new()
		add_child(rope)
		_ropes[id] = rope
	(_ropes[id] as GrappleRope).attach(source, anchor)

func _on_grapple_released(id: int) -> void:
	if _ropes.has(id):
		(_ropes[id] as GrappleRope).release()

# -- helpers -------------------------------------------------------------------

func _fill(ring: Ring, count: int, kind: GDScript) -> void:
	for i in count:
		var n := kind.new() as Node3D
		add_child(n)
		ring.items.append(n)

func _spread(dir: Vector3, deg: float) -> Vector3:
	var basis := FxUtil.basis_up(dir)
	var yaw := deg_to_rad(_rng.randf_range(-deg, deg))
	var pitch := deg_to_rad(_rng.randf_range(-deg, deg))
	return (dir + basis.x * tan(yaw) + basis.z * tan(pitch)).normalized()

func _fighter_node(id: int) -> Node3D:
	var mm := get_tree().get_first_node_in_group("match_manager")
	if mm != null and mm.has_method("get_fighter"):
		return mm.call("get_fighter", id) as Node3D
	return null

func _hitbox_rids(id: int) -> Array[RID]:
	var out: Array[RID] = []
	var f := _fighter_node(id)
	if f == null:
		return out
	for key: String in ["body_hitbox", "head_hitbox"]:
		var area := f.get(key) as CollisionObject3D
		if area != null:
			out.append(area.get_rid())
	return out
