class_name MapMeshUtil
extends RefCounted
## Static helpers that build flat-shaded convex meshes from point and face lists.
## Faces are wound automatically so normals point away from the hull center.

static func add_hull(st: SurfaceTool, points: PackedVector3Array, faces: Array[PackedInt32Array]) -> void:
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	for face in faces:
		for i in range(1, face.size() - 1):
			var a: Vector3 = points[face[0]]
			var b: Vector3 = points[face[i]]
			var c: Vector3 = points[face[i + 1]]
			var n: Vector3 = (c - a).cross(b - a)
			if n.dot((a + b + c) / 3.0 - center) < 0.0:
				var tmp: Vector3 = b
				b = c
				c = tmp
				n = (c - a).cross(b - a)
			if n.length_squared() < 0.000001:
				continue
			n = n.normalized()
			for v in [a, b, c]:
				st.set_normal(n)
				st.add_vertex(v as Vector3)

static func commit_hulls(hulls: Array[PackedVector3Array], faces: Array[PackedInt32Array]) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pts in hulls:
		add_hull(st, pts, faces)
	return st.commit()

## Ramp wedge. size = (width, rise, run). High end at local -Z, low end at +Z.
static func ramp_points(size: Vector3) -> PackedVector3Array:
	var h: Vector3 = size * 0.5
	return PackedVector3Array([
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
	])

static func ramp_faces() -> Array[PackedInt32Array]:
	return [
		PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([0, 1, 5, 4]),
		PackedInt32Array([3, 2, 5, 4]), PackedInt32Array([0, 3, 4]),
		PackedInt32Array([1, 2, 5]),
	]

## Eight-point wedge between two angles of an annulus (used by rings and spirals).
## bottom/top heights are given at the start angle (0) and end angle (1).
static func sector_points(r_in: float, r_out: float, a0: float, a1: float, bot0: float, bot1: float, top0: float, top1: float) -> PackedVector3Array:
	var c0: float = cos(a0)
	var s0: float = sin(a0)
	var c1: float = cos(a1)
	var s1: float = sin(a1)
	return PackedVector3Array([
		Vector3(r_in * c0, bot0, r_in * s0), Vector3(r_in * c1, bot1, r_in * s1),
		Vector3(r_out * c1, bot1, r_out * s1), Vector3(r_out * c0, bot0, r_out * s0),
		Vector3(r_in * c0, top0, r_in * s0), Vector3(r_in * c1, top1, r_in * s1),
		Vector3(r_out * c1, top1, r_out * s1), Vector3(r_out * c0, top0, r_out * s0),
	])

static func sector_faces() -> Array[PackedInt32Array]:
	return [
		PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([4, 5, 6, 7]),
		PackedInt32Array([0, 1, 5, 4]), PackedInt32Array([1, 2, 6, 5]),
		PackedInt32Array([2, 3, 7, 6]), PackedInt32Array([3, 0, 4, 7]),
	]
