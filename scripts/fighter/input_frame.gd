class_name InputFrame
extends RefCounted

var move: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO ## yaw, pitch radians this tick
var jump_pressed: bool = false
var jump_held: bool = false
var crouch_pressed: bool = false
var crouch_held: bool = false
var fire_pressed: bool = false
var fire_held: bool = false
var alt_pressed: bool = false
var alt_held: bool = false
var grapple_pressed: bool = false
var grapple_held: bool = false
var weapon_select: int = 0 ## 0 none, 1-8
var weapon_next: bool = false
var weapon_prev: bool = false
var weapon_last: bool = false

func clear() -> void:
	move = Vector2.ZERO
	look_delta = Vector2.ZERO
	jump_pressed = false
	jump_held = false
	crouch_pressed = false
	crouch_held = false
	fire_pressed = false
	fire_held = false
	alt_pressed = false
	alt_held = false
	grapple_pressed = false
	grapple_held = false
	weapon_select = 0
	weapon_next = false
	weapon_prev = false
	weapon_last = false

func copy_from(other: InputFrame) -> void:
	move = other.move
	look_delta = other.look_delta
	jump_pressed = other.jump_pressed
	jump_held = other.jump_held
	crouch_pressed = other.crouch_pressed
	crouch_held = other.crouch_held
	fire_pressed = other.fire_pressed
	fire_held = other.fire_held
	alt_pressed = other.alt_pressed
	alt_held = other.alt_held
	grapple_pressed = other.grapple_pressed
	grapple_held = other.grapple_held
	weapon_select = other.weapon_select
	weapon_next = other.weapon_next
	weapon_prev = other.weapon_prev
	weapon_last = other.weapon_last

## Packed for GD-Sync payloads (floats + bitflags).
func to_array() -> Array:
	var flags := 0
	if jump_pressed: flags |= 1
	if jump_held: flags |= 2
	if crouch_pressed: flags |= 4
	if crouch_held: flags |= 8
	if fire_pressed: flags |= 16
	if fire_held: flags |= 32
	if alt_pressed: flags |= 64
	if alt_held: flags |= 128
	if grapple_pressed: flags |= 256
	if grapple_held: flags |= 512
	if weapon_next: flags |= 1024
	if weapon_prev: flags |= 2048
	if weapon_last: flags |= 4096
	return [move.x, move.y, look_delta.x, look_delta.y, flags, weapon_select]

static func from_array(data: Array) -> InputFrame:
	var f := InputFrame.new()
	if data.size() < 6:
		return f
	f.move = Vector2(float(data[0]), float(data[1]))
	f.look_delta = Vector2(float(data[2]), float(data[3]))
	var flags := int(data[4])
	f.jump_pressed = (flags & 1) != 0
	f.jump_held = (flags & 2) != 0
	f.crouch_pressed = (flags & 4) != 0
	f.crouch_held = (flags & 8) != 0
	f.fire_pressed = (flags & 16) != 0
	f.fire_held = (flags & 32) != 0
	f.alt_pressed = (flags & 64) != 0
	f.alt_held = (flags & 128) != 0
	f.grapple_pressed = (flags & 256) != 0
	f.grapple_held = (flags & 512) != 0
	f.weapon_next = (flags & 1024) != 0
	f.weapon_prev = (flags & 2048) != 0
	f.weapon_last = (flags & 4096) != 0
	f.weapon_select = int(data[5])
	return f
