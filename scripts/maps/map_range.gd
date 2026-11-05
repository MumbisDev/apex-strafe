class_name MapRange
extends MapBuilder
## Practice range. A 60 x 40 m central hall (lobby + weapon rack) with a shooting gallery that
## extends west to 70 m targets, and a movement course that extends east (80 m straightaway).
## Dummies, the weapon rack and the lap course are returned as data; gameplay nodes consume them.

const X_WEST: float = -112.0
const X_EAST: float = 112.0
const HALL_Z: float = 20.0
const FIRING_X: float = -34.0
const GALLERY_DISTANCES: Array[float] = [10.0, 20.0, 40.0, 70.0]
const LANE_Z: Array[float] = [-15.0, -5.0, 5.0, 15.0]
const DUMMY_KINDS: Array[String] = ["static", "moving", "strafing", "popup"]
const WEAPON_NAMES: Array[String] = [
	"BLADE", "ARC PISTOL", "SMG", "SHOTGUN", "PLASMA", "ROCKET", "RAILGUN", "PORTAL",
]
const GATE_XS: Array[float] = [45.0, 65.0, 85.0, 105.0]

var _trim: Color

func _init() -> void:
	map_id = "range"
	map_name = "Practice Range"
	description = "Shooting gallery with moving targets and a movement course with a timed lap."

func _make_palette() -> MapPalette:
	return MapPalette.practice()

func build(parent: Node3D) -> Dictionary:
	begin(parent)
	_trim = palette.trim_color
	_build_shell()
	var dummies: Array[Dictionary] = _build_gallery()
	var rack: Array[Dictionary] = _build_weapon_rack()
	var course: Dictionary = _build_course()
	_place_spawns_and_pickups()
	kill_volume(AABB(Vector3(-200.0, -60.0, -100.0), Vector3(420.0, 50.0, 200.0)), "void")
	var extra: Dictionary = {
		"dummies": dummies, "weapon_rack": rack, "course": course,
		"sparring_spawns": [
			{"pos": Vector3(-50, 0.05, 0), "yaw": yaw_to(Vector3(1, 0, 0))},
			{"pos": Vector3(-60, 0.05, 10), "yaw": yaw_to(Vector3(1, 0, 0))},
			{"pos": Vector3(-60, 0.05, -10), "yaw": yaw_to(Vector3(1, 0, 0))},
		],
	}
	return finish(AABB(Vector3(-113, -4, -21), Vector3(226, 22, 42)), extra)

func _build_shell() -> void:
	box(Vector3(-41, -0.5, 0), Vector3(142, 1, 40), m_floor)
	box(Vector3(71, -0.5, -7), Vector3(82, 1, 14), m_floor)
	box(Vector3(37, -0.5, 7), Vector3(14, 1, 14), m_floor)
	box(Vector3(84, -0.5, 7), Vector3(56, 1, 14), m_floor)
	var hall_h: float = 12.0
	wall(Vector3(X_WEST - 1, 0, -HALL_Z - 0.5), Vector3(31, 0, -HALL_Z - 0.5), hall_h, 1.0, m_wall)
	wall(Vector3(X_WEST - 1, 0, HALL_Z + 0.5), Vector3(31, 0, HALL_Z + 0.5), hall_h, 1.0, m_wall)
	wall(Vector3(X_WEST - 0.5, 0, -HALL_Z), Vector3(X_WEST - 0.5, 0, HALL_Z), hall_h, 1.0, m_wall)
	wall(Vector3(30.5, 0, -HALL_Z), Vector3(30.5, 0, -14), hall_h, 1.0, m_wall)
	wall(Vector3(30.5, 0, -0.5), Vector3(30.5, 0, 0.5), hall_h, 1.0, m_wall)
	wall(Vector3(30.5, 0, 14), Vector3(30.5, 0, HALL_Z), hall_h, 1.0, m_wall)
	wall(Vector3(31, 0, -14.5), Vector3(X_EAST + 0.5, 0, -14.5), 10.0, 1.0, m_wall)
	wall(Vector3(31, 0, 14.5), Vector3(X_EAST + 0.5, 0, 14.5), 10.0, 1.0, m_wall)
	wall(Vector3(X_EAST + 0.5, 0, -15), Vector3(X_EAST + 0.5, 0, 15), 10.0, 1.0, m_wall)
	wall(Vector3(31, 0, 0), Vector3(110, 0, 0), 5.0, 0.6, m_wall)
	label_sign(Vector3(-15, 7, -19.8), "PRACTICE RANGE", _trim, 0.0, 3.0)

func _build_gallery() -> Array[Dictionary]:
	var dummies: Array[Dictionary] = []
	trim(Vector3(FIRING_X, 0.03, -HALL_Z), Vector3(FIRING_X, 0.03, HALL_Z), 0.3, palette.accent_color)
	label_sign(Vector3(FIRING_X, 3.0, 0.0), "FIRING LINE", palette.accent_color, PI * 0.5, 1.5)
	for i in GALLERY_DISTANCES.size():
		var d: float = GALLERY_DISTANCES[i]
		var x: float = FIRING_X - d
		trim(Vector3(x, 0.03, -HALL_Z), Vector3(x, 0.03, HALL_Z), 0.15, Color(0.8, 0.85, 0.9))
		label_sign(Vector3(x + 0.5, 3.0, 0.0), "%d M" % int(d), Color(0.9, 0.95, 1.0), PI * 0.5, 1.5)
		for j in LANE_Z.size():
			dummies.append(_dummy(DUMMY_KINDS[(i + j) % DUMMY_KINDS.size()], Vector3(x, 0.0, LANE_Z[j]), d))
	box(Vector3(X_WEST + 2.0, 3.0, 0.0), Vector3(1.0, 6.0, 38.0), m_accent)
	return dummies

func _dummy(kind: String, pos: Vector3, distance: float) -> Dictionary:
	var amp: float = 0.0
	var speed: float = 0.0
	match kind:
		"moving":
			amp = 3.0
			speed = 3.0
		"strafing":
			amp = 4.0
			speed = 6.0
	var rail_a: Vector3 = pos + Vector3(0, 0, -amp)
	var rail_b: Vector3 = pos + Vector3(0, 0, amp)
	if amp > 0.0:
		trim(rail_a + Vector3(0, 0.04, 0), rail_b + Vector3(0, 0.04, 0), 0.12, Color(0.8, 0.85, 0.9))
	return {
		"kind": kind, "pos": pos, "distance": distance, "rail_a": rail_a, "rail_b": rail_b,
		"speed": speed, "popup_interval": 2.5 if kind == "popup" else 0.0,
	}

func _build_weapon_rack() -> Array[Dictionary]:
	var rack: Array[Dictionary] = []
	box(Vector3(-18, 0.5, -19.0), Vector3(16, 1.0, 1.0), m_accent)
	for i in WEAPON_NAMES.size():
		var x: float = -24.0 + 2.0 * float(i)
		box(Vector3(x, 1.3, -19.0), Vector3(1.4, 0.4, 0.5), palette.material(Color(0.12, 0.13, 0.16)))
		label_sign(Vector3(x, 2.1, -19.7), "%d %s" % [i + 1, WEAPON_NAMES[i]], _trim, 0.0, 0.5)
		rack.append({"slot": i + 1, "pos": Vector3(x, 1.5, -19.0)})
	label_sign(Vector3(-18, 4.0, -19.9), "T: INFINITE AMMO", palette.accent_color, 0.0, 1.5)
	return rack

func _speed_gate(pos: Vector3) -> Dictionary:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 2.0
	mesh.outer_radius = 2.25
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = palette.emissive_material(palette.accent_color, 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(0, 0, 90)
	mi.position = pos
	_geo.add_child(mi)
	return {"pos": pos, "radius": 2.0}

func _checkpoint(cp_name: String, pos: Vector3, size: Vector3) -> Dictionary:
	return {"name": cp_name, "pos": pos, "size": size}

func _build_course() -> Dictionary:
	var gates: Array[Dictionary] = []
	# Wall-run corridor (30 m) feeding the 80 m bunnyhop straightaway.
	for z in [-10.0, -4.0]:
		wall(Vector3(0, 0, z), Vector3(30, 0, z), 8.0, 0.6, m_wall)
		var face: float = z + (0.31 if z < -7.0 else -0.31)
		for h in [3.0, 5.5]:
			trim(Vector3(0, h, face), Vector3(30, h, face), 0.15, _trim)
	trim(Vector3(1, 0.03, -10), Vector3(1, 0.03, -4), 0.3, palette.accent_color)
	trim(Vector3(31, 0.03, -13.8), Vector3(111, 0.03, -13.8), 0.2, _trim)
	trim(Vector3(31, 0.03, -0.2), Vector3(111, 0.03, -0.2), 0.2, _trim)
	for x in GATE_XS:
		gates.append(_speed_gate(Vector3(x, 1.8, -7.0)))
	label_sign(Vector3(34, 4.0, -13.8), "BUNNYHOP 80 M", _trim, PI * 0.5, 1.5)
	# Return lane: slide tunnel, mantle crate steps, grapple chasm.
	slide_tunnel(Vector3(106, 0, 7), Vector3(-1, 0, 0), 18.0, 0.0, 3.0, 2.2, m_wall, _trim)
	box(Vector3(106.25, 3, 2.5), Vector3(0.5, 6, 5.0), m_wall)
	box(Vector3(106.25, 3, 11.5), Vector3(0.5, 6, 5.0), m_wall)
	var heights: Array[float] = [1.0, 1.4, 1.8]
	for i in heights.size():
		box(Vector3(78.0 - 4.0 * float(i), heights[i] * 0.5, 7.0), Vector3(1.5, heights[i], 13.8), m_accent)
	kill_volume(AABB(Vector3(44, -8, 0), Vector3(12, 6, 14)), "void")
	var pillars: Array[Vector3] = [Vector3(43, 5, 2), Vector3(43, 5, 12), Vector3(57, 5, 2), Vector3(57, 5, 12)]
	multi_cylinders(pillars, 0.8, 10.0, m_wall)
	grapple_link(Vector3(57.5, 0, 7), Vector3(43, 10.6, 2), Vector3(41, 0, 7))
	grapple_link(Vector3(41, 0, 7), Vector3(57, 10.6, 12), Vector3(58.5, 0, 7))
	trim(Vector3(4, 0.03, 0.5), Vector3(4, 0.03, 13.5), 0.3, palette.accent_color)
	var checkpoints: Array[Dictionary] = [
		_checkpoint("start", Vector3(1, 1.5, -7), Vector3(1, 3, 6)),
		_checkpoint("wallrun_exit", Vector3(31.5, 2, -7), Vector3(1, 4, 13)),
		_checkpoint("straightaway_end", Vector3(108, 2, -7), Vector3(1, 4, 13)),
		_checkpoint("tunnel_exit", Vector3(87, 2, 7), Vector3(1, 4, 13)),
		_checkpoint("mantle_end", Vector3(66, 2, 7), Vector3(1, 4, 13)),
		_checkpoint("chasm_far", Vector3(40, 2, 7), Vector3(1, 4, 13)),
		_checkpoint("finish", Vector3(4, 1.5, 7), Vector3(1, 3, 13)),
	]
	return {"checkpoints": checkpoints, "gates": gates, "record_key": "range_lap"}

func _place_spawns_and_pickups() -> void:
	for z in LANE_Z:
		for x in [-26.0, -20.0, -14.0, -8.0]:
			spawn(Vector3(float(x), 0.05, z), yaw_to(Vector3(-1, 0, 0)))
	pickup(P_STIM, Vector3(-28, 0, -17))
	pickup(P_STIM, Vector3(-28, 0, 17))
	pickup(P_MEDKIT, Vector3(-2, 0, 17))
	pickup(P_PLATE, Vector3(-2, 0, -14))
	pickup(P_AMMO, Vector3(-12, 0, 18))
