class_name BotStuck
extends RefCounted
## Stuck handling (GDD 10): moving < 0.5 m over 1.5 s -> jump, then strafe randomly 0.5 s,
## then request a new path, and after 5 s total ask for a teleport to the nearest waypoint.

const MIN_TRAVEL := 0.5
const JUMP_AT := 1.5
const STRAFE_AT := 2.0
const STRAFE_TIME := 0.5
const REPATH_AT := 3.0
const TELEPORT_AT := 5.0

var jump_now: bool = false ## one-tick flags, cleared by the next update
var want_repath: bool = false
var want_teleport: bool = false
var strafe_dir: float = 0.0 ## -1, 0, +1 while the random strafe stage is active
var teleports: int = 0 ## debug counter (soak test)

var _anchor: Vector3 = Vector3.ZERO
var _idle: float = 0.0
var _did_jump: bool = false
var _did_strafe: bool = false
var _did_repath: bool = false
var _strafe_sign: float = 1.0

func is_stuck() -> bool:
	return _idle >= JUMP_AT

func reset(pos: Vector3) -> void:
	_anchor = pos
	_idle = 0.0
	_did_jump = false
	_did_strafe = false
	_did_repath = false
	strafe_dir = 0.0

func update(dt: float, pos: Vector3, wants_move: bool, rng: RandomNumberGenerator) -> void:
	jump_now = false
	want_repath = false
	want_teleport = false
	if not wants_move or pos.distance_to(_anchor) >= MIN_TRAVEL:
		reset(pos)
		return
	_idle += dt
	if _idle >= JUMP_AT and not _did_jump:
		_did_jump = true
		jump_now = true
	if _idle >= STRAFE_AT and not _did_strafe:
		_did_strafe = true
		_strafe_sign = -1.0 if rng.randf() < 0.5 else 1.0
	strafe_dir = _strafe_sign if _did_strafe and _idle < STRAFE_AT + STRAFE_TIME else 0.0
	if _idle >= REPATH_AT and not _did_repath:
		_did_repath = true
		want_repath = true
	if _idle >= TELEPORT_AT:
		want_teleport = true
		teleports += 1
		reset(pos)
