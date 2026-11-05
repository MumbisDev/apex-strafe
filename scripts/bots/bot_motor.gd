class_name BotMotor
extends RefCounted
## Turns navigator output into movement input: local move axes, look, bunnyhop with
## air-strafe, slide, jump links, grapple links, and unstick actions. The brain may
## override the result afterwards (combat strafing, aiming at a target).

const BHOP_MIN_RUN := 5.0
const BHOP_ROLL_INTERVAL := 1.0
const BHOP_YAW_RATE_DEG := 90.0 ## deg/s at skill 0; scales up to 2x at skill 1
const BHOP_WIGGLE_DEG := 8.0
const BHOP_ALT_INTERVAL := 0.3
const SLIDE_HOLD := 0.9
const SLIDE_MIN_SPEED := 6.5
const GRAPPLE_WINDOW := 1.2
const GRAPPLE_RELEASE_DIST := 4.0
const GRAPPLE_AIM_DEG := 3.0

var profile: BotProfile
var aim: BotAim
var bhopping: bool = false ## debug

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bhop_on: bool = false
var _bhop_roll_t: float = 0.0
var _alt_sign: float = 1.0
var _alt_t: float = 0.0
var _slide_hold: float = 0.0
var _grapple_until: float = -1.0
var _grapple_anchor: Vector3 = Vector3.ZERO

func _init(p: BotProfile, bot_aim: BotAim, seed_value: int = 1) -> void:
	profile = p
	aim = bot_aim
	_rng.seed = seed_value

## World-space horizontal direction to local move axes (x strafe right, y forward) for `yaw`.
static func to_local(dir: Vector3, yaw: float) -> Vector2:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return Vector2(dir.dot(right), dir.dot(forward))

## Fill `frame` for this tick. `clock` is the brain clock in seconds.
func drive(dt: float, clock: float, f: Fighter, nav: BotNavigator, stuck: BotStuck, frame: InputFrame, allow_bhop: bool = true) -> void:
	var mv: MovementController = f.movement
	var speed: float = mv.horizontal_speed(f)
	_slide_hold = maxf(0.0, _slide_hold - dt)
	bhopping = false
	if nav.grapple_now:
		_grapple_until = clock + GRAPPLE_WINDOW
		_grapple_anchor = nav.grapple_anchor
	if _drive_grapple(dt, clock, f, frame):
		return
	if nav.slide_now and f.is_on_floor() and speed > SLIDE_MIN_SPEED:
		begin_slide(frame)
	if _slide_hold > 0.0:
		frame.crouch_held = true
	var dir: Vector3 = nav.move_dir
	if dir.length_squared() < 0.0001:
		return
	frame.move = to_local(dir, mv.yaw)
	frame.look_delta = aim.step(dt, mv.yaw, mv.pitch, Vector3(dir.x, 0.0, dir.z), false)
	if nav.jump_now:
		frame.jump_pressed = true
		frame.jump_held = true
	if _slide_hold <= 0.0 and allow_bhop and _bhop(dt, f, nav, frame, dir):
		bhopping = true
	if stuck.jump_now:
		frame.jump_pressed = true
	if stuck.strafe_dir != 0.0:
		frame.move = Vector2(stuck.strafe_dir, 0.3)

## Starts a slide this tick and keeps crouch held for SLIDE_HOLD seconds.
func begin_slide(frame: InputFrame) -> void:
	frame.crouch_pressed = true
	frame.crouch_held = true
	_slide_hold = SLIDE_HOLD

## Grapple link: aim at the anchor, fire when aligned, hold until close, then release.
func _drive_grapple(dt: float, clock: float, f: Fighter, frame: InputFrame) -> bool:
	var mv: MovementController = f.movement
	if mv.grappling:
		_grapple_until = -1.0
		frame.grapple_held = f.global_position.distance_to(mv.grapple_anchor) > GRAPPLE_RELEASE_DIST
		return true
	if clock >= _grapple_until:
		return false
	var to_anchor: Vector3 = _grapple_anchor - f.aim_origin()
	frame.look_delta = aim.step(dt, mv.yaw, mv.pitch, to_anchor, false)
	if aim.on_target(GRAPPLE_AIM_DEG):
		frame.grapple_pressed = true
		frame.grapple_held = true
	return true

## Bunnyhop with air-strafe on straight stretches, gated by the bhop_skill roll.
func _bhop(dt: float, f: Fighter, nav: BotNavigator, frame: InputFrame, dir: Vector3) -> bool:
	_bhop_roll_t -= dt
	if _bhop_roll_t <= 0.0:
		_bhop_roll_t = BHOP_ROLL_INTERVAL
		_bhop_on = _rng.randf() < profile.bhop_skill
	if not _bhop_on or nav.straight_deg >= BotNavigator.STRAIGHT_DEG:
		return false
	if nav.path_length_left(f.global_position) < BHOP_MIN_RUN:
		return false
	var mv: MovementController = f.movement
	frame.jump_held = true
	if f.is_on_floor():
		frame.jump_pressed = true
		frame.move = Vector2(0.0, 1.0)
		return true
	_alt_t -= dt
	if _alt_t <= 0.0:
		_alt_t = BHOP_ALT_INTERVAL
		_alt_sign = -_alt_sign
	var heading: float = atan2(-dir.x, -dir.z) + deg_to_rad(BHOP_WIGGLE_DEG) * _alt_sign * (0.5 + 0.5 * profile.bhop_skill)
	var turn: float = angle_difference(mv.yaw, heading)
	var rate: float = BHOP_YAW_RATE_DEG * (1.0 + profile.bhop_skill)
	var step: float = clampf(turn, -deg_to_rad(rate) * dt, deg_to_rad(rate) * dt)
	frame.look_delta = Vector2(-step, 0.0)
	frame.move = Vector2(signf(turn) if absf(turn) > deg_to_rad(1.0) else _alt_sign, 0.0)
	return true
