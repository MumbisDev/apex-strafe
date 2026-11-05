class_name MapBuilder
extends RefCounted
## Common base for generated maps. Subclasses override `_make_palette()` and `build(parent)`.
## Every solid helper creates a MeshInstance3D plus a StaticBody3D on physics layer `world` (1).
## No CSG. Helper positions: box/cylinder/ramp use the volume center, stairs/wall use the base.

const LAYER_WORLD: int = 1
const LAYER_FIGHTERS: int = 2
const LAYER_TRIGGERS: int = 64
const PICKUP_HOVER: float = 0.9

const P_STIM := "stim"
const P_MEDKIT := "medkit"
const P_MEGA := "mega_health"
const P_SHARD := "armor_shard"
const P_PLATE := "armor_plate"
const P_AMMO := "ammo_box"
const P_OVERCHARGE := "overcharge"
const P_HASTE := "haste"
const P_SMG := "weapon_smg"
const P_SHOTGUN := "weapon_shotgun"
const P_PLASMA := "weapon_plasma"
const P_ROCKET := "weapon_rocket"
const P_RAILGUN := "weapon_railgun"
const PICKUP_TYPES: Array[String] = [
	P_STIM, P_MEDKIT, P_MEGA, P_SHARD, P_PLATE, P_AMMO, P_OVERCHARGE, P_HASTE,
	P_SMG, P_SHOTGUN, P_PLASMA, P_ROCKET, P_RAILGUN,
]

const MAP_SCRIPTS: Dictionary = {
	"foundry": "res://scripts/maps/map_foundry.gd",
	"spire": "res://scripts/maps/map_spire.gd",
	"sprawl": "res://scripts/maps/map_sprawl.gd",
	"range": "res://scripts/maps/map_range.gd",
}

var map_id: String = ""
var map_name: String = ""
var description: String = ""
var palette: MapPalette
var root: Node3D
var m_floor: Material
var m_wall: Material
var m_accent: Material

var _geo: Node3D
var _spawns: Array[Dictionary] = []
var _pickups: Array[Dictionary] = []
var _kill_volumes: Array[Dictionary] = []
var _links: Array[Dictionary] = []
var _anchors: Array[Vector3] = []
var _pads: Array[Dictionary] = []

static func create(id: String) -> MapBuilder:
	if not MAP_SCRIPTS.has(id):
		return null
	var script: GDScript = load(MAP_SCRIPTS[id] as String) as GDScript
	return script.new() as MapBuilder

static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

## Launch velocity (gravity from MovementConfig) that lands exactly on `to`.
static func ballistic_velocity(from: Vector3, to: Vector3, apex_extra: float = 1.5) -> Vector3:
	var g: float = MovementConfig.make_default().gravity
	var dy: float = to.y - from.y
	var h: float = maxf(dy, 0.0) + apex_extra
	var vy: float = sqrt(2.0 * g * h)
	var t: float = vy / g + sqrt(2.0 * maxf(h - dy, 0.0) / g)
	return Vector3((to.x - from.x) / t, vy, (to.z - from.z) / t)

func _make_palette() -> MapPalette:
	return MapPalette.new()

@warning_ignore("unused_parameter")
func build(parent: Node3D) -> Dictionary:
	push_error("MapBuilder.build must be overridden")
	return {}

func begin(parent: Node3D) -> void:
	palette = _make_palette()
	m_floor = palette.floor_material()
	m_wall = palette.wall_material()
	m_accent = palette.accent_material()
	root = Node3D.new()
	root.name = map_name
	parent.add_child(root)
	palette.build_environment(root)
	_geo = Node3D.new()
	_geo.name = "Geometry"
	root.add_child(_geo)

func finish(bounds: AABB, extra: Dictionary = {}) -> Dictionary:
	var aabbs: Array[AABB] = []
	for kv in _kill_volumes:
		aabbs.append(kv["aabb"] as AABB)
	var data: Dictionary = {
		"id": map_id, "name": map_name, "description": description,
		"spawns": _spawns, "pickups": _pickups, "bounds": bounds,
		"kill_volumes": _kill_volumes, "jump_pads": _pads,
		"grapple_anchors": _anchors, "palette": palette, "root": root,
		"waypoints": {"bounds": bounds, "links": _links, "kill_aabbs": aabbs},
	}
	data.merge(extra)
	return data

# ---------------------------------------------------------------- solids

func _basis_facing(dir: Vector3) -> Basis:
	var d: Vector3 = dir.normalized()
	var up: Vector3 = Vector3.RIGHT if absf(d.y) > 0.999 else Vector3.UP
	return Basis.looking_at(d, up)

func _new_body(pos: Vector3, basis: Basis = Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.transform = Transform3D(basis, pos)
	_geo.add_child(body)
	return body

func _add_part(body: StaticBody3D, mesh: Mesh, shape: Shape3D, mat: Material, offset: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = offset
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = offset
	body.add_child(cs)

func box(pos: Vector3, size: Vector3, mat: Material, basis: Basis = Basis.IDENTITY) -> StaticBody3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	var body := _new_body(pos, basis)
	_add_part(body, mesh, shape, mat)
	return body

## Wedge. size = (width, rise, run); it rises toward the horizontal `direction`.
func ramp(pos: Vector3, size: Vector3, direction: Vector3, mat: Material) -> StaticBody3D:
	var dir := Vector3(direction.x, 0.0, direction.z)
	var pts: PackedVector3Array = MapMeshUtil.ramp_points(size)
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var mesh: ArrayMesh = MapMeshUtil.commit_hulls([pts], MapMeshUtil.ramp_faces())
	var body := _new_body(pos, _basis_facing(dir))
	_add_part(body, mesh, shape, mat)
	return body

## Visual steps with a smooth wedge collider, so fighters glide up without step-up logic.
## `pos` is the bottom-center of the first step's front edge; ascends toward `direction`.
func stairs(pos: Vector3, steps: int, step_h: float, step_d: float, width: float, mat: Material, direction: Vector3 = Vector3.FORWARD) -> StaticBody3D:
	var body := _new_body(pos, _basis_facing(Vector3(direction.x, 0.0, direction.z)))
	var rise: float = float(steps) * step_h
	var run: float = float(steps) * step_d
	for i in steps:
		var h: float = step_h * float(i + 1)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, h, step_d)
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(0.0, h * 0.5, -(float(i) + 0.5) * step_d)
		body.add_child(mi)
	var shape := ConvexPolygonShape3D.new()
	var hw: float = width * 0.5
	shape.points = PackedVector3Array([
		Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0), Vector3(-hw, 0.0, -run), Vector3(hw, 0.0, -run),
		Vector3(-hw, rise, -run), Vector3(hw, rise, -run),
	])
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body

func cylinder(pos: Vector3, radius: float, height: float, mat: Material) -> StaticBody3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var body := _new_body(pos)
	_add_part(body, mesh, shape, mat)
	return body

## Vertical slab between ground points a and b (base at a.y).
func wall(a: Vector3, b: Vector3, height: float, thickness: float, mat: Material) -> StaticBody3D:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var center: Vector3 = Vector3((a.x + b.x) * 0.5, a.y + height * 0.5, (a.z + b.z) * 0.5)
	return box(center, Vector3(thickness, height, d.length()), mat, _basis_facing(d))

## Slab whose top surface is at `top_pos.y`. Optional glowing edge trim.
func platform(top_pos: Vector3, size: Vector2, mat: Material, trim_color: Color = Color(0.0, 0.0, 0.0, 0.0), thickness: float = 0.6) -> StaticBody3D:
	var body: StaticBody3D = box(top_pos - Vector3(0.0, thickness * 0.5, 0.0), Vector3(size.x, thickness, size.y), mat)
	if trim_color.a > 0.0:
		var hx: float = size.x * 0.5 - 0.1
		var hz: float = size.y * 0.5 - 0.1
		var y: float = top_pos.y + 0.02
		var c := Vector3(top_pos.x, y, top_pos.z)
		trim(c + Vector3(-hx, 0, -hz), c + Vector3(hx, 0, -hz), 0.12, trim_color)
		trim(c + Vector3(hx, 0, -hz), c + Vector3(hx, 0, hz), 0.12, trim_color)
		trim(c + Vector3(hx, 0, hz), c + Vector3(-hx, 0, hz), 0.12, trim_color)
		trim(c + Vector3(-hx, 0, hz), c + Vector3(-hx, 0, -hz), 0.12, trim_color)
	return body

## Annulus from base to base + height, built from convex sectors (pit walls, plazas).
func ring(base: Vector3, r_in: float, r_out: float, height: float, mat: Material, segments: int = 32) -> StaticBody3D:
	var hulls: Array[PackedVector3Array] = []
	var body := _new_body(base)
	for i in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var pts: PackedVector3Array = MapMeshUtil.sector_points(r_in, r_out, a0, a1, 0.0, 0.0, height, height)
		hulls.append(pts)
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		cs.shape = shape
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MapMeshUtil.commit_hulls(hulls, MapMeshUtil.sector_faces())
	mi.material_override = mat
	body.add_child(mi)
	return body

## Spiral ramp around a core. Top surface rises from y0 to y1 over `loops` turns.
func spiral_ramp(center: Vector3, r_in: float, r_out: float, y0: float, y1: float, loops: int, thickness: float, mat: Material, segs_per_loop: int = 24) -> StaticBody3D:
	var total: int = loops * segs_per_loop
	var hulls: Array[PackedVector3Array] = []
	var body := _new_body(center)
	for i in total:
		var ya: float = lerpf(y0, y1, float(i) / float(total))
		var yb: float = lerpf(y0, y1, float(i + 1) / float(total))
		var a0: float = TAU * float(i) / float(segs_per_loop)
		var a1: float = TAU * float(i + 1) / float(segs_per_loop)
		var pts: PackedVector3Array = MapMeshUtil.sector_points(r_in, r_out, a0, a1, ya - thickness, yb - thickness, ya, yb)
		hulls.append(pts)
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		cs.shape = shape
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MapMeshUtil.commit_hulls(hulls, MapMeshUtil.sector_faces())
	mi.material_override = mat
	body.add_child(mi)
	return body

## Enclosed tube (floor, two walls, ceiling). `start` is the floor center at the entrance.
## Returns the floor center at the exit.
func slide_tunnel(start: Vector3, direction: Vector3, length: float, slope_deg: float, width: float, height: float, mat: Material, trim_color: Color) -> Vector3:
	var dh := Vector3(direction.x, 0.0, direction.z).normalized()
	var slope: float = deg_to_rad(slope_deg)
	var dir3: Vector3 = dh * cos(slope) + Vector3.DOWN * sin(slope)
	var b: Basis = _basis_facing(dir3)
	var mid: Vector3 = start + dir3 * length * 0.5
	var up: Vector3 = b.y
	var side: Vector3 = b.x * (width * 0.5 + 0.25)
	box(mid - up * 0.25, Vector3(width + 1.0, 0.5, length), mat, b)
	box(mid + up * (height + 0.25), Vector3(width + 1.0, 0.5, length), mat, b)
	box(mid + side + up * (height * 0.5), Vector3(0.5, height, length), mat, b)
	box(mid - side + up * (height * 0.5), Vector3(0.5, height, length), mat, b)
	var end: Vector3 = start + dir3 * length
	for s in [-1.0, 1.0]:
		var off: Vector3 = b.x * (width * 0.5 - 0.1) * float(s) + up * (height - 0.1)
		trim(start + off, end + off, 0.1, trim_color)
	return end

## Repeated props with one MultiMesh and one StaticBody3D of shared shapes.
func multi_boxes(centers: Array[Vector3], size: Vector3, mat: Material) -> StaticBody3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	return _multi(centers, mesh, shape, mat)

func multi_cylinders(centers: Array[Vector3], radius: float, height: float, mat: Material) -> StaticBody3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _multi(centers, mesh, shape, mat)

func _multi(centers: Array[Vector3], mesh: Mesh, shape: Shape3D, mat: Material) -> StaticBody3D:
	if centers.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = centers.size()
	var body := _new_body(Vector3.ZERO)
	for i in centers.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, centers[i]))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = centers[i]
		body.add_child(cs)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	_geo.add_child(mmi)
	return body

# ---------------------------------------------------------------- visuals and triggers

## Thin emissive strip (visual only, no collision) that keeps edges readable at speed.
func trim(a: Vector3, b: Vector3, thickness: float, color: Color) -> MeshInstance3D:
	var d: Vector3 = b - a
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, d.length())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = palette.emissive_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geo.add_child(mi)
	mi.transform = Transform3D(_basis_facing(d), (a + b) * 0.5)
	return mi

func label_sign(pos: Vector3, text: String, color: Color, yaw: float = 0.0, size: float = 1.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.02 * size
	label.modulate = color
	label.outline_modulate = color.darkened(0.8)
	label.outline_size = 8
	label.shaded = false
	label.double_sided = true
	label.position = pos
	label.rotation.y = yaw
	_geo.add_child(label)
	return label

func jump_pad(pos: Vector3, launch_velocity: Vector3) -> JumpPad:
	var body := _new_body(pos)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.2
	mesh.bottom_radius = 1.2
	mesh.height = 0.12
	var shape := CylinderShape3D.new()
	shape.radius = 1.2
	shape.height = 0.12
	_add_part(body, mesh, shape, palette.emissive_material(palette.accent_color, 2.5), Vector3(0.0, 0.06, 0.0))
	var pad := JumpPad.new()
	pad.launch_velocity = launch_velocity
	pad.collision_layer = LAYER_TRIGGERS
	pad.collision_mask = LAYER_FIGHTERS
	var trigger := CollisionShape3D.new()
	var tshape := CylinderShape3D.new()
	tshape.radius = 1.1
	tshape.height = 1.0
	trigger.shape = tshape
	trigger.position = Vector3(0.0, 0.6, 0.0)
	pad.add_child(trigger)
	pad.position = pos
	_geo.add_child(pad)
	_pads.append({"pos": pos, "velocity": launch_velocity})
	return pad

## Jump pad that lands on `target`; also declares the JUMP_PAD navigation link.
func jump_pad_to(pos: Vector3, target: Vector3, apex_extra: float = 1.5) -> JumpPad:
	var v: Vector3 = ballistic_velocity(pos + Vector3(0.0, 0.12, 0.0), target, apex_extra)
	declare_link(WaypointGraph.LinkType.JUMP_PAD, pos, target)
	return jump_pad(pos, v)

## Glowing node that can be grappled (the grapple ray also works on any world surface).
func grapple_anchor(pos: Vector3) -> StaticBody3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var body := _new_body(pos)
	body.set_meta("no_nav", true)
	_add_part(body, mesh, shape, palette.emissive_material(palette.trim_color, 4.0))
	_anchors.append(pos)
	return body

## Anchor plus the GRAPPLE navigation link (from, anchor, to).
func grapple_link(from: Vector3, anchor: Vector3, to: Vector3) -> void:
	grapple_anchor(anchor)
	declare_link(WaypointGraph.LinkType.GRAPPLE, from, to, anchor)

func declare_link(type: int, from: Vector3, to: Vector3, anchor: Vector3 = Vector3.ZERO) -> void:
	_links.append({"type": type, "from": from, "to": to, "anchor": anchor})

func kill_volume(aabb: AABB, kind: String = "void", surface_color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> KillVolume:
	var kv := KillVolume.new()
	kv.kind = kind
	kv.collision_layer = LAYER_TRIGGERS
	kv.collision_mask = LAYER_FIGHTERS
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	cs.shape = shape
	kv.add_child(cs)
	kv.position = aabb.get_center()
	_geo.add_child(kv)
	_kill_volumes.append({"aabb": aabb, "kind": kind})
	if surface_color.a > 0.0:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(aabb.size.x, 0.1, aabb.size.z)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = palette.emissive_material(surface_color, 3.5)
		mi.position = Vector3(aabb.get_center().x, aabb.end.y - 0.05, aabb.get_center().z)
		_geo.add_child(mi)
	return kv

# ---------------------------------------------------------------- markers

func spawn(pos: Vector3, yaw: float) -> void:
	_spawns.append({"pos": pos, "yaw": yaw})

## Evenly spaced spawns on a circle, facing the center.
func spawn_ring(center: Vector3, radius: float, count: int, phase_deg: float = 0.0) -> void:
	for i in count:
		var a: float = deg_to_rad(phase_deg) + TAU * float(i) / float(count)
		var pos: Vector3 = center + Vector3(cos(a), 0.0, sin(a)) * radius
		spawn(pos, yaw_to(center - pos))

## `floor_pos` is the surface point; the stored marker hovers PICKUP_HOVER above it.
func pickup(type: String, floor_pos: Vector3) -> void:
	if not PICKUP_TYPES.has(type):
		push_error("Unknown pickup type: %s" % type)
		return
	_pickups.append({"type": type, "pos": floor_pos + Vector3(0.0, PICKUP_HOVER, 0.0)})
