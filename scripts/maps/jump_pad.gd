class_name JumpPad
extends Area3D
## Launches fighters that overlap it. Each fighter has a 0.5 s cooldown.

signal launched(body: Node3D)

const COOLDOWN: float = 0.5

var launch_velocity: Vector3 = Vector3(0.0, 17.0, 0.0)

var _clock: float = 0.0
var _ready_at: Dictionary = {}

func _physics_process(delta: float) -> void:
	_clock += delta
	for body in get_overlapping_bodies():
		var id: int = body.get_instance_id()
		if _clock < float(_ready_at.get(id, 0.0)):
			continue
		_ready_at[id] = _clock + COOLDOWN
		launch(body)

func launch(body: Node3D) -> void:
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = launch_velocity
	if body.has_method("on_jump_pad"):
		body.call("on_jump_pad", launch_velocity)
	launched.emit(body)
