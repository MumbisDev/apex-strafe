class_name WeaponLibrary
extends RefCounted
## Builds WeaponDefs (GDD §7 + portal special). The only place weapon numbers live.

const SLOT_BLADE: int = 1
const SLOT_PISTOL: int = 2
const SLOT_SMG: int = 3
const SLOT_SHOTGUN: int = 4
const SLOT_PLASMA: int = 5
const SLOT_ROCKET: int = 6
const SLOT_RAIL: int = 7
const SLOT_PORTAL: int = 8
const SLOT_COUNT: int = 8

static var _defs: Array[WeaponDef] = []


## Returns the def for slot 1..SLOT_COUNT (null when out of range).
static func get_def(slot: int) -> WeaponDef:
	_ensure_built()
	if slot < 1 or slot > SLOT_COUNT:
		return null
	return _defs[slot - 1]


static func all() -> Array[WeaponDef]:
	_ensure_built()
	return _defs


static func _ensure_built() -> void:
	if _defs.size() == SLOT_COUNT:
		return
	_defs = [
		_blade(), _pistol(), _smg(), _shotgun(), _plasma(), _rocket(), _rail(), _portal(),
	]


static func _base(slot: int, key: StringName, title: String, type: WeaponDef.FireType) -> WeaponDef:
	var d := WeaponDef.new()
	d.id = slot
	d.key = key
	d.display_name = title
	d.fire_type = type
	return d


static func _blade() -> WeaponDef:
	var d := _base(SLOT_BLADE, &"blade", "Blade", WeaponDef.FireType.MELEE)
	d.is_starter = true
	d.infinite_ammo = true
	d.damage = 55.0
	d.backstab_mult = 2.0
	d.backstab_angle_deg = 120.0
	d.fire_interval = 0.55
	d.melee_range = 2.4
	d.melee_cone_deg = 60.0
	d.lunge_speed = 6.0
	d.model_color = Color(0.75, 0.78, 0.85)
	d.tracer_color = Color(0.8, 0.9, 1.0)
	return d


static func _pistol() -> WeaponDef:
	var d := _base(SLOT_PISTOL, &"arc_pistol", "Arc Pistol", WeaponDef.FireType.HITSCAN)
	d.is_starter = false
	d.infinite_ammo = true
	d.damage = 20.0
	d.head_mult = 1.5
	d.fire_interval = 0.28
	d.spread_min_deg = 0.2
	d.spread_max_deg = 0.2
	d.kick_pitch_deg = 0.6
	d.tracer_color = Color(0.1, 0.9, 1.0)
	d.tracer_lifetime = 0.12
	d.model_color = Color(0.2, 0.25, 0.32)
	return d


static func _smg() -> WeaponDef:
	var d := _base(SLOT_SMG, &"smg", "SMG", WeaponDef.FireType.HITSCAN)
	d.damage = 9.0
	d.head_mult = 1.4
	d.fire_interval = 0.075
	d.auto_fire = true
	d.ammo_start = 60
	d.ammo_max = 200
	d.spread_min_deg = 0.3
	d.spread_max_deg = 3.5
	d.bloom_per_shot_deg = 0.35
	d.spread_recover_time = 0.25
	d.kick_pitch_deg = 0.35
	d.kick_recovery_time = 0.1
	d.tracer_color = Color(1.0, 0.9, 0.2)
	d.tracer_lifetime = 0.08
	d.model_color = Color(0.25, 0.27, 0.3)
	return d


static func _shotgun() -> WeaponDef:
	var d := _base(SLOT_SHOTGUN, &"shotgun", "Shotgun", WeaponDef.FireType.HITSCAN)
	d.damage = 9.0
	d.pellets = 10
	d.head_mult = 1.5
	d.fire_interval = 0.85
	d.ammo_start = 10
	d.ammo_max = 24
	d.spread_min_deg = 4.5
	d.spread_max_deg = 4.5
	d.falloff_start = 15.0
	d.falloff_end = 35.0
	d.falloff_min_mult = 0.4
	d.kick_pitch_deg = 2.5
	d.kick_recovery_time = 0.25
	d.tracer_color = Color(1.0, 1.0, 1.0)
	d.tracer_lifetime = 0.08
	d.model_color = Color(0.4, 0.3, 0.22)
	return d


static func _plasma() -> WeaponDef:
	var d := _base(SLOT_PLASMA, &"plasma_rifle", "Plasma Rifle", WeaponDef.FireType.PROJECTILE)
	d.damage = 14.0
	d.fire_interval = 0.11
	d.auto_fire = true
	d.ammo_start = 50
	d.ammo_max = 200
	d.projectile_speed = 55.0
	d.projectile_lifetime = 5.0
	d.kick_pitch_deg = 0.25
	d.tracer_color = Color(0.35, 1.0, 0.55)
	d.model_color = Color(0.2, 0.3, 0.3)
	return d


static func _rocket() -> WeaponDef:
	var d := _base(SLOT_ROCKET, &"rocket_launcher", "Rocket Launcher", WeaponDef.FireType.PROJECTILE)
	d.damage = 85.0
	d.fire_interval = 0.85
	d.ammo_start = 5
	d.ammo_max = 20
	d.projectile_speed = 32.0
	d.projectile_lifetime = 6.0
	d.splash_damage = 80.0
	d.splash_radius = 4.5
	d.splash_min_mult = 0.15
	d.self_damage_mult = 0.35
	d.knockback_speed = 16.0
	d.kick_pitch_deg = 3.0
	d.kick_recovery_time = 0.3
	d.tracer_color = Color(1.0, 0.55, 0.15)
	d.model_color = Color(0.35, 0.38, 0.3)
	return d


static func _rail() -> WeaponDef:
	var d := _base(SLOT_RAIL, &"railgun", "Railgun", WeaponDef.FireType.HITSCAN)
	d.damage = 85.0
	d.head_mult = 1.5
	d.fire_interval = 1.4
	d.ammo_start = 4
	d.ammo_max = 12
	d.max_range = 500.0
	d.pierce_count = 3
	d.zoom_fov = 40.0
	d.kick_pitch_deg = 2.0
	d.kick_recovery_time = 0.3
	d.tracer_color = Color(1.0, 0.2, 0.9)
	d.tracer_lifetime = 0.8
	d.model_color = Color(0.3, 0.2, 0.35)
	return d


static func _portal() -> WeaponDef:
	var d := _base(SLOT_PORTAL, &"portal_gun", "Portal Gun", WeaponDef.FireType.PORTAL)
	d.damage = 0.0
	d.fire_interval = 0.35
	d.ammo_start = 24
	d.ammo_max = 24
	d.max_range = 60.0
	d.kick_pitch_deg = 0.4
	d.tracer_color = Color(0.2, 0.55, 1.0)
	d.tracer_lifetime = 0.2
	d.model_color = Color(0.15, 0.35, 0.55)
	return d
