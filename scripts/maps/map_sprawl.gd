class_name MapSprawl
extends MapBuilder
## Sprawl: 120 x 60 m neon city speed course. Surf ramps are skipped (FALLBACK, see DECISIONS.md).

const HALF_X: float = 60.0
const HALF_Z: float = 30.0
const ROW_W: float = 17.0
const ROW_GAP: float = 3.6
const ROW_STEP: float = 20.6
const ROW_DEPTH: float = 7.0
const N_ROOF: float = 14.0
const S_ROOF: float = 10.0
const BLOCK_H: float = 25.0
const TUNNEL_LEN: float = 18.0
const TUNNEL_SLOPE: float = 10.0
const SIGNS: Array[String] = ["NEON", "HOTEL", "RAMEN", "ARCADE", "VOID", "CLUB"]

var _teal: Color
var _pink: Color
var _building_mats: Array[Material] = []

func _init() -> void:
	map_id = "sprawl"
	map_name = "Sprawl"
	description = "Neon city speed course: long boulevards, slide tunnels, skywalks and wall-run towers."

func _make_palette() -> MapPalette:
	return MapPalette.sprawl()

func build(parent: Node3D) -> Dictionary:
	begin(parent)
	_teal = palette.trim_color
	_pink = palette.accent_color
	_building_mats = [m_wall, palette.material(Color(0.1, 0.13, 0.22)), palette.material(Color(0.2, 0.1, 0.2))]
	box(Vector3(0, -0.5, 0), Vector3(120, 1, 60), palette.glossy_floor_material())
	_build_perimeter()
	_build_rows()
	_build_blocks_and_plaza()
	_build_skywalks()
	_build_tunnels()
	_build_surf()
	_build_roads()
	_build_links()
	_place_spawns()
	_place_pickups()
	kill_volume(AABB(Vector3(-150.0, -60.0, -150.0), Vector3(300.0, 50.0, 300.0)), "void")
	return finish(AABB(Vector3(-HALF_X, -3.0, -HALF_Z), Vector3(HALF_X * 2.0, 34.0, HALF_Z * 2.0)))

static func gap_center(k: int) -> float:
	return -HALF_X + float(k) * ROW_STEP + ROW_W + ROW_GAP * 0.5

static func row_center(k: int) -> float:
	return -HALF_X + float(k) * ROW_STEP + ROW_W * 0.5

func _build_perimeter() -> void:
	wall(Vector3(-HALF_X - 1, 0, -HALF_Z - 0.5), Vector3(HALF_X + 1, 0, -HALF_Z - 0.5), 30.0, 1.0, m_wall)
	wall(Vector3(-HALF_X - 1, 0, HALF_Z + 0.5), Vector3(HALF_X + 1, 0, HALF_Z + 0.5), 30.0, 1.0, m_wall)
	wall(Vector3(-HALF_X - 0.5, 0, -HALF_Z), Vector3(-HALF_X - 0.5, 0, HALF_Z), 30.0, 1.0, m_wall)
	wall(Vector3(HALF_X + 0.5, 0, -HALF_Z), Vector3(HALF_X + 0.5, 0, HALF_Z), 30.0, 1.0, m_wall)

func _build_rows() -> void:
	for k in 6:
		_building(Vector3(row_center(k), 0.0, -26.5), N_ROOF, k, -1.0)
		_building(Vector3(row_center(k), 0.0, 26.5), S_ROOF, k + 1, 1.0)
	# Alleys: mantle crate steps (1.0 / 1.4 / 1.8 m) hugging one wall.
	var low: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var tall: Array[Vector3] = []
	for k in 5:
		for s in [-1.0, 1.0]:
			var x: float = gap_center(k) - 1.0
			low.append(Vector3(x, 0.5, float(s) * 24.0))
			mid.append(Vector3(x, 0.7, float(s) * 25.6))
			tall.append(Vector3(x, 0.9, float(s) * 27.2))
	multi_boxes(low, Vector3(1.2, 1.0, 1.2), m_accent)
	multi_boxes(mid, Vector3(1.2, 1.4, 1.2), m_accent)
	multi_boxes(tall, Vector3(1.2, 1.8, 1.2), m_accent)

func _building(base: Vector3, height: float, style: int, side: float) -> void:
	box(Vector3(base.x, height * 0.5, base.z), Vector3(ROW_W, height, ROW_DEPTH), _building_mats[style % 3])
	var face_z: float = base.z - side * ROW_DEPTH * 0.5
	var edge: Color = _teal if style % 2 == 0 else _pink
	trim(Vector3(base.x - ROW_W * 0.5, height + 0.05, face_z), Vector3(base.x + ROW_W * 0.5, height + 0.05, face_z), 0.25, edge)
	label_sign(Vector3(base.x, height * 0.55, face_z - side * 0.1), SIGNS[style % SIGNS.size()], edge, PI if side > 0.0 else 0.0, 1.5)

func _build_blocks_and_plaza() -> void:
	for s in [-1.0, 1.0]:
		var cx: float = float(s) * 33.0
		box(Vector3(cx, BLOCK_H * 0.5, 0), Vector3(38, BLOCK_H, 18), m_wall)
		for fz in [-1.0, 1.0]:
			var face: float = float(fz) * 9.05
			for h in [3.0, 12.0, 21.0]:
				trim(Vector3(cx - 19.0, h, face), Vector3(cx + 19.0, h, face), 0.25, _teal if h < 20.0 else _pink)
			label_sign(Vector3(cx, 16.5, face + float(fz) * 0.1), "WALL RUN", _teal, PI if fz < 0.0 else 0.0, 2.0)
	cylinder(Vector3(0, 0.5, 0), 3.0, 1.0, m_accent)
	cylinder(Vector3(0, 1.5, 0), 0.7, 3.0, m_accent)
	label_sign(Vector3(0, 4.5, 0), "SPRAWL", _pink, 0.0, 2.0)

func _build_skywalks() -> void:
	# Level 1 (y = 6): a ring over the plaza edge, reached by four boulevard stairs.
	var y: float = 5.7
	box(Vector3(0, y, -11), Vector3(26, 0.6, 4), m_floor)
	box(Vector3(0, y, 11), Vector3(26, 0.6, 4), m_floor)
	box(Vector3(-11, y, 0), Vector3(4, 0.6, 18), m_floor)
	box(Vector3(11, y, 0), Vector3(4, 0.6, 18), m_floor)
	for e in [-9.0, 9.0, -13.0, 13.0]:
		var x: float = float(e)
		var span: float = 13.0 if absf(x) > 10.0 else 9.0
		trim(Vector3(x, 6.03, -span), Vector3(x, 6.03, span), 0.15, _teal)
		trim(Vector3(-span, 6.03, x), Vector3(span, 6.03, x), 0.15, _teal)
	var pillars: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pillars.append(Vector3(11.0 * float(sx), 2.85, 11.0 * float(sz)))
	multi_cylinders(pillars, 0.5, 5.7, m_wall)
	for sz in [-11.0, 11.0]:
		stairs(Vector3(-23.4, 0, sz), 20, 0.3, 0.52, 4.0, m_floor, Vector3(1, 0, 0))
		stairs(Vector3(23.4, 0, sz), 20, 0.3, 0.52, 4.0, m_floor, Vector3(-1, 0, 0))
	# Level 2 (y = 12): stairs from the west ring side up to a deck over the plaza.
	stairs(Vector3(-9, 6, 0), 20, 0.3, 0.45, 4.0, m_floor, Vector3(1, 0, 0))
	box(Vector3(4.5, 11.7, 0), Vector3(9, 0.6, 4), m_floor)
	for e in [-1.95, 1.95]:
		trim(Vector3(-9, 6.05, float(e)), Vector3(0, 12.05, float(e)), 0.12, _pink)
		trim(Vector3(0, 12.05, float(e)), Vector3(9, 12.05, float(e)), 0.12, _pink)

func _build_tunnels() -> void:
	_tunnel_run(-58.0, -21.0, 1.0)
	_tunnel_run(58.0, -21.0, -1.0)
	_tunnel_run(-17.0, 21.0, 1.0)

## Entry ramp + plateau + 3 m x 2.2 m x 18 m tunnel sloped 10 degrees downhill.
func _tunnel_run(x0: float, z: float, dir_sign: float) -> void:
	var rise: float = TUNNEL_LEN * sin(deg_to_rad(TUNNEL_SLOPE))
	var d := Vector3(dir_sign, 0, 0)
	ramp(Vector3(x0 + dir_sign * 6.0, rise * 0.5, z), Vector3(3.0, rise, 12.0), d, m_floor)
	box(Vector3(x0 + dir_sign * 14.0, rise * 0.5, z), Vector3(4.0, rise, 3.0), m_floor)
	slide_tunnel(Vector3(x0 + dir_sign * 16.0, rise, z), d, TUNNEL_LEN, TUNNEL_SLOPE, 3.0, 2.2, m_wall, _teal)
	label_sign(Vector3(x0 + dir_sign * 15.0, rise + 3.0, z), "SLIDE", _pink, yaw_to(d), 1.0)

func _build_surf() -> void:
	## Contested surf lanes (pitch ~55–65°) near the plaza for movement expression.
	surf_ramp(Vector3(-40.0, 3.0, 0.0), Vector3(8.0, 0.4, 18.0), 58.0, 90.0)
	surf_ramp(Vector3(40.0, 3.0, 0.0), Vector3(8.0, 0.4, 18.0), 58.0, -90.0)
	label_sign(Vector3(-40.0, 8.0, 0.0), "SURF", _teal, deg_to_rad(90.0), 1.0)
	label_sign(Vector3(40.0, 8.0, 0.0), "SURF", _pink, deg_to_rad(-90.0), 1.0)

func _build_roads() -> void:
	for z in [-14.0, 14.0]:
		for i in 15:
			var x: float = -58.0 + 8.0 * float(i)
			trim(Vector3(x, 0.03, float(z)), Vector3(x + 4.0, 0.03, float(z)), 0.25, _pink)
		trim(Vector3(-58, 0.03, float(z) - 4.6), Vector3(58, 0.03, float(z) - 4.6), 0.2, _teal)
		trim(Vector3(-58, 0.03, float(z) + 4.6), Vector3(58, 0.03, float(z) + 4.6), 0.2, _teal)

func _build_links() -> void:
	var n_pad: float = row_center(3)
	var s_pad: float = row_center(4)
	jump_pad_to(Vector3(n_pad, 0, -17.5), Vector3(n_pad, N_ROOF, -26.5))
	jump_pad_to(Vector3(s_pad, 0, 17.5), Vector3(s_pad, S_ROOF, 26.5))
	grapple_link(Vector3(row_center(0), 0, -15), Vector3(row_center(0), N_ROOF + 2.5, -23.5), Vector3(row_center(0), N_ROOF, -26.5))
	grapple_link(Vector3(row_center(1), 0, 15), Vector3(row_center(1), S_ROOF + 2.5, 23.5), Vector3(row_center(1), S_ROOF, 26.5))
	for k in 6:
		var cx: float = row_center(k)
		declare_link(WaypointGraph.LinkType.DROP, Vector3(cx, N_ROOF, -24.5), Vector3(cx, 0, -17))
		declare_link(WaypointGraph.LinkType.DROP, Vector3(cx, S_ROOF, 24.5), Vector3(cx, 0, 17))
	for s in [-1.0, 1.0]:
		var bx: float = float(s) * 33.0
		grapple_link(Vector3(bx, 0, -14), Vector3(bx, BLOCK_H + 2.5, -9.5), Vector3(bx, BLOCK_H, -5))
		declare_link(WaypointGraph.LinkType.DROP, Vector3(bx, BLOCK_H, -8), Vector3(bx, 0, -14))

func _place_spawns() -> void:
	for z in [-15.5, 15.5]:
		for k in 8:
			var x: float = -49.0 + 14.0 * float(k)
			spawn(Vector3(x, 0.05, float(z)), yaw_to(Vector3(-signf(x), 0, 0)))

func _place_pickups() -> void:
	pickup(P_ROCKET, Vector3(6, 12, 0))
	pickup(P_RAILGUN, Vector3(35, S_ROOF, 26.5))
	pickup(P_SHOTGUN, Vector3(gap_center(0) + 0.6, 0, -28.4))
	pickup(P_SMG, Vector3(gap_center(4) + 0.6, 0, 28.4))
	pickup(P_PLASMA, Vector3(0, 0, -6))
	pickup(P_PISTOL, Vector3(-20, 0, 0))
	pickup(P_PISTOL, Vector3(20, 0, 0))
	pickup(P_PORTAL, Vector3(6, 6, 0))
	pickup(P_OVERCHARGE, Vector3(14, N_ROOF, -26.5))
	pickup(P_HASTE, Vector3(56, 0, 14))
	pickup(P_MEGA, Vector3(11, 6, 11))
	pickup(P_PLATE, Vector3(-56, 0, 14))
	pickup(P_PLATE, Vector3(56, 0, -14))
	pickup(P_STIM, Vector3(-56, 0, 0))
	pickup(P_STIM, Vector3(56, 0, 0))
	pickup(P_STIM, Vector3(-28, 0, -15.5))
	pickup(P_STIM, Vector3(28, 0, 15.5))
	pickup(P_MEDKIT, Vector3(gap_center(1) + 0.6, 0, -28.4))
	pickup(P_MEDKIT, Vector3(gap_center(3) + 0.6, 0, 28.4))
	pickup(P_AMMO, Vector3(gap_center(2) + 0.6, 0, -28.4))
	pickup(P_AMMO, Vector3(gap_center(2) + 0.6, 0, 28.4))
	pickup(P_AMMO, Vector3(gap_center(3) + 0.6, 0, -28.4))
	pickup(P_AMMO, Vector3(gap_center(1) + 0.6, 0, 28.4))
	pickup(P_SHARD, Vector3(-11, 6, -11))
	pickup(P_SHARD, Vector3(11, 6, -11))
	pickup(P_SHARD, Vector3(-11, 6, 11))
