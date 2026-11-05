class_name Tracer
extends Node3D
## Pooled bullet tracer: thin emissive box racing from muzzle to hit point. Rail beams linger and fade.

const SPEED: float = 300.0 ## visual speed, m/s
const TRAIL_LENGTH: float = 6.0
const THICKNESS: float = 0.025
const RAIL_THICKNESS: float = 0.07

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _from: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.FORWARD
var _length: float = 0.0
var _linger: float = 0.0
var _color: Color = Color.WHITE
var _t: float = 0.0
var _thickness: float = THICKNESS

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	_mat = FxKit.unshaded(Color.WHITE)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	FxKit.hide_node(self)

## linger > 0 keeps the full beam visible and fades it over that many seconds (railgun).
func play(from: Vector3, to: Vector3, color: Color, linger: float = 0.0) -> void:
	_from = from
	_length = from.distance_to(to)
	if _length < 0.01:
		return
	_dir = (to - from) / _length
	_linger = linger
	_color = color
	_thickness = RAIL_THICKNESS if linger > 0.0 else THICKNESS
	_t = 0.0
	_mat.albedo_color = color
	visible = true
	set_process(true)
	_update(0.0)

func _process(delta: float) -> void:
	_t += delta
	_update(_t)

func _update(t: float) -> void:
	var head := minf(t * SPEED, _length)
	var tail := 0.0 if _linger > 0.0 else maxf(0.0, head - TRAIL_LENGTH)
	var seg := maxf(head - tail, 0.01)
	var mid := _from + _dir * (tail + seg * 0.5)
	var up := Vector3.RIGHT if absf(_dir.dot(Vector3.UP)) > 0.99 else Vector3.UP
	global_transform = Transform3D(Basis.looking_at(_dir, up), mid)
	_mesh.scale = Vector3(_thickness, _thickness, seg)
	var arrive := _length / SPEED
	var alpha := 1.0
	if _linger > 0.0 and t > arrive:
		alpha = 1.0 - (t - arrive) / _linger
	_mat.albedo_color = Color(_color.r, _color.g, _color.b, clampf(alpha, 0.0, 1.0))
	if (_linger > 0.0 and alpha <= 0.0) or (_linger <= 0.0 and tail >= _length):
		FxKit.hide_node(self)
