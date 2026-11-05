class_name MovementConfig
extends Resource

@export var gravity: float = 24.0
@export var ground_speed: float = 9.0
@export var crouch_speed: float = 4.5
@export var ground_accel: float = 12.0
@export var ground_friction: float = 6.0
@export var stop_speed: float = 2.5
@export var jump_velocity: float = 8.6
@export var air_accel: float = 20.0
@export var air_wish_cap: float = 1.0
@export var jump_buffer_time: float = 0.10
@export var coyote_time: float = 0.08
@export var max_speed_hard_cap: float = 35.0

@export var slide_min_speed: float = 6.5
@export var slide_boost: float = 1.15
@export var slide_boost_cap: float = 14.0
@export var slide_friction: float = 1.0
@export var slide_steer_accel: float = 2.0
@export var slide_end_speed: float = 3.5
@export var slide_air_max: float = 0.25
@export var slide_cooldown: float = 0.8
@export var slide_jump_bonus: float = 0.08
@export var slide_jump_chain: float = 0.6

@export var wallrun_min_air: float = 0.15
@export var wallrun_min_speed: float = 5.0
@export var wallrun_probe: float = 0.7
@export var wallrun_gravity_scale: float = 0.15
@export var wallrun_target_speed: float = 11.0
@export var wallrun_max_time: float = 1.6
@export var wallrun_hug: float = 2.0
@export var wallrun_cooldown: float = 0.35
@export var wallrun_roll_deg: float = 12.0

@export var walljump_normal_speed: float = 7.0
@export var walljump_up: float = 8.0
@export var walljump_tangent_keep: float = 0.9
@export var walljump_max: int = 3
@export var walljump_probe: float = 0.5

@export var mantle_min_h: float = 0.5
@export var mantle_max_h: float = 1.9
@export var mantle_duration: float = 0.25
@export var mantle_speed_keep: float = 0.7

@export var grapple_range: float = 45.0
@export var grapple_accel: float = 38.0
@export var grapple_speed_cap: float = 28.0
@export var grapple_reel: float = 12.0
@export var grapple_min_len: float = 3.0
@export var grapple_max_time: float = 4.0
@export var grapple_cooldown: float = 1.5
@export var grapple_jump_boost: float = 2.0

@export var stand_height: float = 1.8
@export var stand_radius: float = 0.4
@export var stand_eye: float = 1.62
@export var crouch_height: float = 1.0
@export var crouch_eye: float = 0.8

static func make_default() -> MovementConfig:
	return MovementConfig.new()
