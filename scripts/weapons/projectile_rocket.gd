class_name ProjectileRocket
extends Node3D
## Swept-ray projectile used for rockets (splash) and plasma bolts (direct only).
## Stepped each physics tick from the previous to the next position, so it never tunnels.

var def: WeaponDef
var shooter: Node3D
var owner_id: int = -1
var velocity: Vector3 = Vector3.ZERO
var damage_sink: Callable = Callable()
var knockback_mult: float = 1.0
var excludes: Array[RID] = []
var age: float = 0.0
var detonated: bool = false
## Set false to drive the projectile manually with advance(dt) (tests, replays).
var auto_step: bool = true


## Creates a projectile under `parent` heading along `dir` from `pos`.
static func launch(parent: Node, weapon_def: WeaponDef, p_shooter: Node3D, p_owner_id: int, pos: Vector3, dir: Vector3, sink: Callable, exclude: Array[RID]) -> ProjectileRocket:
	var bolt := ProjectileRocket.new()
	bolt.def = weapon_def
	bolt.shooter = p_shooter
	bolt.owner_id = p_owner_id
	bolt.velocity = dir.normalized() * weapon_def.projectile_speed
	bolt.damage_sink = sink
	bolt.excludes = exclude
	bolt.top_level = true
	bolt.name = "Projectile_%s" % weapon_def.key
	var host: Node = parent
	if host == null:
		host = p_shooter.get_tree().root
	host.add_child(bolt)
	bolt.global_position = pos
	return bolt


func _ready() -> void:
	top_level = true
	set_physics_process(auto_step)
	_build_visual()


func _physics_process(delta: float) -> void:
	advance(delta)


## Moves one step; detonates on world/hitbox contact or expires after its lifetime.
func advance(dt: float) -> void:
	if detonated:
		return
	age += dt
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * dt
	var space := get_world_3d().direct_space_state
	var res: Dictionary = WeaponUtils.ray(space, from, to, WeaponUtils.MASK_HITSCAN, excludes)
	if not res.is_empty():
		var pos: Vector3 = res["position"]
		global_position = pos
		_detonate(pos, res["normal"] as Vector3, WeaponUtils.hit_owner(res["collider"] as Object), res)
		return
	global_position = to
	if velocity.length_squared() > 0.0001:
		look_at(to + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)
	if age >= def.projectile_lifetime:
		detonated = true
		queue_free()


func _detonate(pos: Vector3, normal: Vector3, victim: Node, res: Dictionary) -> void:
	detonated = true
	var tree := get_tree()
	if def.splash_radius > 0.0:
		explode(self, pos + normal * 0.05, def, owner_id, victim, damage_sink, knockback_mult)
	elif victim != null and victim != shooter:
		var is_head: bool = WeaponUtils.hit_part(res["collider"] as Object) == WeaponUtils.PART_HEAD
		var info := DamageInfo.create(def.damage, owner_id, -1, def.id, pos, is_head)
		WeaponUtils.deliver_damage(tree, victim, info, damage_sink)
	queue_free()


## Applies direct damage to `direct_victim` plus linear-falloff splash to every fighter inside
## the radius that has line of sight to the blast. Impulse points from blast center to the victim.
static func explode(source: Node3D, pos: Vector3, weapon_def: WeaponDef, p_owner_id: int, direct_victim: Node, sink: Callable, p_knockback_mult: float = 1.0) -> void:
	var space := source.get_world_3d().direct_space_state
	var tree := source.get_tree()
	var shape := SphereShape3D.new()
	shape.radius = weapon_def.splash_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, pos)
	query.collision_mask = WeaponUtils.MASK_HITBOXES
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen: Dictionary = {}
	var no_excludes: Array[RID] = []
	for result: Dictionary in space.intersect_shape(query, 64):
		var victim := WeaponUtils.hit_owner(result["collider"] as Object)
		if victim == null or seen.has(victim.get_instance_id()):
			continue
		seen[victim.get_instance_id()] = true
		var to_center: Vector3 = WeaponUtils.center_of(victim) - pos
		var dist: float = to_center.length()
		if dist > weapon_def.splash_radius:
			continue
		var is_direct: bool = victim == direct_victim
		if not is_direct and not WeaponUtils.ray(space, pos, pos + to_center, WeaponUtils.MASK_WORLD, no_excludes).is_empty():
			continue
		var falloff: float = weapon_def.splash_mult(dist)
		var dir: Vector3 = to_center / dist if dist > 0.001 else Vector3.UP
		var info := DamageInfo.create(weapon_def.splash_damage * falloff, p_owner_id, WeaponUtils.owner_id(victim), weapon_def.id, pos)
		info.is_splash = not is_direct
		info.impulse = dir * weapon_def.knockback_speed * falloff * p_knockback_mult
		if is_direct:
			info.amount = weapon_def.damage
		if info.is_self:
			info.amount *= weapon_def.self_damage_mult
		WeaponUtils.deliver_damage(tree, victim, info, sink)
	WeaponUtils.emit_event(&"explosion", [pos, weapon_def.splash_radius, p_owner_id])


func _build_visual() -> void:
	var color: Color = def.tracer_color
	var mesh_instance := MeshInstance3D.new()
	if def.splash_radius > 0.0:
		var body := CapsuleMesh.new()
		body.radius = 0.09
		body.height = 0.55
		mesh_instance.mesh = body
		mesh_instance.rotation_degrees.x = 90.0
	else:
		var bolt := SphereMesh.new()
		bolt.radius = 0.12
		bolt.height = 0.24
		mesh_instance.mesh = bolt
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 1.5
	glow.omni_range = 4.0
	glow.shadow_enabled = false
	add_child(glow)
