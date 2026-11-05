class_name RemoteInput
extends InputSource
## Networked input for remote fighters. Host/peers push frames via apply_network_frame.

var last_frame: InputFrame = InputFrame.new()
var target_pos: Vector3 = Vector3.ZERO
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var target_vel: Vector3 = Vector3.ZERO
var has_pose: bool = false

func sample(_dt: float, _fighter: Fighter) -> InputFrame:
	return last_frame

func apply_network_frame(frame: InputFrame) -> void:
	last_frame.copy_from(frame)

func apply_pose(pos: Vector3, yaw: float, pitch: float, vel: Vector3) -> void:
	target_pos = pos
	target_yaw = yaw
	target_pitch = pitch
	target_vel = vel
	has_pose = true

## Soft-correct remote body toward the last networked pose (call from NetBridge).
func snap_fighter(fighter: Fighter, blend: float = 0.35) -> void:
	if not has_pose:
		return
	fighter.global_position = fighter.global_position.lerp(target_pos, blend)
	fighter.velocity = fighter.velocity.lerp(target_vel, blend)
	if fighter.movement != null:
		fighter.movement.yaw = lerp_angle(fighter.movement.yaw, target_yaw, blend)
		fighter.movement.pitch = lerpf(fighter.movement.pitch, target_pitch, blend)
