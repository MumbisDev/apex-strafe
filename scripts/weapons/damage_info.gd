class_name DamageInfo
extends RefCounted
## One damage event. Weapons build these; MatchManager.auth_apply_damage consumes them.

## Id meaning "nobody" (world damage, unset victim).
const NO_ID: int = -1

var amount: float = 0.0
var attacker_id: int = NO_ID
var victim_id: int = NO_ID
var weapon_id: int = 0
var hit_pos: Vector3 = Vector3.ZERO
## Velocity change (m/s) the victim receives. Zero for plain bullets.
var impulse: Vector3 = Vector3.ZERO
var is_head: bool = false
var is_self: bool = false
var is_splash: bool = false


static func create(
		p_amount: float,
		p_attacker_id: int,
		p_victim_id: int,
		p_weapon_id: int,
		p_hit_pos: Vector3 = Vector3.ZERO,
		p_is_head: bool = false) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.attacker_id = p_attacker_id
	info.victim_id = p_victim_id
	info.weapon_id = p_weapon_id
	info.hit_pos = p_hit_pos
	info.is_head = p_is_head
	info.is_self = p_attacker_id != NO_ID and p_attacker_id == p_victim_id
	return info


func duplicate_info() -> DamageInfo:
	var copy := DamageInfo.new()
	copy.amount = amount
	copy.attacker_id = attacker_id
	copy.victim_id = victim_id
	copy.weapon_id = weapon_id
	copy.hit_pos = hit_pos
	copy.impulse = impulse
	copy.is_head = is_head
	copy.is_self = is_self
	copy.is_splash = is_splash
	return copy


## Returns a copy with amount multiplied (impulse untouched).
func scaled(multiplier: float) -> DamageInfo:
	var copy := duplicate_info()
	copy.amount = amount * multiplier
	return copy


func _to_string() -> String:
	return "DamageInfo(%.1f w%d %d->%d head=%s self=%s splash=%s)" % [
		amount, weapon_id, attacker_id, victim_id, str(is_head), str(is_self), str(is_splash)]
