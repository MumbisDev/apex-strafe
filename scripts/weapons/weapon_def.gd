class_name WeaponDef
extends Resource
## Pure data for one weapon. All numbers come from WeaponLibrary (GDD section 7).

enum FireType { MELEE, HITSCAN, PROJECTILE, PORTAL }

@export_group("Identity")
@export var id: int = 0 ## Slot 1..8; also used as weapon_id in events and DamageInfo.
@export var key: StringName = &""
@export var display_name: String = ""
@export var fire_type: FireType = FireType.HITSCAN
@export var is_starter: bool = false

@export_group("Damage")
@export var damage: float = 10.0 ## Per hit / per pellet / direct projectile hit.
@export var head_mult: float = 1.0
@export var max_range: float = 200.0
@export var pellets: int = 1
@export var pierce_count: int = 1 ## Fighters a single shot may damage.
@export var falloff_start: float = 0.0 ## 0 disables distance falloff.
@export var falloff_end: float = 0.0
@export var falloff_min_mult: float = 1.0

@export_group("Rate and ammo")
@export var fire_interval: float = 0.5
@export var auto_fire: bool = false
@export var infinite_ammo: bool = false
@export var ammo_start: int = 0
@export var ammo_max: int = 0
@export var switch_time: float = 0.25

@export_group("Spread")
@export var spread_min_deg: float = 0.0
@export var spread_max_deg: float = 0.0
@export var bloom_per_shot_deg: float = 0.0
@export var spread_recover_time: float = 0.25 ## Seconds to fall from max back to min.

@export_group("Melee")
@export var melee_range: float = 2.4
@export var melee_cone_deg: float = 60.0
@export var melee_target_radius: float = 0.4
@export var lunge_speed: float = 0.0
@export var backstab_mult: float = 1.0
@export var backstab_angle_deg: float = 120.0

@export_group("Projectile")
@export var projectile_speed: float = 0.0
@export var projectile_lifetime: float = 5.0
@export var splash_damage: float = 0.0
@export var splash_radius: float = 0.0 ## 0 means no explosion.
@export var splash_min_mult: float = 0.15
@export var self_damage_mult: float = 0.35
@export var knockback_speed: float = 0.0 ## Impulse magnitude at the blast center.

@export_group("Handling and presentation")
@export var zoom_fov: float = 0.0 ## > 0: alt fire zooms to this FOV.
@export var kick_pitch_deg: float = 0.0
@export var kick_recovery_time: float = 0.12
@export var tracer_color: Color = Color.WHITE
@export var tracer_lifetime: float = 0.1
@export var model_color: Color = Color(0.2, 0.2, 0.25)


func is_melee() -> bool:
	return fire_type == FireType.MELEE


func is_hitscan() -> bool:
	return fire_type == FireType.HITSCAN


func is_projectile() -> bool:
	return fire_type == FireType.PROJECTILE


## Damage multiplier for a hit at the given distance (1.0 inside falloff_start).
func distance_mult(distance: float) -> float:
	if falloff_end <= falloff_start or distance <= falloff_start:
		return 1.0
	var t: float = clampf((distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	return lerpf(1.0, falloff_min_mult, t)


## Splash damage multiplier at a distance from the blast center (linear to splash_min_mult).
func splash_mult(distance: float) -> float:
	if splash_radius <= 0.0:
		return 0.0
	return lerpf(1.0, splash_min_mult, clampf(distance / splash_radius, 0.0, 1.0))


## Degrees of spread recovered per second.
func spread_recover_rate() -> float:
	if spread_recover_time <= 0.0:
		return spread_max_deg - spread_min_deg
	return (spread_max_deg - spread_min_deg) / spread_recover_time
