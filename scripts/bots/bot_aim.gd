class_name BotAim
extends RefCounted
## Limited-speed aiming with a resampled error vector and projectile lead.
## Output is an InputFrame-style look delta (MovementController does `yaw -= x; pitch -= y`).

const ERROR_RESAMPLE := 0.3
const TORSO_HEIGHT := 1.1
const ROCKET_SLOT := 6
const PLASMA_SLOT := 5
const PLASMA_SPEED := 55.0
const ROCKET_SPEED := 32.0
const ROCKET_FEET_RANGE := 20.0

var profile: BotProfile
var error_offset: Vector2 = Vector2.ZERO ## (yaw, pitch) radians
var angle_error: float = 0.0 ## radians between current aim and the requested direction (error excluded)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _resample_t: float = 0.0

func _init(p: BotProfile, seed_value: int = 1) -> void:
	profile = p
	_rng.seed = seed_value

static func projectile_speed(slot: int) -> float:
	match slot:
		PLASMA_SLOT: return PLASMA_SPEED
		ROCKET_SLOT: return ROCKET_SPEED
	return 0.0

## Where to aim. `target_feet` is the enemy feet position.
func aim_point(eye: Vector3, target_feet: Vector3, target_vel: Vector3, slot: int, grounded: bool) -> Vector3:
	var torso: Vector3 = target_feet + Vector3.UP * TORSO_HEIGHT
	var dist: float = eye.distance_to(torso)
	if slot == ROCKET_SLOT and grounded and dist <= ROCKET_FEET_RANGE:
		torso = target_feet + Vector3.UP * 0.1
	var speed: float = projectile_speed(slot)
	if speed <= 0.0:
		return torso
	return torso + target_vel * (dist / speed) * profile.lead_accuracy

## Advances the aim one tick toward `dir` (world direction). Returns the look delta to put
## in the InputFrame. `max_deg_s < 0` uses the profile's tracking speed.
func step(dt: float, yaw: float, pitch: float, dir: Vector3, with_error: bool = true, max_deg_s: float = -1.0) -> Vector2:
	if dir.length_squared() < 0.0001:
		return Vector2.ZERO
	_resample_t -= dt
	if _resample_t <= 0.0:
		_resample_t = ERROR_RESAMPLE
		_resample_error()
	var want_yaw: float = atan2(-dir.x, -dir.z)
	var want_pitch: float = asin(clampf(dir.normalized().y, -1.0, 1.0))
	var d_yaw: float = angle_difference(yaw, want_yaw)
	var d_pitch: float = want_pitch - pitch
	angle_error = Vector2(d_yaw * cos(pitch), d_pitch).length()
	if with_error:
		d_yaw += error_offset.x
		d_pitch += error_offset.y
	var rate: float = profile.aim_tracking_deg_s if max_deg_s < 0.0 else max_deg_s
	var max_step: float = deg_to_rad(rate) * dt
	var delta := Vector2(d_yaw, d_pitch)
	if delta.length() > max_step:
		delta = delta.normalized() * max_step
	return Vector2(-delta.x, -delta.y)

## True when the last `step` ended within `threshold_deg` of the requested direction.
func on_target(threshold_deg: float) -> bool:
	return angle_error <= deg_to_rad(threshold_deg)

func _resample_error() -> void:
	var mag: float = deg_to_rad(profile.aim_error_deg) * _rng.randf()
	var ang: float = _rng.randf() * TAU
	error_offset = Vector2(cos(ang), sin(ang)) * mag

## Unit direction for a yaw/pitch pair (mirrors MovementController._aim_dir).
static func dir_from_angles(yaw: float, pitch: float) -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD
