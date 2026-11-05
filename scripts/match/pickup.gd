class_name GamePickup
extends Area3D

enum Kind {
	STIM, MEDKIT, MEGA_HEALTH, ARMOR_SHARD, ARMOR_PLATE,
	AMMO_BOX, WEAPON, POWERUP_OVERCHARGE, POWERUP_HASTE, BACKPACK
}

var kind: Kind = Kind.STIM
var weapon_id: int = 0
var pickup_id: int = 0
var respawn_time: float = 15.0
var available: bool = true
var respawn_left: float = 0.0
var backpack_weapon: int = 0
var backpack_ammo: int = 0
var backpack_life: float = 20.0
var _mesh: MeshInstance3D
var _ghost: MeshInstance3D
var _ring: MeshInstance3D
var _bob_t: float = 0.0

func _ready() -> void:
	collision_layer = 8 ## pickups layer 4
	collision_mask = 2 ## fighters
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body)
	_build_visual()
	add_to_group("pickups")

func configure(p_kind: Kind, id: int, pos: Vector3, wpn: int = 0, custom_respawn: float = -1.0) -> void:
	kind = p_kind
	pickup_id = id
	weapon_id = wpn
	global_position = pos
	respawn_time = custom_respawn if custom_respawn > 0.0 else _default_respawn(p_kind)

func _default_respawn(k: Kind) -> float:
	match k:
		Kind.STIM, Kind.ARMOR_SHARD: return 15.0
		Kind.MEDKIT, Kind.ARMOR_PLATE: return 30.0
		Kind.MEGA_HEALTH: return 60.0
		Kind.AMMO_BOX: return 20.0
		Kind.WEAPON:
			return 30.0 if weapon_id == 6 or weapon_id == 7 else 25.0
		Kind.POWERUP_OVERCHARGE: return 120.0
		Kind.POWERUP_HASTE: return 90.0
		Kind.BACKPACK: return 0.0
	return 20.0

func _physics_process(dt: float) -> void:
	_bob_t += dt
	if _mesh and available:
		_mesh.rotation.y += dt * 2.0
		_mesh.position.y = 0.5 + sin(_bob_t * 2.0) * 0.1
	if not available and kind != Kind.BACKPACK:
		respawn_left -= dt
		if _ring:
			var frac := 1.0 - clampf(respawn_left / respawn_time, 0.0, 1.0)
			_ring.scale = Vector3(1, 1, 1) * (0.5 + frac)
		if respawn_left <= 0.0:
			_set_available(true)
			Events.pickup_spawned.emit(_kind_name(), global_position)
			Audio.play_sfx("pickup_respawn", global_position)
	if kind == Kind.BACKPACK:
		backpack_life -= dt
		if backpack_life <= 0.0:
			queue_free()

func _on_body(body: Node) -> void:
	if not available:
		return
	if body is Fighter:
		var mm := get_tree().get_first_node_in_group("match_manager")
		if mm and mm.has_method("auth_collect_pickup"):
			# Prefer scene-level handler
			var scene := get_tree().current_scene
			if scene and scene.has_method("try_collect_pickup"):
				scene.call("try_collect_pickup", body as Fighter, self)

func try_apply(f: Fighter) -> bool:
	if not available:
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
			mat.albedo_color = Color(1.0, 0.45, 0.1)
			mat.emission = mat.albedo_color
			var w := BoxMesh.new()
			w.size = Vector3(0.2, 0.2, 0.8)
			_mesh.mesh = w
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

func _cross_mesh(small: bool) -> Mesh:
	# Approximate with box
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.1) if small else Vector3(0.7, 0.7, 0.12)
	return box

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
