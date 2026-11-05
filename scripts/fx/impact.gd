class_name Impact
extends Node3D
## Pooled impact: spark burst plus a short flash. World hits throw yellow sparks;
## fighter hits throw red-white cube sparks (no decal).

const FLASH_TIME: float = 0.07
const LIFETIME: float = 0.6

var _sparks_world: GPUParticles3D
var _sparks_flesh: GPUParticles3D
var _flash: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _t: float = 0.0

func _ready() -> void:
	var gravity := Vector3(0, -12, 0)
	_sparks_world = FxUtil.burst(10, 0.4, FxUtil.sphere_mesh(0.025, 4), FxUtil.unshaded(Color.WHITE),
		FxUtil.process_material(Vector3.UP, 55.0, 3.0, 8.0, gravity, 0.6, 1.2,
			[Color("#FFFBD0"), Color("#FFC233"), Color(1.0, 0.3, 0.05, 0.0)]))
	var cube := BoxMesh.new()
	cube.size = Vector3(0.05, 0.05, 0.05)
	_sparks_flesh = FxUtil.burst(8, 0.45, cube, FxUtil.unshaded(Color.WHITE, false),
		FxUtil.process_material(Vector3.UP, 70.0, 2.0, 6.0, gravity, 0.7, 1.3,
			[Color.WHITE, Color("#FF3B3B"), Color(0.5, 0.0, 0.0, 0.0)]))
	_flash_mat = FxUtil.unshaded(Color(1, 0.9, 0.6, 1))
	_flash = MeshInstance3D.new()
	_flash.mesh = FxUtil.sphere_mesh(0.12, 6)
	_flash.material_override = _flash_mat
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n: Node3D in [_sparks_world, _sparks_flesh, _flash]:
		add_child(n)
	FxUtil.hide_node(self)

func play(pos: Vector3, normal: Vector3, flesh: bool) -> void:
	global_transform = Transform3D(FxUtil.basis_up(normal), pos)
	_flash_mat.albedo_color = Color(1.0, 0.25, 0.2, 1.0) if flesh else Color(1.0, 0.9, 0.6, 1.0)
	_flash.visible = true
	_flash.scale = Vector3.ONE
	_t = 0.0
	visible = true
	set_process(true)
	FxUtil.fire(_sparks_flesh if flesh else _sparks_world)

func _process(delta: float) -> void:
	_t += delta
	if _t < FLASH_TIME:
		var k := 1.0 - _t / FLASH_TIME
		_flash.scale = Vector3.ONE * (0.6 + 0.8 * k)
		_flash_mat.albedo_color.a = k
	else:
		_flash.visible = false
	if _t >= LIFETIME:
		FxUtil.hide_node(self)
