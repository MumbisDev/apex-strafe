class_name GrappleRope
extends Node3D
## Camera-facing ribbon rope from a fighter's hand to the grapple anchor. Wobbles on attach, retracts on release.

const SEGMENTS: int = 16
const HALF_WIDTH: float = 0.035
const WOBBLE_AMPLITUDE: float = 0.5
const WOBBLE_DECAY: float = 4.0
const RETRACT_TIME: float = 0.15
const HAND_OFFSET: Vector3 = Vector3(0.0, -0.25, 0.0)

var _mesh: ImmediateMesh
var _source: Node3D
var _anchor: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _retract_t: float = -1.0

func _ready() -> void:
	_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = FxUtil.unshaded(Color(UITheme.ACCENT, 0.9))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 200.0
	add_child(mi)
	FxUtil.hide_node(self)

## `source` supplies the rope start each frame (its aim origin when it has one).
func attach(source: Node3D, anchor: Vector3) -> void:
	_source = source
	_anchor = anchor
	_t = 0.0
	_retract_t = -1.0
	visible = true
	set_process(true)

func release() -> void:
	if visible and _retract_t < 0.0:
		_retract_t = 0.0

func is_attached() -> bool:
	return visible and _retract_t < 0.0

func _process(delta: float) -> void:
	_t += delta
	if _source == null or not is_instance_valid(_source):
		FxUtil.hide_node(self)
		return
	var start := _hand_position()
	var end := _anchor
	if _retract_t >= 0.0:
		_retract_t += delta
		var k := clampf(_retract_t / RETRACT_TIME, 0.0, 1.0)
		end = _anchor.lerp(start, k)
		if k >= 1.0:
			FxUtil.hide_node(self)
			return
	_rebuild(start, end)

func _hand_position() -> Vector3:
	if _source.has_method("aim_origin"):
		return (_source.call("aim_origin") as Vector3) + HAND_OFFSET
	return _source.global_position + Vector3(0, 1.3, 0)

func _rebuild(start: Vector3, end: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam != null else start + Vector3.UP * 5.0
	var axis := end - start
	var length := axis.length()
	if length < 0.05:
		return
	var dir := axis / length
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var amp := WOBBLE_AMPLITUDE * exp(-_t * WOBBLE_DECAY) * minf(length / 20.0, 1.0)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var s := float(i) / float(SEGMENTS)
		var p := start + axis * s
		p += (side * sin(_t * 28.0 + s * 9.0) + Vector3.UP * cos(_t * 23.0 + s * 7.0)) * amp * sin(PI * s)
		var face := dir.cross(cam_pos - p)
		face = face.normalized() * HALF_WIDTH if face.length_squared() > 0.0001 else side * HALF_WIDTH
		_mesh.surface_add_vertex(to_local(p - face))
		_mesh.surface_add_vertex(to_local(p + face))
	_mesh.surface_end()
