class_name BotCombat
extends RefCounted
## Fight movement and fire discipline. Outputs local-space move input (x strafe, y forward).

const STRAFE_MIN := 0.4
const STRAFE_MAX := 1.0
const BURST_MIN := 0.3
const BURST_MAX := 0.8
const PAUSE_MIN := 0.2
const PAUSE_MAX := 0.5
const SWITCH_COOLDOWN := 0.8
const JUMP_DODGE_CHANCE := 0.25
const SLIDE_STRAFE_CHANCE := 0.3
const SLIDE_MIN_SPEED := 6.5

var profile: BotProfile
var move: Vector2 = Vector2.ZERO
var jump: bool = false ## one-tick
var slide: bool = false ## one-tick
var fire: bool = false
var weapon_select: int = 0 ## 0 = keep current

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _strafe_sign: float = 1.0
var _strafe_t: float = 0.0
var _burst_t: float = 0.0
var _pause_t: float = 0.0
var _switch_cd: float = 0.0

func _init(p: BotProfile, seed_value: int = 1) -> void:
	profile = p
	_rng.seed = seed_value

## `aim_err_deg` is the aim's current angular error; `can_shoot` means the target (or its
## feet for rockets) is in line of sight right now.
func step(dt: float, dist: float, current: int, available: Array[int], winning: bool,
		can_shoot: bool, aim_err_deg: float, speed: float, grounded: bool) -> void:
	jump = false
	slide = false
	weapon_select = 0
	_switch_cd = maxf(0.0, _switch_cd - dt)
	var want: int = BotWeapons.choose(dist, winning, available)
	if want != current and _switch_cd <= 0.0:
		weapon_select = want
		_switch_cd = SWITCH_COOLDOWN
	_update_strafe(dt, speed, grounded)
	var pref: float = BotWeapons.preferred_distance(want)
	var fwd: float = 0.0
	if want == BotWeapons.BLADE or dist > pref * 1.3:
		fwd = 1.0
	elif dist < pref * 0.7:
		fwd = -1.0
	move = Vector2(_strafe_sign, fwd)
	fire = _fire_decision(dt, current, can_shoot, aim_err_deg)

func _update_strafe(dt: float, speed: float, grounded: bool) -> void:
	_strafe_t -= dt
	if _strafe_t > 0.0:
		return
	_strafe_t = _rng.randf_range(STRAFE_MIN, STRAFE_MAX)
	if _rng.randf() < 0.75:
		_strafe_sign = -_strafe_sign
	if grounded and _rng.randf() < JUMP_DODGE_CHANCE * profile.dodge_intensity:
		jump = true
	elif grounded and speed > SLIDE_MIN_SPEED and _rng.randf() < SLIDE_STRAFE_CHANCE * profile.slide_usage:
		slide = true

func _fire_decision(dt: float, slot: int, can_shoot: bool, aim_err_deg: float) -> bool:
	if not can_shoot or aim_err_deg > BotWeapons.fire_threshold_deg(slot):
		_burst_t = 0.0
		return false
	if slot != BotWeapons.SMG:
		return true
	if _burst_t > 0.0:
		_burst_t -= dt
		if _burst_t <= 0.0:
			_pause_t = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)
		return true
	_pause_t -= dt
	if _pause_t <= 0.0:
		_burst_t = _rng.randf_range(BURST_MIN, BURST_MAX)
		return true
	return false
