class_name HealthComponent
extends RefCounted

var health: float = 100.0
var armor: float = 0.0
var max_health: float = 100.0
var max_armor: float = 100.0
var invulnerable: bool = false
var spawn_protect_t: float = 0.0
var overcharge_t: float = 0.0
var haste_t: float = 0.0
var last_attacker_id: int = -1
var last_attacker_time: float = -999.0
var alive: bool = true

const ARMOR_ABSORB := 0.66

func reset() -> void:
	health = 100.0
	armor = 0.0
	max_health = 100.0
	invulnerable = false
	spawn_protect_t = 0.0
	overcharge_t = 0.0
	haste_t = 0.0
	alive = true
	last_attacker_id = -1

func tick(dt: float) -> void:
	if spawn_protect_t > 0.0:
		spawn_protect_t = maxf(0.0, spawn_protect_t - dt)
		if spawn_protect_t <= 0.0:
			invulnerable = false
	if overcharge_t > 0.0:
		overcharge_t = maxf(0.0, overcharge_t - dt)
	if haste_t > 0.0:
		haste_t = maxf(0.0, haste_t - dt)
	if health > 100.0:
		health = maxf(100.0, health - 1.0 * dt)

func apply_damage(info: DamageInfo) -> float:
	if not alive or invulnerable:
		return 0.0
	var amount := info.amount
	if info.is_self:
		amount *= 0.35 ## rocket self factor applied by caller usually; keep for safety if flagged
	# Armor absorbs 66% until armor depleted
	var absorbed := minf(armor, amount * ARMOR_ABSORB)
	# GDD: armor absorbs 66% of damage until armor reaches 0; absorbed subtracted from armor
	# Example: 100 dmg 50 armor -> armor 0, health loses 50 (absorbed 50)
	# Example: 100 dmg 100 armor -> armor 34, health loses 34
	var armor_takes := minf(armor, amount * ARMOR_ABSORB)
	armor -= armor_takes
	var health_damage := amount - armor_takes
	health = maxf(0.0, health - health_damage)
	if not info.is_self:
		last_attacker_id = info.attacker_id
		last_attacker_time = Time.get_ticks_msec() / 1000.0
	if health <= 0.0:
		alive = false
	return health_damage

func heal(amount: float, cap: float = 100.0) -> float:
	var before := health
	health = minf(cap, health + amount)
	max_health = maxf(max_health, cap)
	return health - before

func add_armor(amount: float) -> float:
	var before := armor
	armor = minf(max_armor, armor + amount)
	return armor - before

func begin_spawn_protect(duration: float = 2.0) -> void:
	spawn_protect_t = duration
	invulnerable = true

func end_spawn_protect_on_fire(min_elapsed: float = 0.5) -> void:
	if spawn_protect_t > 0.0 and (2.0 - spawn_protect_t) >= min_elapsed:
		spawn_protect_t = 0.0
		invulnerable = false
