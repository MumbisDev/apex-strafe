class_name ScreenShake
extends Node
## Maps gameplay events to camera shake and FOV punches for the local fighter.
## Shake is delegated to CameraRig.add_shake (it applies the Settings shake scale);
## FOV punches bump camera.fov, which CameraRig's per-tick lerp then relaxes back.

const EXPLOSION_MAX_DISTANCE: float = 30.0
const EXPLOSION_SHAKE: float = 2.0
const DAMAGE_SHAKE_MAX: float = 0.8
const GRAPPLE_FOV_PUNCH: float = 8.0

var local_id: int = -1
var _rig: CameraRig

func _ready() -> void:
	Events.explosion.connect(_on_explosion)
	Events.fighter_damaged.connect(_on_damaged)
	Events.grapple_attached.connect(_on_grapple_attached)

func bind(rig: CameraRig, id: int) -> void:
	_rig = rig
	local_id = id

## Shake strength 0..1 for an explosion `distance` meters from the camera.
static func explosion_strength(distance: float, radius: float) -> float:
	var reach := maxf(EXPLOSION_MAX_DISTANCE, radius * 4.0)
	return clampf(1.0 - distance / reach, 0.0, 1.0)

func _on_explosion(pos: Vector3, radius: float, _owner_id: int) -> void:
	if _rig == null or _rig.camera == null:
		return
	var strength := explosion_strength(_rig.camera.global_position.distance_to(pos), radius)
	if strength > 0.0:
		_rig.add_shake(strength * EXPLOSION_SHAKE)

func _on_damaged(victim_id: int, _attacker_id: int, amount: float, _hit_pos: Vector3, _is_head: bool) -> void:
	if victim_id == local_id and _rig != null:
		_rig.add_shake(clampf(amount / 100.0, 0.1, DAMAGE_SHAKE_MAX))

func _on_grapple_attached(id: int, _anchor: Vector3) -> void:
	if id == local_id and _rig != null and _rig.camera != null and Settings.fov_kick:
		_rig.camera.fov += GRAPPLE_FOV_PUNCH
