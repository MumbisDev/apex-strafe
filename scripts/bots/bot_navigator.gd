class_name BotNavigator
extends RefCounted
## Path following over the map's WaypointGraph (an AStar3D, GDD Section 11).
## Optional `link_source` object supplies link metadata by duck typing:
##   get_link_type(from_id: int, to_id: int) -> int   (LINK_* values below)
##   get_link_anchor(from_id: int, to_id: int) -> Vector3   (GRAPPLE links)
## Without metadata, links are inferred from height (a step up of 0.45 m+ is a JUMP).
## Without a graph the navigator steers straight at the destination.

const LINK_WALK := 0
const LINK_JUMP := 1
const LINK_DROP := 2
const LINK_GRAPPLE := 3
const LINK_WALLRUN := 4

const ARRIVAL_RADIUS := 1.5
const VERTICAL_TOLERANCE := 2.5
const REPATH_INTERVAL := 0.5
const PATH_BUDGET_PER_TICK := 2 ## global, shared by every bot
const STRAIGHT_DEG := 20.0
const SLIDE_MIN_SPEED := 6.5
const SLIDE_MIN_RUN := 8.0
const CORNER_BLEND := 0.35

static var _budget_frame: int = -1
static var _budget_used: int = 0
static var denied_requests: int = 0 ## debug: requests deferred by the budget

const JUMP_MIN_STEP := 0.45
const JUMP_MAX_STEP := 2.2

var graph: AStar3D
var link_source: Object = null
var profile: BotProfile
var has_destination: bool = false
var destination: Vector3 = Vector3.ZERO
var last_request_ok: bool = true

## Outputs, valid after `update()`.
var move_dir: Vector3 = Vector3.ZERO ## horizontal, normalized, or zero
var jump_now: bool = false ## one-tick flags
var slide_now: bool = false
var grapple_now: bool = false
var wallrun_ok: bool = false ## current segment is a WALLRUN link
var grapple_anchor: Vector3 = Vector3.ZERO
var arrived: bool = false
var straight_deg: float = 0.0

var _pts: PackedVector3Array = PackedVector3Array()
var _ids: PackedInt64Array = PackedInt64Array()
var _index: int = 0
var _dirty: bool = false
var _last_request: float = -999.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _link_rolls: Dictionary = {} ## link key -> bool (skill gate, rolled once per link)
var _slide_ok: bool = false
var _slide_roll_t: float = 0.0
var _slide_cd: float = 0.0

func _init(g: AStar3D, p: BotProfile, seed_value: int = 1, links: Object = null) -> void:
	graph = g
	profile = p
	link_source = links
	_rng.seed = seed_value

## Finds the AStar3D inside whatever the map produced: an AStar3D, a WaypointGraph, or the
## dictionary `WaypointGraph.generate()` returns (key "astar"), optionally nested under "waypoints".
static func graph_from(source: Variant) -> AStar3D:
	if source is AStar3D:
		return source as AStar3D
	if source is WaypointGraph:
		return (source as WaypointGraph).astar
	if source is Dictionary:
		var d := source as Dictionary
		if d.has("astar"):
			return graph_from(d["astar"])
		if d.has("waypoints"):
			return graph_from(d["waypoints"])
	return null

## Looks for a graph on a map/match scene root (`waypoint_graph` property/meta or `map_data`).
static func graph_from_map(map_root: Node) -> AStar3D:
	if map_root == null:
		return null
	for prop in ["waypoint_graph", "map_data", "astar"]:
		var v: Variant = map_root.get(prop)
		if v != null:
			var g: AStar3D = graph_from(v)
			if g != null:
				return g
		if map_root.has_meta(prop):
			var g2: AStar3D = graph_from(map_root.get_meta(prop))
			if g2 != null:
				return g2
	return null

## Global per-physics-tick path query budget. `frame < 0` uses the engine's physics frame.
static func try_consume_budget(frame: int = -1) -> bool:
	var f: int = Engine.get_physics_frames() if frame < 0 else frame
	if f != _budget_frame:
		_budget_frame = f
		_budget_used = 0
	if _budget_used >= PATH_BUDGET_PER_TICK:
		denied_requests += 1
		return false
	_budget_used += 1
	return true

static func reset_budget() -> void:
	_budget_frame = -1
	_budget_used = 0
	denied_requests = 0

func set_destination(dest: Vector3) -> void:
	if has_destination and dest.distance_to(destination) < 2.0:
		return
	destination = dest
	has_destination = true
	_dirty = true

func clear_destination() -> void:
	has_destination = false
	_pts = PackedVector3Array()
	_ids = PackedInt64Array()
	_index = 0
	_dirty = false
	move_dir = Vector3.ZERO

func force_repath() -> void:
	_dirty = true

func path_points_left() -> PackedVector3Array:
	if _index >= _pts.size():
		return PackedVector3Array()
	return _pts.slice(_index)

func path_length_left(pos: Vector3) -> float:
	var total: float = 0.0
	var prev: Vector3 = pos
	for i in range(_index, _pts.size()):
		total += prev.distance_to(_pts[i])
		prev = _pts[i]
	return total

func update(dt: float, now: float, pos: Vector3, vel: Vector3, frame: int = -1) -> void:
	jump_now = false
	slide_now = false
	grapple_now = false
	wallrun_ok = false
	arrived = false
	_slide_cd = maxf(0.0, _slide_cd - dt)
	_slide_roll_t -= dt
	if _slide_roll_t <= 0.0:
		_slide_roll_t = 1.5
		_slide_ok = _rng.randf() < profile.slide_usage
	if not has_destination:
		move_dir = Vector3.ZERO
		return
	if _dirty or now - _last_request >= REPATH_INTERVAL:
		if try_consume_budget(frame):
			_request(pos, now)
	_follow(pos, vel)

func _request(pos: Vector3, now: float) -> void:
	_last_request = now
	_dirty = false
	if graph == null or graph.get_point_count() == 0:
		_set_path(PackedVector3Array([destination]), PackedInt64Array([-1]), pos)
		last_request_ok = true
		return
	var a: int = graph.get_closest_point(pos)
	var b: int = graph.get_closest_point(destination)
	var ids: PackedInt64Array = PackedInt64Array()
	if a >= 0 and b >= 0:
		ids = graph.get_id_path(a, b)
	if ids.is_empty() or not _skill_allows(ids):
		last_request_ok = false
		return
	var pts := PackedVector3Array()
	for id in ids:
		pts.append(graph.get_point_position(id))
	var out_ids: PackedInt64Array = ids.duplicate()
	if pts[pts.size() - 1].distance_to(destination) > ARRIVAL_RADIUS:
		pts.append(destination)
		out_ids.append(-1)
	last_request_ok = true
	_set_path(pts, out_ids, pos)

func _set_path(pts: PackedVector3Array, ids: PackedInt64Array, pos: Vector3) -> void:
	_pts = pts
	_ids = ids
	_index = 0
	## Skip a first node that lies behind us (new paths start at the closest waypoint).
	if _pts.size() >= 2 and pos.distance_to(_pts[1]) < _pts[0].distance_to(_pts[1]):
		_index = 1

## GRAPPLE / WALLRUN links are only walked when the bot's usage roll for that link passed.
func _skill_allows(ids: PackedInt64Array) -> bool:
	for i in range(ids.size() - 1):
		var link: int = _classify(int(ids[i]), int(ids[i + 1]))
		var usage: float = 1.0
		if link == LINK_GRAPPLE:
			usage = profile.grapple_usage
		elif link == LINK_WALLRUN:
			usage = profile.wallrun_usage
		else:
			continue
		var key: int = int(ids[i]) * 1000003 + int(ids[i + 1])
		if not _link_rolls.has(key):
			_link_rolls[key] = _rng.randf() < usage
		if not bool(_link_rolls[key]):
			return false
	return true

## Link type between two graph point ids (metadata if available, else inferred from height).
func _classify(from_id: int, to_id: int) -> int:
	if link_source != null and link_source.has_method("get_link_type"):
		return int(link_source.call("get_link_type", from_id, to_id))
	if graph == null or not graph.has_point(from_id) or not graph.has_point(to_id):
		return LINK_WALK
	return _infer(graph.get_point_position(from_id), graph.get_point_position(to_id))

static func _infer(a: Vector3, b: Vector3) -> int:
	var step: float = b.y - a.y
	if step >= JUMP_MIN_STEP and step <= JUMP_MAX_STEP:
		return LINK_JUMP
	if step < -JUMP_MIN_STEP:
		return LINK_DROP
	return LINK_WALK

func _follow(pos: Vector3, vel: Vector3) -> void:
	if _pts.is_empty():
		move_dir = Vector3.ZERO ## waiting for a path (budget) or the request failed
		return
	while _index < _pts.size() and _reached(pos, _pts[_index]):
		_on_arrive(_index)
		_index += 1
	if _index >= _pts.size():
		arrived = true
		move_dir = Vector3.ZERO
		straight_deg = 0.0
		return
	var cur: Vector3 = _pts[_index]
	var to_cur: Vector3 = _flat(cur - pos).normalized()
	var dir: Vector3 = to_cur
	straight_deg = 0.0
	if _index + 1 < _pts.size():
		var seg: Vector3 = _flat(_pts[_index + 1] - cur)
		if seg.length_squared() > 0.01 and to_cur.length_squared() > 0.0:
			straight_deg = rad_to_deg(to_cur.angle_to(seg.normalized()))
			var here: int = _link_at(_index)
			if here == LINK_WALK or here == LINK_DROP:
				dir = (to_cur * (1.0 - CORNER_BLEND) + seg.normalized() * CORNER_BLEND).normalized()
	move_dir = dir
	wallrun_ok = _link_at(_index - 1) == LINK_WALLRUN
	var speed: float = _flat(vel).length()
	if speed > SLIDE_MIN_SPEED and _slide_ok and _slide_cd <= 0.0 and straight_deg < STRAIGHT_DEG:
		var downhill: bool = _index + 1 < _pts.size() and _pts[_index + 1].y < pos.y - 1.0
		if downhill or path_length_left(pos) > SLIDE_MIN_RUN:
			slide_now = true
			_slide_cd = 1.5

func _on_arrive(i: int) -> void:
	match _link_at(i):
		LINK_JUMP:
			jump_now = true
		LINK_GRAPPLE:
			grapple_now = true
			if link_source != null and link_source.has_method("get_link_anchor") and i + 1 < _ids.size():
				grapple_anchor = link_source.call("get_link_anchor", int(_ids[i]), int(_ids[i + 1])) as Vector3

## Link type from path node i to node i + 1.
func _link_at(i: int) -> int:
	if i < 0 or i + 1 >= _pts.size():
		return LINK_WALK
	var a: int = int(_ids[i])
	var b: int = int(_ids[i + 1])
	if a < 0 or b < 0:
		return LINK_WALK ## straight leg to the off-graph destination
	return _classify(a, b)

func _reached(pos: Vector3, p: Vector3) -> bool:
	return _flat(p - pos).length() <= ARRIVAL_RADIUS and absf(p.y - pos.y) < VERTICAL_TOLERANCE

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

## --- Graph queries used by goal code -------------------------------------------------

func nearest_waypoint(pos: Vector3) -> Vector3:
	if graph == null or graph.get_point_count() == 0:
		return pos
	return graph.get_point_position(graph.get_closest_point(pos))

func sample_waypoints(count: int, rng: RandomNumberGenerator) -> PackedVector3Array:
	var out := PackedVector3Array()
	if graph == null or graph.get_point_count() == 0:
		return out
	var ids: PackedInt64Array = graph.get_point_ids()
	for i in count:
		out.append(graph.get_point_position(ids[rng.randi_range(0, ids.size() - 1)]))
	return out
