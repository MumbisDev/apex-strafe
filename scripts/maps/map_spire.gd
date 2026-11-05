class_name MapSpire
extends MapBuilder
## Spire: vertical tower arena on a floating island. Falling off the island is death.

const ISLAND_R: float = 28.0
const TOWER_R: float = 6.0
const TOWER_H: float = 40.0
const SPIRAL_R_IN: float = 5.9
const SPIRAL_R_OUT: float = 12.0
const SPIRAL_TOP: float = 36.0
const SPIRAL_LOOPS: int = 3
const PLATFORM_HEIGHTS: Array[float] = [6.0, 10.0, 15.0, 20.0, 25.0, 29.0, 33.0, 36.0]
const PLATFORM_RADII: Array[float] = [20.0, 21.0, 20.0, 22.0, 20.0, 21.0, 20.0, 22.0]
const PLATFORM_SIZE: float = 8.0

var _trim: Color

func _init() -> void:
	map_id = "spire"
	map_name = "Spire"
	description = "Vertical tower arena: spiral ramp, floating platforms, jump pads and grapples."

func _make_palette() -> MapPalette:
	return MapPalette.spire()

func build(parent: Node3D) -> Dictionary:
	begin(parent)
	_trim = palette.trim_color
	_build_island_and_tower()
	var centers: Array[Vector3] = _build_platforms()
	_build_links(centers)
	_place_pickups(centers)
	spawn_ring(Vector3(0.0, 0.05, 0.0), 19.0, 16, 0.0)
	kill_volume(AABB(Vector3(-150.0, -90.0, -150.0), Vector3(300.0, 80.0, 300.0)), "void")
	return finish(AABB(Vector3(-ISLAND_R, -3.0, -ISLAND_R), Vector3(ISLAND_R * 2.0, TOWER_H + 12.0, ISLAND_R * 2.0)))

static func spiral_y(theta: float) -> float:
	return SPIRAL_TOP * theta / (float(SPIRAL_LOOPS) * TAU)

static func spiral_pos(theta: float, radius: float = 9.0) -> Vector3:
	return Vector3(cos(theta) * radius, spiral_y(theta), sin(theta) * radius)

static func platform_center(i: int) -> Vector3:
	var a: float = deg_to_rad(10.0 + 45.0 * float(i))
	var r: float = PLATFORM_RADII[i]
	return Vector3(cos(a) * r, PLATFORM_HEIGHTS[i], sin(a) * r)

func _build_island_and_tower() -> void:
	cylinder(Vector3(0, -1.0, 0), ISLAND_R, 2.0, m_floor)
	var prev := Vector3(ISLAND_R - 0.1, 0.03, 0.0)
	for i in range(1, 49):
		var a: float = TAU * float(i) / 48.0
		var cur := Vector3(cos(a) * (ISLAND_R - 0.1), 0.03, sin(a) * (ISLAND_R - 0.1))
		trim(prev, cur, 0.2, _trim)
		prev = cur
	cylinder(Vector3(0, TOWER_H * 0.5, 0), TOWER_R, TOWER_H, m_wall)
	for k in 4:
		var a: float = PI * 0.5 * float(k) + 0.4
		var p := Vector3(cos(a) * (TOWER_R + 0.05), 0.0, sin(a) * (TOWER_R + 0.05))
		trim(p, p + Vector3(0, TOWER_H, 0), 0.15, _trim)
	spiral_ramp(Vector3.ZERO, SPIRAL_R_IN, SPIRAL_R_OUT, 0.0, SPIRAL_TOP, SPIRAL_LOOPS, 0.6, m_floor)
	var rim_prev := Vector3(TOWER_R - 0.1, TOWER_H + 0.03, 0.0)
	for i in range(1, 25):
		var a: float = TAU * float(i) / 24.0
		var cur := Vector3(cos(a) * (TOWER_R - 0.1), TOWER_H + 0.03, sin(a) * (TOWER_R - 0.1))
		trim(rim_prev, cur, 0.15, _trim)
		rim_prev = cur

func _build_platforms() -> Array[Vector3]:
	var centers: Array[Vector3] = []
	for i in PLATFORM_HEIGHTS.size():
		var c: Vector3 = platform_center(i)
		centers.append(c)
		platform(c, Vector2(PLATFORM_SIZE, PLATFORM_SIZE), m_floor, _trim, 0.8)
	return centers

func _outward(c: Vector3) -> Vector3:
	return Vector3(c.x, 0.0, c.z).normalized()

func _next_dir(centers: Array[Vector3], i: int) -> Vector3:
	var j: int = (i + 1) % centers.size()
	var d: Vector3 = centers[j] - centers[i]
	return Vector3(d.x, 0.0, d.z).normalized()

func _build_links(centers: Array[Vector3]) -> void:
	# Island pad to the first platform; a pad on each platform hops to the next.
	var a0: float = deg_to_rad(10.0 - 20.0)
	jump_pad_to(Vector3(cos(a0) * 26.0, 0.0, sin(a0) * 26.0), centers[0] - _next_dir(centers, 0) * 1.5)
	for i in centers.size() - 1:
		var from: Vector3 = centers[i] + _next_dir(centers, i) * 3.0
		var to: Vector3 = centers[i + 1] - _next_dir(centers, i + 1) * 1.5
		jump_pad_to(from, to, 2.5)
		grapple_link(centers[i] - _outward(centers[i]) * 2.0, centers[i + 1] + Vector3(0, 7, 0), to)
	for i in centers.size():
		var edge: Vector3 = centers[i] + _outward(centers[i]) * 3.5
		var down: Vector3 = _outward(centers[i]) * minf(PLATFORM_RADII[i] + 4.0, ISLAND_R - 2.0)
		declare_link(WaypointGraph.LinkType.DROP, edge, Vector3(down.x, 0.0, down.z))
	# Summit: pad from the spiral end onto the tower top, grapple, and a drop back down.
	var theta_end: float = float(SPIRAL_LOOPS) * TAU - 0.35
	jump_pad_to(spiral_pos(theta_end), Vector3(-1.5, TOWER_H, 0.0), 3.5)
	grapple_link(spiral_pos(theta_end, 10.0), Vector3(0, TOWER_H + 6.0, 0), Vector3(2, TOWER_H, 0))
	declare_link(WaypointGraph.LinkType.DROP, Vector3(5, TOWER_H, 0), spiral_pos(float(SPIRAL_LOOPS) * TAU))

func _place_pickups(centers: Array[Vector3]) -> void:
	pickup(P_OVERCHARGE, Vector3(2.5, TOWER_H, 0))
	pickup(P_RAILGUN, Vector3(-2.5, TOWER_H, 0))
	pickup(P_PISTOL, Vector3(10, 0, 10))
	pickup(P_PISTOL, Vector3(-10, 0, -10))
	pickup(P_PORTAL, Vector3(0, TOWER_H * 0.5, 18))
	var kinds: Array[String] = [P_SMG, P_SHOTGUN, P_PLASMA, P_ROCKET, P_MEGA, P_HASTE, P_AMMO, P_AMMO]
	for i in centers.size():
		pickup(kinds[i], centers[i] + _outward(centers[i]) * 2.0)
	for k in 4:
		var a: float = deg_to_rad(45.0 + 90.0 * float(k))
		pickup(P_STIM, Vector3(cos(a) * 15.0, 0, sin(a) * 15.0))
	pickup(P_PLATE, Vector3(15, 0, 0))
	pickup(P_PLATE, Vector3(-15, 0, 0))
	pickup(P_MEDKIT, Vector3(0, 0, 24))
	pickup(P_MEDKIT, Vector3(0, 0, -24))
	pickup(P_SHARD, spiral_pos(PI))
	pickup(P_SHARD, spiral_pos(3.0 * PI))
	pickup(P_AMMO, Vector3(24, 0, 12))
	pickup(P_AMMO, Vector3(-24, 0, -12))
