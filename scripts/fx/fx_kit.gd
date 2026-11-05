class_name FxKit
extends RefCounted
## Shared builders for cosmetic FX (materials, particle systems, orientation). No state.

const LAYER_WORLD: int = 1
const LAYER_DEBRIS: int = 32 ## physics layer 6

static func unshaded(color: Color, additive: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func ramp(colors: Array[Color]) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / float(maxi(1, colors.size() - 1)))
	g.offsets = offsets
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

static func sphere_mesh(radius: float, segments: int = 6) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = maxi(2, floori(segments * 0.5))
	return s

## One-shot burst emitter. Trigger it with fire().
static func burst(amount: int, lifetime: float, mesh: Mesh, mat: Material, pm: ParticleProcessMaterial) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.material_override = mat
	return p

static func process_material(dir: Vector3, spread_deg: float, v_min: float, v_max: float,
		gravity: Vector3, scale_min: float, scale_max: float, colors: Array[Color]) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread_deg
	pm.initial_velocity_min = v_min
	pm.initial_velocity_max = v_max
	pm.gravity = gravity
	pm.scale_min = scale_min
	pm.scale_max = scale_max
	pm.color_ramp = ramp(colors)
	return pm

static func fire(p: GPUParticles3D) -> void:
	p.restart()
	p.emitting = true

## Basis whose +Y axis is `normal` (for decals, sparks, rings).
static func basis_up(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)

static func hide_node(n: Node3D) -> void:
	n.visible = false
	n.set_process(false)
