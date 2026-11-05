class_name PlayerInput
extends InputSource

var _frame: InputFrame = InputFrame.new()
var _look_accum: Vector2 = Vector2.ZERO
var _crouch_toggled: bool = false
var _grapple_toggled: bool = false
var _prev_jump: bool = false
var _prev_crouch: bool = false
var _prev_fire: bool = false
var _prev_alt: bool = false
var _prev_grapple: bool = false

func push_look(rel: Vector2) -> void:
	_look_accum += rel

func sample(dt: float, _fighter: Fighter) -> InputFrame:
	_frame.clear()
	var mv := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	_frame.move = mv
	var sens := Settings.mouse_sensitivity * 0.0022
	var look := _look_accum * sens
	if Settings.invert_y:
		look.y = -look.y
	_frame.look_delta = Vector2(look.x, look.y)
	_look_accum = Vector2.ZERO

	var jump_held := Input.is_action_pressed("jump")
	_frame.jump_held = jump_held
	_frame.jump_pressed = jump_held and not _prev_jump
	_prev_jump = jump_held

	var crouch_raw := Input.is_action_pressed("crouch")
	if Settings.crouch_toggle:
		if crouch_raw and not _prev_crouch:
			_crouch_toggled = not _crouch_toggled
		_frame.crouch_held = _crouch_toggled
		_frame.crouch_pressed = crouch_raw and not _prev_crouch and _crouch_toggled
	else:
		_frame.crouch_held = crouch_raw
		_frame.crouch_pressed = crouch_raw and not _prev_crouch
	_prev_crouch = crouch_raw

	var fire_held := Input.is_action_pressed("fire")
	_frame.fire_held = fire_held
	_frame.fire_pressed = fire_held and not _prev_fire
	_prev_fire = fire_held

	var alt_held := Input.is_action_pressed("alt_fire")
	_frame.alt_held = alt_held
	_frame.alt_pressed = alt_held and not _prev_alt
	_prev_alt = alt_held

	var grap_raw := Input.is_action_pressed("grapple")
	if Settings.grapple_toggle:
		if grap_raw and not _prev_grapple:
			_grapple_toggled = not _grapple_toggled
		_frame.grapple_held = _grapple_toggled
		_frame.grapple_pressed = grap_raw and not _prev_grapple and _grapple_toggled
	else:
		_frame.grapple_held = grap_raw
		_frame.grapple_pressed = grap_raw and not _prev_grapple
	_prev_grapple = grap_raw

	for i in range(1, WeaponLibrary.SLOT_COUNT + 1):
		if Input.is_action_just_pressed("weapon_%d" % i):
			_frame.weapon_select = i
	_frame.weapon_next = Input.is_action_just_pressed("weapon_next")
	_frame.weapon_prev = Input.is_action_just_pressed("weapon_prev")
	_frame.weapon_last = Input.is_action_just_pressed("weapon_last")
	return _frame
