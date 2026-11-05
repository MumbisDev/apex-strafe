class_name CameraRig
extends Node3D

var camera: Camera3D
var base_fov: float = 100.0
var land_dip: float = 0.0
var land_dip_t: float = 0.0
var roll: float = 0.0
var shake: float = 0.0
var _fighter: Fighter

func build(fighter: Fighter) -> void:
	_fighter = fighter
	camera = Camera3D.new()
	camera.fov = Settings.fov if Settings else 100.0
	camera.current = false
	add_child(camera)

func set_active(on: bool) -> void:
	if camera:
		camera.current = on

func tick(dt: float, move: MovementController, speed: float, wallrun_side: float) -> void:
	base_fov = Settings.fov if Settings else 100.0
	var fov_kick := 0.0
	if Settings == null or Settings.fov_kick:
		var t := clampf((speed - 9.0) / (22.0 - 9.0), 0.0, 1.0)
		fov_kick = 12.0 * t
	camera.fov = lerpf(camera.fov, base_fov + fov_kick, 1.0 - exp(-10.0 * dt))
	position = Vector3(0, move.eye_height(), 0)
	rotation = Vector3(move.pitch, 0, 0)
	# Parent fighter handles yaw
	var target_roll := 0.0
	if Settings == null or Settings.camera_tilt:
		if move.state == MovementController.State.WALLRUN:
			target_roll = deg_to_rad(move.config.wallrun_roll_deg) * wallrun_side
		else:
			target_roll = deg_to_rad(1.5) * clampf(speed / 20.0, 0.0, 1.0) * signf(_strafe_sign())
	roll = lerpf(roll, target_roll, 1.0 - exp(-8.0 * dt))
	camera.rotation.z = roll
	if land_dip_t > 0.0:
		land_dip_t -= dt
		camera.position.y = -land_dip * (land_dip_t / 0.12)
	else:
		camera.position.y = 0.0
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 8.0)
		var amt := shake * (Settings.screen_shake_amount if Settings else 1.0)
		camera.h_offset = randf_range(-amt, amt) * 0.05
		camera.v_offset = randf_range(-amt, amt) * 0.05
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func on_landed(impact_speed: float) -> void:
	var t := clampf(impact_speed / 18.0, 0.0, 1.0)
	land_dip = 0.08 * t
	land_dip_t = 0.12

func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)

func _strafe_sign() -> float:
	if _fighter == null:
		return 0.0
	var right := _fighter.global_transform.basis.x
	return _fighter.velocity.dot(right)
