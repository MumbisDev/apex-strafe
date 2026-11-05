class_name WaypointGraph
extends RefCounted
## AStar3D waypoint graph generated from physics queries against the `world` layer.
## Link metadata lives in `links` (key = from_id * KEY_MUL + to_id).

enum LinkType { WALK, JUMP, DROP, GRAPPLE, JUMP_PAD, WALLRUN }

const GRID_STEP: float = 3.0
const MAX_POINTS: int = 1200
const LINK_RADIUS: float = 4.5
const MAX_LEVELS: int = 10
const FLOOR_MIN_NORMAL_Y: float = 0.7
const CLEARANCE: float = 1.9
const WALK_MAX_DY: float = 0.4
const WALK_MAX_SLOPE_DEG: float = 40.0
const WALK_SURFACE_TOLERANCE: float = 0.25
const JUMP_MAX_DY: float = 1.6
const DROP_MAX_DY: float = 8.0
const CAP_RADIUS: float = 0.35
const CAP_HEIGHT: float = 1.6
const CAP_LIFT: float = 0.35
const SNAP_RADIUS: float = 3.5
const MARKER_MERGE: float = 1.5
const VERIFY_RADIUS: float = 3.0
const WORLD_MASK: int = 1
const KEY_MUL: int = 1000000
const PENALTY: Dictionary = {
	LinkType.JUMP: 2.0, LinkType.DROP: 1.0, LinkType.GRAPPLE: 4.0,
	LinkType.JUMP_PAD: 2.0, LinkType.WALLRUN: 3.0,
}

class _Star extends AStar3D:
	var penalty: Dictionary = {}

	func _compute_cost(from_id: int, to_id: int) -> float:
		var base: float = get_point_position(from_id).distance_to(get_point_position(to_id))
		return base + float(penalty.get(from_id * WaypointGraph.KEY_MUL + to_id, 0.0))

var astar: AStar3D = _Star.new()
var links: Dictionary = {}
var stats: Dictionary = {}

var _adj: Dictionary = {}
var _cells: Dictionary = {}
var _kill: Array[AABB] = []
var _space: PhysicsDirectSpaceState3D
var _ray: PhysicsRayQueryParameters3D
var _sweep: PhysicsShapeQueryParameters3D

static func link_key(from_id: int, to_id: int) -> int:
	return from_id * KEY_MUL + to_id

## Generates the graph for `data` (the Dictionary returned by a map's build()).
## The map must already be in the tree and physics must have processed one frame.
func generate(world: World3D, data: Dictionary) -> bool:
	var t0: int = Time.get_ticks_usec()
	_space = world.direct_space_state
	_ray = PhysicsRayQueryParameters3D.new()
	_ray.collision_mask = WORLD_MASK
	_sweep = PhysicsShapeQueryParameters3D.new()
	_sweep.collision_mask = WORLD_MASK
	var cap := CapsuleShape3D.new()
	cap.radius = CAP_RADIUS
	cap.height = CAP_HEIGHT
	_sweep.shape = cap
	var wp: Dictionary = data["waypoints"]
	var bounds: AABB = wp["bounds"]
	_kill.assign(wp["kill_aabbs"] as Array)
	var spawns: Array = data["spawns"]
	var pickups: Array = data["pickups"]
	var pts: Array[Vector3] = _sample_floor(bounds, GRID_STEP)
	if pts.size() > MAX_POINTS:
		pts = _sample_floor(bounds, GRID_STEP * sqrt(float(pts.size()) / float(MAX_POINTS)) * 1.05)
	_add_marker_points(pts, spawns)
	_add_marker_points(pts, pickups)
	for p in pts:
		_add_point(p)
	_link_neighbors()
	var unresolved: int = _add_declared(wp["links"] as Array)
	var removed: int = _prune(spawns)
	stats = {
		"points": astar.get_point_count(), "links": links.size(), "pruned": removed,
		"unresolved_declared": unresolved, "types": count_by_type(),
		"build_ms": float(Time.get_ticks_usec() - t0) / 1000.0,
	}
	return astar.get_point_count() > 0

func point_count() -> int:
	return astar.get_point_count()

func link_count() -> int:
	return links.size()

func count_by_type() -> Dictionary:
	var out: Dictionary = {}
	for info in links.values():
		var type_name: String = LinkType.keys()[int((info as Dictionary)["type"])]
		out[type_name] = int(out.get(type_name, 0)) + 1
	return out

func link_info(from_id: int, to_id: int) -> Dictionary:
	return links.get(link_key(from_id, to_id), {}) as Dictionary

func nearest_point(pos: Vector3) -> int:
	return astar.get_closest_point(pos)

func find_id_path(from_pos: Vector3, to_pos: Vector3) -> PackedInt64Array:
	return astar.get_id_path(nearest_point(from_pos), nearest_point(to_pos))

func find_path(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	return astar.get_point_path(nearest_point(from_pos), nearest_point(to_pos))

## Returns human-readable problems; empty when every marker is within 3 m of a waypoint.
func verify(spawns: Array, pickups: Array) -> Array[String]:
	var problems: Array[String] = []
	for entry in spawns:
		_check_marker("spawn", (entry as Dictionary)["pos"] as Vector3, problems)
	for entry in pickups:
		var d: Dictionary = entry
		_check_marker("pickup %s" % str(d["type"]), d["pos"] as Vector3, problems)
	return problems

func _check_marker(label: String, pos: Vector3, problems: Array[String]) -> void:
	var id: int = _nearest_within(pos, VERIFY_RADIUS)
	if id < 0:
		problems.append("%s at %s has no waypoint within %.1f m" % [label, str(pos), VERIFY_RADIUS])

# ---------------------------------------------------------------- sampling

func _sample_floor(bounds: AABB, step: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x: float = bounds.position.x + step * 0.5
	while x < bounds.end.x:
		var z: float = bounds.position.z + step * 0.5
		while z < bounds.end.z:
			_sample_column(x, z, bounds, out)
			z += step
		x += step
	return out

func _sample_column(x: float, z: float, bounds: AABB, out: Array[Vector3]) -> void:
	var y: float = bounds.end.y
	for i in MAX_LEVELS:
		_ray.from = Vector3(x, y, z)
		_ray.to = Vector3(x, bounds.position.y, z)
		var hit: Dictionary = _space.intersect_ray(_ray)
		if hit.is_empty():
			return
		var p: Vector3 = hit["position"]
		var n: Vector3 = hit["normal"]
		var col: Object = hit["collider"]
		var ignore: bool = col != null and col.has_meta("no_nav")
		var floor_hit: bool = not ignore and n.y > FLOOR_MIN_NORMAL_Y
		if floor_hit and _has_clearance(p) and not _in_kill(p):
			out.append(p)
		y = p.y - (0.3 if floor_hit else 0.05)

func _has_clearance(p: Vector3) -> bool:
	_ray.from = p + Vector3(0.0, 0.05, 0.0)
	_ray.to = p + Vector3(0.0, CLEARANCE, 0.0)
	var hit: Dictionary = _space.intersect_ray(_ray)
	if hit.is_empty():
		return true
	var col: Object = hit["collider"]
	return col != null and col.has_meta("no_nav")

func _in_kill(p: Vector3) -> bool:
	for box in _kill:
		if box.grow(0.5).has_point(p):
			return true
	return false

## Guarantees a waypoint near every spawn/pickup even when the 3 m grid misses a small platform.
func _add_marker_points(pts: Array[Vector3], markers: Array) -> void:
	for entry in markers:
		var pos: Vector3 = (entry as Dictionary)["pos"]
		_ray.from = pos + Vector3(0.0, 0.5, 0.0)
		_ray.to = pos - Vector3(0.0, 3.0, 0.0)
		var hit: Dictionary = _space.intersect_ray(_ray)
		if hit.is_empty():
			continue
		var p: Vector3 = hit["position"]
		var covered: bool = false
		for q in pts:
			if q.distance_to(p) < MARKER_MERGE:
				covered = true
				break
		if not covered and _has_clearance(p):
			pts.append(p)

func _add_point(p: Vector3) -> int:
	var id: int = astar.get_available_point_id()
	astar.add_point(id, p)
	_adj[id] = []
	var cell := _cell(p)
	if not _cells.has(cell):
		_cells[cell] = []
	(_cells[cell] as Array).append(id)
	return id

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / LINK_RADIUS), floori(p.z / LINK_RADIUS))

# ---------------------------------------------------------------- linking

func _link_neighbors() -> void:
	for id in astar.get_point_ids():
		var c: Vector2i = _cell(astar.get_point_position(id))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var bucket: Array = _cells.get(Vector2i(c.x + dx, c.y + dz), []) as Array
				for other in bucket:
					if int(other) > id:
						_try_link(id, int(other))

func _try_link(a: int, b: int) -> void:
	var pa: Vector3 = astar.get_point_position(a)
	var pb: Vector3 = astar.get_point_position(b)
	var h: float = Vector2(pb.x - pa.x, pb.z - pa.z).length()
	if h > LINK_RADIUS:
		return
	var dy: float = pb.y - pa.y
	var ady: float = absf(dy)
	var lo: int = a if dy >= 0.0 else b
	var hi: int = b if dy >= 0.0 else a
	if _surface_walkable(pa, pb, h, ady) and _path_clear(pa, pb):
		_connect(a, b, LinkType.WALK, true)
		return
	if ady < WALK_MAX_DY:
		if _level_clear(pa, pb):
			_connect(a, b, LinkType.JUMP, true)
		return
	if ady <= JUMP_MAX_DY and _jump_clear(astar.get_point_position(lo), astar.get_point_position(hi)):
		_connect(lo, hi, LinkType.JUMP, false)
	if ady <= DROP_MAX_DY and _drop_clear(astar.get_point_position(hi), astar.get_point_position(lo)):
		_connect(hi, lo, LinkType.DROP, false)

## WALK: a continuous floor between the points, flat (< 0.4 m) or a walkable slope.
func _surface_walkable(pa: Vector3, pb: Vector3, h: float, ady: float) -> bool:
	if ady >= WALK_MAX_DY and rad_to_deg(atan2(ady, maxf(h, 0.01))) > WALK_MAX_SLOPE_DEG:
		return false
	var mid: Vector3 = (pa + pb) * 0.5
	_ray.from = Vector3(mid.x, maxf(pa.y, pb.y) + 0.6, mid.z)
	_ray.to = Vector3(mid.x, minf(pa.y, pb.y) - 0.6, mid.z)
	var hit: Dictionary = _space.intersect_ray(_ray)
	if hit.is_empty():
		return false
	var p: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	return absf(p.y - mid.y) <= WALK_SURFACE_TOLERANCE and n.y > FLOOR_MIN_NORMAL_Y

func _capsule_clear(from: Vector3, to: Vector3) -> bool:
	var lift := Vector3(0.0, CAP_LIFT + CAP_HEIGHT * 0.5, 0.0)
	_sweep.transform = Transform3D(Basis.IDENTITY, from + lift)
	_sweep.motion = to - from
	var res: PackedFloat32Array = _space.cast_motion(_sweep)
	return res.size() >= 2 and res[0] >= 0.999

func _path_clear(pa: Vector3, pb: Vector3) -> bool:
	return _capsule_clear(pa, pb)

func _level_clear(pa: Vector3, pb: Vector3) -> bool:
	var y: float = maxf(pa.y, pb.y)
	return _capsule_clear(Vector3(pa.x, y, pa.z), Vector3(pb.x, y, pb.z))

func _jump_clear(lo: Vector3, hi: Vector3) -> bool:
	var above := Vector3(lo.x, hi.y, lo.z)
	return _capsule_clear(lo, above) and _capsule_clear(above, hi)

func _drop_clear(hi: Vector3, lo: Vector3) -> bool:
	var out := Vector3(lo.x, hi.y, lo.z)
	return _capsule_clear(hi, out) and _capsule_clear(out, lo)

func _connect(a: int, b: int, type: int, bidirectional: bool, anchor: Vector3 = Vector3.ZERO) -> void:
	_connect_one(a, b, type, anchor)
	if bidirectional:
		_connect_one(b, a, type, anchor)

func _connect_one(a: int, b: int, type: int, anchor: Vector3) -> void:
	var key: int = link_key(a, b)
	if links.has(key):
		return
	links[key] = {"type": type, "anchor": anchor}
	astar.connect_points(a, b, false)
	(astar as _Star).penalty[key] = float(PENALTY.get(type, 0.0))
	(_adj[a] as Array).append(b)
	(_adj[b] as Array).append(a)

func _nearest_within(pos: Vector3, radius: float) -> int:
	var best: int = -1
	var best_d: float = radius
	for id in astar.get_point_ids():
		var d: float = astar.get_point_position(id).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = id
	return best

## Resolves map-declared GRAPPLE / JUMP_PAD / DROP links. Returns how many failed to snap.
func _add_declared(declared: Array) -> int:
	var unresolved: int = 0
	for entry in declared:
		var l: Dictionary = entry
		var from_id: int = _nearest_within(l["from"] as Vector3, SNAP_RADIUS)
		var to_id: int = _nearest_within(l["to"] as Vector3, SNAP_RADIUS)
		if from_id < 0 or to_id < 0 or from_id == to_id:
			unresolved += 1
			continue
		_connect(from_id, to_id, int(l["type"]), false, l["anchor"] as Vector3)
	return unresolved

## Keeps the connected component holding the most spawns. Returns the removed point count.
func _prune(spawns: Array) -> int:
	var comp: Dictionary = {}
	var sizes: Array[int] = []
	for id in astar.get_point_ids():
		if comp.has(id):
			continue
		var index: int = sizes.size()
		var stack: Array[int] = [id]
		comp[id] = index
		var count: int = 0
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			count += 1
			for nb in _adj[cur] as Array:
				if not comp.has(int(nb)):
					comp[int(nb)] = index
					stack.append(int(nb))
		sizes.append(count)
	if sizes.is_empty():
		return 0
	var votes: Array[int] = []
	votes.resize(sizes.size())
	votes.fill(0)
	for entry in spawns:
		var sid: int = _nearest_within((entry as Dictionary)["pos"] as Vector3, VERIFY_RADIUS)
		if sid >= 0:
			votes[int(comp[sid])] += 1
	var keep: int = 0
	for i in sizes.size():
		if votes[i] > votes[keep] or (votes[i] == votes[keep] and sizes[i] > sizes[keep]):
			keep = i
	var removed: int = 0
	for id in astar.get_point_ids():
		if int(comp[id]) != keep:
			astar.remove_point(id)
			_adj.erase(id)
			removed += 1
	for key in links.keys():
		var k: int = int(key)
		if not astar.has_point(k / KEY_MUL) or not astar.has_point(k % KEY_MUL):
			links.erase(key)
	return removed
