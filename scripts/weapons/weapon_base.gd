class_name WeaponBase
extends RefCounted
## Runtime state and firing logic of one weapon (melee, hitscan, or projectile).
## WeaponInventory owns seven of these and feeds them the aim transform each shot.

signal fired(weapon_id: int, origin: Vector3, dir: Vector3)
signal tracer(from: Vector3, to: Vector3, color: Color, lifetime: float)
signal impact(pos: Vector3, normal: Vector3, on_fighter: bool)

const MAX_TRACE_STEPS: int = 12
const MUZZLE_CLEARANCE: float = 0.05

var def: WeaponDef
var ammo: int = 0
var cooldown: float = 0.0
var spread_deg: float = 0.0
var shots_fired: int = 0

# Context pushed by WeaponInventory.
var shooter: Node3D
var owner_id: int = -1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var damage_sink: Callable = Callable()
var projectile_parent: Node
var fire_rate_mult: float = 1.0
var unlimited_ammo: bool = false
var knockback_mult: float = 1.0

var _excludes: Array[RID] = []
var _melee_shape: SphereShape3D


func _init(weapon_def: WeaponDef) -> void:
	def = weapon_def
	ammo = weapon_def.ammo_start
	spread_deg = weapon_def.spread_min_deg
	_melee_shape = SphereShape3D.new()
	_melee_shape.radius = weapon_def.melee_range + weapon_def.melee_target_radius


func tick(dt: float) -> void:
	cooldown = maxf(cooldown - dt, -dt)
	if spread_deg > def.spread_min_deg:
		spread_deg = maxf(def.spread_min_deg, spread_deg - def.spread_recover_rate() * dt)


func fire_interval() -> float:
	return def.fire_interval / maxf(fire_rate_mult, 0.01)


func has_ammo() -> bool:
	return def.infinite_ammo or unlimited_ammo or ammo > 0


func is_ready() -> bool:
	return cooldown <= 0.0 and has_ammo()


## Rebuilds the cached shooter hitbox exclusion list (call if hitboxes are recreated).
func refresh_excludes() -> void:
	_excludes = WeaponUtils.collect_hitbox_rids(shooter) if shooter != null else ([] as Array[RID])


## Attempts one shot. `aim` is the camera transform (origin + facing); `muzzle` is the visual muzzle.
func try_fire(aim: Transform3D, muzzle: Vector3) -> bool:
	if shooter == null or not is_ready():
		return false
	if _excludes.is_empty():
		refresh_excludes()
	cooldown += fire_interval()
	if not def.infinite_ammo and not unlimited_ammo:
		ammo -= 1
	shots_fired += 1
	match def.fire_type:
		WeaponDef.FireType.MELEE:
			_fire_melee(aim)
		WeaponDef.FireType.HITSCAN:
			_fire_hitscan(aim, muzzle)
		WeaponDef.FireType.PROJECTILE:
			_fire_projectile(aim, muzzle)
	fired.emit(def.id, aim.origin, -aim.basis.z)
	return true


func _space() -> PhysicsDirectSpaceState3D:
	return shooter.get_world_3d().direct_space_state


func _make_info(amount: float, pos: Vector3, is_head: bool) -> DamageInfo:
	return DamageInfo.create(amount, owner_id, -1, def.id, pos, is_head)


# ---------------------------------------------------------------- hitscan

func _fire_hitscan(aim: Transform3D, muzzle: Vector3) -> void:
	for i in def.pellets:
		var dir: Vector3 = WeaponUtils.spread_dir(aim.basis, spread_deg, rng)
		_trace(aim.origin, dir, muzzle)
	spread_deg = minf(def.spread_max_deg, spread_deg + def.bloom_per_shot_deg)


func _trace(origin: Vector3, dir: Vector3, muzzle: Vector3) -> void:
	var space := _space()
	var excl: Array[RID] = []
	excl.append_array(_excludes)
	var mask: int = WeaponUtils.MASK_HITSCAN
	var end: Vector3 = origin + dir * def.max_range
	var far: Vector3 = end
	var hits: int = 0
	for step in MAX_TRACE_STEPS:
		var res: Dictionary = WeaponUtils.ray(space, origin, far, mask, excl)
		if res.is_empty():
			break
		var pos: Vector3 = res["position"]
		var collider := res["collider"] as Object
		var victim := WeaponUtils.hit_owner(collider)
		if victim == null or victim == shooter:
			end = pos
			impact.emit(pos, res["normal"] as Vector3, false)
			break
		var head_res: Dictionary = WeaponUtils.find_head_hit(space, origin, far, mask, excl, res)
		var is_head: bool = not head_res.is_empty()
		if is_head:
			pos = head_res["position"]
		var amount: float = def.damage * def.distance_mult(origin.distance_to(pos))
		if is_head:
			amount *= def.head_mult
		var info := _make_info(amount, pos, is_head)
		WeaponUtils.deliver_damage(shooter.get_tree(), victim, info, damage_sink)
		impact.emit(pos, -dir, true)
		hits += 1
		end = pos
		excl.append_array(WeaponUtils.collect_hitbox_rids(victim))
		if hits >= def.pierce_count:
			if def.pierce_count <= 1:
				break
			mask = WeaponUtils.MASK_WORLD # Limit reached: only find where the beam ends.
	tracer.emit(muzzle, end, def.tracer_color, def.tracer_lifetime)


# ---------------------------------------------------------------- melee

func _fire_melee(aim: Transform3D) -> void:
	var forward: Vector3 = -aim.basis.z
	if shooter is CharacterBody3D and def.lunge_speed > 0.0:
		(shooter as CharacterBody3D).velocity += forward * def.lunge_speed
	var space := _space()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _melee_shape
	query.transform = Transform3D(Basis.IDENTITY, aim.origin)
	query.collision_mask = WeaponUtils.MASK_HITBOXES
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = _excludes
	var target: Node = null
	var best_angle: float = INF
	var half_cone: float = def.melee_cone_deg * 0.5
	for result: Dictionary in space.intersect_shape(query, 32):
		var victim := WeaponUtils.hit_owner(result["collider"] as Object)
		if victim == null or victim == shooter:
			continue
		var to_center: Vector3 = WeaponUtils.center_of(victim) - aim.origin
		var dist: float = to_center.length()
		if dist - def.melee_target_radius > def.melee_range:
			continue
		var pad: float = rad_to_deg(asin(clampf(def.melee_target_radius / maxf(dist, def.melee_target_radius), 0.0, 1.0)))
		var angle: float = rad_to_deg(forward.angle_to(to_center))
		if angle - pad > half_cone or angle >= best_angle:
			continue
		if not WeaponUtils.ray(space, aim.origin, aim.origin + to_center, WeaponUtils.MASK_WORLD, _excludes).is_empty():
			continue
		target = victim
		best_angle = angle
	if target == null:
		return
	var center: Vector3 = WeaponUtils.center_of(target)
	var amount: float = def.damage
	if _is_backstab(target, aim.origin):
		amount *= def.backstab_mult
	WeaponUtils.deliver_damage(shooter.get_tree(), target, _make_info(amount, center, false), damage_sink)
	impact.emit(center, -forward, true)


func _is_backstab(victim: Node, attacker_pos: Vector3) -> bool:
	var facing: Vector3 = WeaponUtils.forward_of(victim)
	facing.y = 0.0
	var to_attacker: Vector3 = attacker_pos - (victim as Node3D).global_position
	to_attacker.y = 0.0
	if facing.length_squared() < 0.0001 or to_attacker.length_squared() < 0.0001:
		return false
	return rad_to_deg(facing.angle_to(to_attacker)) > def.backstab_angle_deg


# ---------------------------------------------------------------- projectiles

func _fire_projectile(aim: Transform3D, muzzle: Vector3) -> void:
	var forward: Vector3 = -aim.basis.z
	var far: Vector3 = aim.origin + forward * def.max_range
	var res: Dictionary = WeaponUtils.ray(_space(), aim.origin, far, WeaponUtils.MASK_HITSCAN, _excludes)
	var target: Vector3 = far if res.is_empty() else res["position"]
	var start: Vector3 = muzzle
	# Muzzle poking through a wall in front of the camera: spawn at the camera instead.
	if not res.is_empty() and aim.origin.distance_to(muzzle) > aim.origin.distance_to(target):
		start = aim.origin + forward * MUZZLE_CLEARANCE
	var dir: Vector3 = target - start
	dir = forward if dir.length_squared() < 1.0 else dir.normalized()
	var parent: Node = projectile_parent if projectile_parent != null else shooter.get_parent()
	var bolt := ProjectileRocket.launch(parent, def, shooter, owner_id, start, dir, damage_sink, _excludes)
	bolt.knockback_mult = knockback_mult
	tracer.emit(start, start + dir * 0.5, def.tracer_color, 0.03)
