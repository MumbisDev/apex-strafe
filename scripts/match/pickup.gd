class_name GamePickup
extends Area3D
## Arena pickup. Contested items use sky-drop or timed cage before they can be taken.

enum Kind {
	STIM, MEDKIT, MEGA_HEALTH, ARMOR_SHARD, ARMOR_PLATE,
	AMMO_BOX, WEAPON, POWERUP_OVERCHARGE, POWERUP_HASTE, BACKPACK
}
enum Delivery { GROUND, SKY_DROP, CAGED }

const SKY_HEIGHT: float = 14.0
const SKY_TIME: float = 1.6
const CAGE_TIME: float = 8.0

var kind: Kind = Kind.STIM
var delivery: Delivery = Delivery.GROUND
var weapon_id: int = 0
var pickup_id: int = 0
var respawn_time: float = 15.0
var available: bool = true
var locked: bool = false
var respawn_left: float = 0.0
var backpack_weapon: int = 0
var backpack_ammo: int = 0
var backpack_life: float = 20.0
var _mesh: MeshInstance3D
var _ghost: MeshInstance3D
var _ring: MeshInstance3D
var _cage: MeshInstance3D
var _beacon: MeshInstance3D
var _bob_t: float = 0.0
var _lock_left: float = 0.0
var _lock_total: float = 0.0
var _home: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body)
	_build_visual()
	_begin_delivery()
	add_to_group("pickups")


func configure(
		p_kind: Kind, id: int, pos: Vector3, wpn: int = 0,
		custom_respawn: float = -1.0, p_delivery: Delivery = Delivery.GROUND) -> void:
	kind = p_kind
	pickup_id = id
	weapon_id = wpn
	delivery = p_delivery
	_home = pos
	if is_inside_tree():
		global_position = pos
	else:
		position = pos
	respawn_time = custom_respawn if custom_respawn > 0.0 else _default_respawn(p_kind)


func _default_respawn(k: Kind) -> float:
	match k:
		Kind.STIM, Kind.ARMOR_SHARD: return 15.0
		Kind.MEDKIT, Kind.ARMOR_PLATE: return 30.0
		Kind.MEGA_HEALTH: return 60.0
		Kind.AMMO_BOX: return 20.0
		Kind.WEAPON:
			if weapon_id == WeaponLibrary.SLOT_PORTAL:
				return 90.0
			return 30.0 if weapon_id == 6 or weapon_id == 7 else 25.0
		Kind.POWERUP_OVERCHARGE: return 120.0
		Kind.POWERUP_HASTE: return 90.0
		Kind.BACKPACK: return 0.0
	return 20.0


func _begin_delivery() -> void:
	match delivery:
		Delivery.SKY_DROP:
			locked = true
			_lock_total = SKY_TIME
			_lock_left = SKY_TIME
			if _mesh:
				_mesh.position.y = SKY_HEIGHT
			if _beacon:
				_beacon.visible = true
			if _cage:
				_cage.visible = false
		Delivery.CAGED:
			locked = true
			_lock_total = CAGE_TIME
			_lock_left = CAGE_TIME
			if _cage:
				_cage.visible = true
			if _beacon:
				_beacon.visible = false
		_:
			locked = false
			_lock_left = 0.0
			if _cage:
				_cage.visible = false
			if _beacon:
				_beacon.visible = false


func _physics_process(dt: float) -> void:
	_bob_t += dt
	if locked:
		_lock_left -= dt
		_update_lock_visual(dt)
		if _lock_left <= 0.0:
			locked = false
			if _mesh:
				_mesh.position.y = 0.5
			if _cage:
				_cage.visible = false
			if _beacon:
				_beacon.visible = false
			Audio.play_sfx("pickup_respawn", global_position)
	elif _mesh and available:
		_mesh.rotation.y += dt * 2.0
		_mesh.position.y = 0.5 + sin(_bob_t * 2.0) * 0.1
	if not available and kind != Kind.BACKPACK:
		respawn_left -= dt
		if _ring:
			var frac := 1.0 - clampf(respawn_left / respawn_time, 0.0, 1.0)
			_ring.scale = Vector3.ONE * (0.5 + frac)
		if respawn_left <= 0.0:
			_set_available(true)
			_begin_delivery()
			Events.pickup_spawned.emit(_kind_name(), global_position)
			Audio.play_sfx("pickup_respawn", global_position)
	if kind == Kind.BACKPACK:
		backpack_life -= dt
		if backpack_life <= 0.0:
			queue_free()


func _update_lock_visual(dt: float) -> void:
	var t := 1.0 - clampf(_lock_left / maxf(_lock_total, 0.001), 0.0, 1.0)
	if delivery == Delivery.SKY_DROP and _mesh:
		_mesh.position.y = lerpf(SKY_HEIGHT, 0.5, t)
		_mesh.rotation.y += 0.05
	if delivery == Delivery.CAGED and _cage:
		_cage.scale = Vector3.ONE * (1.0 - t * 0.15)
		_cage.rotation.y += dt * 0.8


func _on_body(body: Node) -> void:
	if not available or locked:
		return
	if body is Fighter:
		var scene := get_tree().current_scene
		if scene and scene.has_method("try_collect_pickup"):
			scene.call("try_collect_pickup", body as Fighter, self)


func try_apply(f: Fighter) -> bool:
	if not available or locked:
		return false
	var applied := false
	match kind:
		Kind.STIM:
			applied = f.health.heal(25.0, 100.0) > 0.0
		Kind.MEDKIT:
			applied = f.health.heal(50.0, 100.0) > 0.0
		Kind.MEGA_HEALTH:
			applied = f.health.heal(100.0, 200.0) > 0.0
			applied = true
		Kind.ARMOR_SHARD:
			applied = f.health.add_armor(25.0) > 0.0
		Kind.ARMOR_PLATE:
			applied = f.health.add_armor(50.0) > 0.0
		Kind.AMMO_BOX:
			if f.inventory is WeaponInventory:
				applied = (f.inventory as WeaponInventory).give_ammo_box()
			elif f.inventory and f.inventory.has_method("give_ammo_box"):
				applied = bool(f.inventory.call("give_ammo_box"))
		Kind.WEAPON:
			if f.inventory is WeaponInventory:
				applied = (f.inventory as WeaponInventory).give_weapon(weapon_id, true)
			elif f.inventory and f.inventory.has_method("give_weapon"):
				applied = bool(f.inventory.call("give_weapon", weapon_id, true))
			else:
				applied = true
		Kind.POWERUP_OVERCHARGE:
			f.health.overcharge_t = 20.0
			applied = true
			Events.powerup_announced.emit("%s got OVERCHARGE" % f.display_name)
		Kind.POWERUP_HASTE:
			f.health.haste_t = 20.0
			applied = true
			Events.powerup_announced.emit("%s got HASTE" % f.display_name)
		Kind.BACKPACK:
			if f.inventory is WeaponInventory:
				var inv := f.inventory as WeaponInventory
				inv.give_weapon(backpack_weapon, false)
				inv.add_ammo(backpack_weapon, backpack_ammo)
			applied = true
	if applied:
		Events.pickup_collected.emit(f.id, _kind_name(), global_position)
		_play_pickup_sfx()
		if kind == Kind.BACKPACK:
			queue_free()
		else:
			_set_available(false)
			respawn_left = respawn_time * (Game.match_config.pickup_respawn_scale if Game else 1.0)
	return applied


func _set_available(on: bool) -> void:
	available = on
	if _mesh:
		_mesh.visible = on
	if _ghost:
		_ghost.visible = not on
	if _ring:
		_ring.visible = not on
	if not on:
		locked = false
		if _cage:
			_cage.visible = false
		if _beacon:
			_beacon.visible = false


func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.7
	col.shape = sp
	add_child(col)
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	match kind:
		Kind.STIM, Kind.MEDKIT, Kind.MEGA_HEALTH:
			mat.albedo_color = Color(0.2, 0.9, 0.3)
			mat.emission = mat.albedo_color
			_mesh.mesh = _cross_mesh(kind == Kind.STIM)
		Kind.ARMOR_SHARD, Kind.ARMOR_PLATE:
			mat.albedo_color = Color(0.2, 0.4, 1.0)
			mat.emission = mat.albedo_color
			var box := BoxMesh.new()
			box.size = Vector3(0.4, 0.5, 0.15) if kind == Kind.ARMOR_SHARD else Vector3(0.6, 0.7, 0.2)
			_mesh.mesh = box
		Kind.AMMO_BOX:
			mat.albedo_color = Color(0.95, 0.85, 0.2)
			mat.emission = mat.albedo_color
			var c := BoxMesh.new()
			c.size = Vector3(0.5, 0.4, 0.5)
			_mesh.mesh = c
		Kind.WEAPON:
			mat.albedo_color = Color(0.2, 0.55, 1.0) if weapon_id == WeaponLibrary.SLOT_PORTAL \
				else Color(1.0, 0.45, 0.1)
			mat.emission = mat.albedo_color
			_mesh.mesh = _weapon_pickup_mesh(weapon_id)
		Kind.POWERUP_OVERCHARGE, Kind.POWERUP_HASTE:
			mat.albedo_color = Color(0.7, 0.2, 1.0) if kind == Kind.POWERUP_OVERCHARGE else Color(0.2, 0.9, 1.0)
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 2.0
			var oct := SphereMesh.new()
			oct.radius = 0.45
			oct.height = 0.9
			_mesh.mesh = oct
		Kind.BACKPACK:
			mat.albedo_color = Color(0.6, 0.4, 0.2)
			var b := BoxMesh.new()
			b.size = Vector3(0.5, 0.5, 0.35)
			_mesh.mesh = b
	_mesh.material_override = mat
	_mesh.position.y = 0.5
	add_child(_mesh)
	_ghost = _mesh.duplicate() as MeshInstance3D
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1, 1, 1, 0.15)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.material_override = gm
	_ghost.visible = false
	add_child(_ghost)
	_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.55
	tor.outer_radius = 0.7
	_ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.albedo_color = mat.albedo_color
	rm.emission_enabled = true
	rm.emission = mat.albedo_color
	_ring.material_override = rm
	_ring.visible = false
	_ring.position.y = 0.2
	add_child(_ring)
	_build_cage(mat.albedo_color)
	_build_beacon(mat.albedo_color)


func _build_cage(color: Color) -> void:
	_cage = MeshInstance3D.new()
	var cage_mesh := BoxMesh.new()
	cage_mesh.size = Vector3(1.4, 1.8, 1.4)
	_cage.mesh = cage_mesh
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(color.r, color.g, color.b, 0.35)
	cm.emission_enabled = true
	cm.emission = color
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cage.material_override = cm
	_cage.position.y = 0.9
	_cage.visible = false
	add_child(_cage)


func _build_beacon(color: Color) -> void:
	_beacon = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = SKY_HEIGHT
	_beacon.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(color.r, color.g, color.b, 0.45)
	bm.emission_enabled = true
	bm.emission = color
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon.material_override = bm
	_beacon.position.y = SKY_HEIGHT * 0.5
	_beacon.visible = false
	add_child(_beacon)


func _cross_mesh(small: bool) -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.1) if small else Vector3(0.7, 0.7, 0.12)
	return box


func _weapon_pickup_mesh(slot: int) -> Mesh:
	match slot:
		WeaponLibrary.SLOT_BLADE:
			var tip := PrismMesh.new()
			tip.size = Vector3(0.12, 0.55, 0.04)
			return tip
		WeaponLibrary.SLOT_ROCKET:
			var tube := CylinderMesh.new()
			tube.top_radius = 0.12
			tube.bottom_radius = 0.12
			tube.height = 0.7
			return tube
		WeaponLibrary.SLOT_PORTAL:
			var dish := CylinderMesh.new()
			dish.top_radius = 0.28
			dish.bottom_radius = 0.28
			dish.height = 0.12
			return dish
		WeaponLibrary.SLOT_RAIL:
			var rail := BoxMesh.new()
			rail.size = Vector3(0.1, 0.1, 0.9)
			return rail
		_:
			var gun := BoxMesh.new()
			gun.size = Vector3(0.16, 0.22, 0.55)
			return gun


func _kind_name() -> String:
	return Kind.keys()[kind]


func _play_pickup_sfx() -> void:
	match kind:
		Kind.STIM, Kind.MEDKIT, Kind.MEGA_HEALTH:
			Audio.play_sfx("pickup_health", global_position)
		Kind.ARMOR_SHARD, Kind.ARMOR_PLATE:
			Audio.play_sfx("pickup_armor", global_position)
		Kind.AMMO_BOX:
			Audio.play_sfx("pickup_ammo", global_position)
		Kind.WEAPON, Kind.BACKPACK:
			Audio.play_sfx("pickup_weapon", global_position)
		_:
			Audio.play_sfx("powerup_pickup", global_position)
