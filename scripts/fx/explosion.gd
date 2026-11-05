class_name Explosion
extends Node3D
## Pooled explosion: expanding emissive fireball, shockwave ring, fire + smoke particles, light flash.

const DURATION: float = 1.6
const FIREBALL_TIME: float = 0.45
const RING_TIME: float = 0.5
const LIGHT_TIME: float = 0.3

var _fireball: MeshInstance3D
var _fire_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _fire: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _radius: float = 4.5
var _t: float = 0.0

func _ready() -> void:
	_fire_mat = FxKit.unshaded(Color(1.0, 0.55, 0.15, 0.9))
	_fireball = MeshInstance3D.new()
	_fireball.mesh = FxKit.sphere_mesh(1.0, 12)
	_fireball.material_override = _fire_mat
	_ring_mat = FxKit.unshaded(Color(1.0, 0.8, 0.5, 0.8))
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_fire = FxKit.burst(28, 0.7, FxKit.sphere_mesh(0.25, 6), FxKit.unshaded(Color.WHITE),
		FxKit.process_material(Vector3.UP, 180.0, 3.0, 9.0, Vector3(0, 1.5, 0), 0.5, 1.4,
			[Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.45, 0.1, 0.8), Color(0.3, 0.05, 0.0, 0.0)]))
	_smoke = FxKit.burst(16, DURATION - 0.1, FxKit.sphere_mesh(0.45, 6), FxKit.unshaded(Color.WHITE, false),
		FxKit.process_material(Vector3.UP, 120.0, 1.0, 4.0, Vector3(0, 1.2, 0), 0.8, 2.0,
			[Color(0.25, 0.25, 0.25, 0.0), Color(0.2, 0.2, 0.22, 0.55), Color(0.1, 0.1, 0.1, 0.0)]))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.25)
	_light.shadow_enabled = false
	for n: Node3D in [_fireball, _ring, _fire, _smoke, _light]:
		add_child(n)
	for g: GeometryInstance3D in [_fireball, _ring]:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FxKit.hide_node(self)

func play(pos: Vector3, radius: float) -> void:
	global_position = pos
	_radius = maxf(radius, 0.5)
	_t = 0.0
	_light.omni_range = _radius * 3.0
	_light.light_energy = 6.0
	_fireball.scale = Vector3.ONE * 0.1
	_ring.scale = Vector3.ONE * 0.1
	visible = true
	set_process(true)
	FxKit.fire(_fire)
	FxKit.fire(_smoke)

func _process(delta: float) -> void:
	_t += delta
	var fb := clampf(_t / FIREBALL_TIME, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - fb, 3.0)
	_fireball.scale = Vector3.ONE * _radius * 0.7 * maxf(ease_out, 0.05)
	_fire_mat.albedo_color.a = 0.9 * (1.0 - fb)
	_fireball.visible = fb < 1.0
	var rg := clampf(_t / RING_TIME, 0.0, 1.0)
	_ring.scale = Vector3.ONE * _radius * 1.3 * maxf(1.0 - pow(1.0 - rg, 2.0), 0.05)
	_ring_mat.albedo_color.a = 0.8 * (1.0 - rg)
	_ring.visible = rg < 1.0
	_light.light_energy = 6.0 * clampf(1.0 - _t / LIGHT_TIME, 0.0, 1.0)
	_light.visible = _t < LIGHT_TIME
	if _t >= DURATION:
		FxKit.hide_node(self)
