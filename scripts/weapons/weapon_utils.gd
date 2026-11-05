class_name WeaponUtils
extends RefCounted
## Shared static helpers for weapons and projectiles: physics masks, hitbox lookup,
## spread sampling and damage routing. Keeps weapon_base.gd and projectile_rocket.gd small.

## Physics masks (bit values) for layers 1 world, 5 hitboxes.
const MASK_WORLD: int = 1
const MASK_HITBOXES: int = 16
const MASK_HITSCAN: int = 17

## Hitbox Area3D contract: meta "fighter" -> owning Node (falls back to parent),
## meta "part" -> "head" or "body". Owners expose `id: int` and optionally
## `take_damage(info) -> bool` and `get_center_position() -> Vector3`.
const OWNER_META: StringName = &"fighter"
const PART_META: StringName = &"part"
const PART_HEAD: StringName = &"head"
const GROUP_MATCH_MANAGER: StringName = &"match_manager"
const GROUP_DUMMY: StringName = &"target_dummy"
const BODY_CENTER_HEIGHT: float = 0.9


static func get_autoload(autoload_name: StringName) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(autoload_name)))


## Emits a signal on the Events autoload when it exists (safe in tests without autoloads).
static func emit_event(signal_name: StringName, args: Array = []) -> void:
	var events := get_autoload(&"Events")
	if events == null or not events.has_signal(signal_name):
		return
	events.callv(&"emit_signal", [signal_name] + args)


static func find_match_manager(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var manager: Node = tree.get_first_node_in_group(GROUP_MATCH_MANAGER)
	if manager != null and manager.has_method(&"auth_apply_damage"):
		return manager
	return null


static func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return space.intersect_ray(query)


## Owner node of a hitbox collider, or null for world geometry.
static func hit_owner(collider: Object) -> Node:
	var node := collider as Node
	if node == null:
		return null
	if node.has_meta(OWNER_META):
		return node.get_meta(OWNER_META) as Node
	var area := node as Area3D
	if area != null and (area.collision_layer & MASK_HITBOXES) != 0:
		return area.get_parent()
	return null


static func hit_part(collider: Object) -> StringName:
	var node := collider as Node
	if node != null and node.has_meta(PART_META):
		return StringName(String(node.get_meta(PART_META)))
	return &"body"


static func owner_id(node: Node) -> int:
	if node == null:
		return -1
	return int(node.get("id"))


static func center_of(node: Node) -> Vector3:
	if node.has_method(&"get_center_position"):
		return node.call(&"get_center_position") as Vector3
	var spatial := node as Node3D
	if spatial == null:
		return Vector3.ZERO
	return spatial.global_position + Vector3.UP * BODY_CENTER_HEIGHT


static func forward_of(node: Node) -> Vector3:
	var spatial := node as Node3D
	if spatial == null:
		return Vector3.FORWARD
	return -spatial.global_transform.basis.z


## RIDs of every hitbox Area3D under root (used to exclude a shooter or a pierced fighter).
static func collect_hitbox_rids(root: Node) -> Array[RID]:
	var out: Array[RID] = []
	_collect_rids(root, out)
	return out


static func _collect_rids(node: Node, out: Array[RID]) -> void:
	var area := node as Area3D
	if area != null and (area.collision_layer & MASK_HITBOXES) != 0:
		out.append(area.get_rid())
	for child: Node in node.get_children():
		_collect_rids(child, out)


## Head volumes sit inside the body capsule, so a ray usually reports the body first.
## Re-cast with the body excluded: if the same owner's head is next, it is a headshot.
## Returns the head hit dictionary, or an empty one for a body hit.
static func find_head_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array[RID], hit: Dictionary) -> Dictionary:
	var collider := hit["collider"] as Object
	if hit_part(collider) == PART_HEAD:
		return hit
	var excl: Array[RID] = []
	excl.append_array(exclude)
	excl.append(hit["rid"] as RID)
	var second := ray(space, from, to, mask, excl)
	if second.is_empty():
		return {}
	var other := second["collider"] as Object
	if hit_owner(other) == hit_owner(collider) and hit_part(other) == PART_HEAD:
		return second
	return {}


## Uniform random point on a disc of the given half-angle, as a unit direction.
static func spread_dir(aim_basis: Basis, spread_deg: float, rng: RandomNumberGenerator) -> Vector3:
	var forward: Vector3 = -aim_basis.z
	if spread_deg <= 0.0:
		return forward
	var angle: float = rng.randf() * TAU
	var radius: float = sqrt(rng.randf()) * tan(deg_to_rad(spread_deg))
	return (forward + aim_basis.x * cos(angle) * radius + aim_basis.y * sin(angle) * radius).normalized()


## Routes damage: explicit sink Callable (victim_id, info) -> MatchManager.auth_apply_damage
## (node in group "match_manager") -> direct victim.take_damage for practice dummies.
static func deliver_damage(tree: SceneTree, victim: Node, info: DamageInfo, sink: Callable) -> void:
	info.victim_id = owner_id(victim)
	info.is_self = info.attacker_id != DamageInfo.NO_ID and info.attacker_id == info.victim_id
	if sink.is_valid():
		sink.call(info.victim_id, info)
		return
	var manager := find_match_manager(tree)
	if manager != null and not victim.is_in_group(GROUP_DUMMY):
		manager.call(&"auth_apply_damage", info.victim_id, info)
		return
	if victim.has_method(&"take_damage"):
		var died: bool = victim.call(&"take_damage", info)
		if info.attacker_id != DamageInfo.NO_ID and not info.is_self:
			emit_event(&"hit_confirmed", [info.attacker_id, died, info.is_head])
