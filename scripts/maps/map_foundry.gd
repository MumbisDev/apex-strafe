class_name MapFoundry
extends MapBuilder
## Foundry: 80 x 80 m industrial pit arena with a lava pit, gantry ring and wall-run walls.

const HALF: float = 40.0
const PIT_R: float = 14.0
const PIT_DEPTH: float = 6.0
const APRON_R: float = 20.0
const APRON_H: float = 0.15
const GANTRY_Y: float = 8.0
const G_IN: float = 29.0
const G_OUT: float = 36.0
const G_THICK: float = 0.8
const WALL_H: float = 24.0

var _trim: Color

func _init() -> void:
	map_id = "foundry"
	map_name = "Foundry"
	description = "Industrial pit arena: a lava pit, a gantry ring and long wall-run walls."

func _make_palette() -> MapPalette:
	return MapPalette.foundry()

func build(parent: Node3D) -> Dictionary:
	begin(parent)
	_trim = palette.trim_color
	_build_floor_and_pit()
	_build_gantry()
	_build_walls()
	_build_props()
	_build_side_room(Vector3(-32.5, 0.0, -32.5), -1.0)
	_build_side_room(Vector3(32.5, 0.0, 32.5), 1.0)
	_build_movement_aids()
	spawn_ring(Vector3(0.0, 0.05, 0.0), 26.0, 16, 11.25)
	_place_pickups()
	kill_volume(AABB(Vector3(-150.0, -60.0, -150.0), Vector3(300.0, 48.0, 300.0)), "void")
	return finish(AABB(Vector3(-HALF, -PIT_DEPTH - 1.0, -HALF), Vector3(HALF * 2.0, 40.0, HALF * 2.0)))

func _build_floor_and_pit() -> void:
	box(Vector3(0, -0.5, -27), Vector3(80, 1, 26), m_floor)
	box(Vector3(0, -0.5, 27), Vector3(80, 1, 26), m_floor)
	box(Vector3(-27, -0.5, 0), Vector3(26, 1, 28), m_floor)
	box(Vector3(27, -0.5, 0), Vector3(26, 1, 28), m_floor)
	box(Vector3(0, -PIT_DEPTH - 0.5, 0), Vector3(28, 1, 28), m_floor)
	ring(Vector3(0, -PIT_DEPTH, 0), PIT_R, APRON_R, PIT_DEPTH + APRON_H, m_floor)
	kill_volume(AABB(Vector3(-14, -6.5, -14), Vector3(28, 2.5, 28)), "lava", Color(1.0, 0.3, 0.05))
	var prev: Vector3 = Vector3(PIT_R, APRON_H + 0.02, 0.0)
	for i in range(1, 33):
		var a: float = TAU * float(i) / 32.0
		var cur := Vector3(cos(a) * PIT_R, APRON_H + 0.02, sin(a) * PIT_R)
		trim(prev, cur, 0.15, _trim)
		prev = cur
	for s in [-1.0, 1.0]:
		box(Vector3(float(s) * 9.5, -0.3, 0.0), Vector3(10.0, 0.6, 5.0), m_floor)
		box(Vector3(0.0, -0.3, float(s) * 9.5), Vector3(5.0, 0.6, 10.0), m_floor)
		for e in [-2.4, 2.4]:
			trim(Vector3(float(s) * 4.6, 0.02, float(e)), Vector3(float(s) * 14.4, 0.02, float(e)), 0.1, _trim)
			trim(Vector3(float(e), 0.02, float(s) * 4.6), Vector3(float(e), 0.02, float(s) * 14.4), 0.1, _trim)
	platform(Vector3(0, 0.12, 0), Vector2(9, 9), m_floor, _trim, 0.8)

func _build_gantry() -> void:
	var y: float = GANTRY_Y - G_THICK * 0.5
	var mid: float = (G_IN + G_OUT) * 0.5
	var width: float = G_OUT - G_IN
	box(Vector3(0, y, -mid), Vector3(G_OUT * 2.0, G_THICK, width), m_floor)
	box(Vector3(0, y, mid), Vector3(G_OUT * 2.0, G_THICK, width), m_floor)
	box(Vector3(-mid, y, 0), Vector3(width, G_THICK, G_IN * 2.0), m_floor)
	box(Vector3(mid, y, 0), Vector3(width, G_THICK, G_IN * 2.0), m_floor)
	var ty: float = GANTRY_Y + 0.02
	trim(Vector3(-G_IN, ty, -G_IN), Vector3(G_IN, ty, -G_IN), 0.15, _trim)
	trim(Vector3(G_IN, ty, -G_IN), Vector3(G_IN, ty, G_IN), 0.15, _trim)
	trim(Vector3(G_IN, ty, G_IN), Vector3(-G_IN, ty, G_IN), 0.15, _trim)
	trim(Vector3(-G_IN, ty, G_IN), Vector3(-G_IN, ty, -G_IN), 0.15, _trim)
	var supports: Array[Vector3] = []
	for s in [-1.0, 1.0]:
		for t in [-16.0, 16.0]:
			supports.append(Vector3(float(s) * mid, 3.6, float(t)))
			supports.append(Vector3(float(t), 3.6, float(s) * mid))
	multi_cylinders(supports, 0.6, 7.2, m_wall)
	# Four pinwheel corner ramps and two stair runs reach the gantry.
	var rise: float = GANTRY_Y
	ramp(Vector3(19, 4, -26), Vector3(6, rise, 20), Vector3(1, 0, 0), m_floor)
	ramp(Vector3(-26, 4, -19), Vector3(6, rise, 20), Vector3(0, 0, -1), m_floor)
	ramp(Vector3(-19, 4, 26), Vector3(6, rise, 20), Vector3(-1, 0, 0), m_floor)
	ramp(Vector3(26, 4, 19), Vector3(6, rise, 20), Vector3(0, 0, 1), m_floor)
	stairs(Vector3(-16.35, 0, 0), 23, rise / 23.0, 0.55, 4.0, m_floor, Vector3(-1, 0, 0))
	stairs(Vector3(16.35, 0, 0), 23, rise / 23.0, 0.55, 4.0, m_floor, Vector3(1, 0, 0))

func _build_walls() -> void:
	var c: Vector3 = Vector3(0, 0, 0)
	wall(c + Vector3(-HALF - 1, 0, -HALF - 0.5), c + Vector3(HALF + 1, 0, -HALF - 0.5), WALL_H, 1.0, m_wall)
	wall(c + Vector3(-HALF - 1, 0, HALF + 0.5), c + Vector3(HALF + 1, 0, HALF + 0.5), WALL_H, 1.0, m_wall)
	wall(c + Vector3(-HALF - 0.5, 0, -HALF), c + Vector3(-HALF - 0.5, 0, HALF), WALL_H, 1.0, m_wall)
	wall(c + Vector3(HALF + 0.5, 0, -HALF), c + Vector3(HALF + 0.5, 0, HALF), WALL_H, 1.0, m_wall)
	# Smooth wall-run walls (40 m long, 12 m high) with route trims. Face at z = +-38.5.
	for s in [-1.0, 1.0]:
		var z: float = float(s) * 39.0
		wall(Vector3(-20, 0, z), Vector3(20, 0, z), 12.0, 1.0, m_wall)
		var face: float = float(s) * 38.45
		for h in [3.0, 6.5]:
			trim(Vector3(-20, h, face), Vector3(20, h, face), 0.2, _trim)
		label_sign(Vector3(0, 9.0, face), "WALL-RUN", _trim, PI if s > 0.0 else 0.0, 2.0)

func _build_props() -> void:
	var pillars: Array[Vector3] = []
	for k in 8:
		var a: float = deg_to_rad(22.5 + 45.0 * float(k))
		pillars.append(Vector3(cos(a) * 22.0, 3.0, sin(a) * 22.0))
	multi_cylinders(pillars, 0.9, 6.0, m_wall)
	# Crate clusters: mantle-friendly 1.0 / 1.4 / 1.8 m steps.
	var low: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var tall: Array[Vector3] = []
	var origins: Array[Vector4] = [Vector4(6, -32.5, 1, 0), Vector4(-6, 32.5, 1, 0), Vector4(-32.5, -8, 0, 1), Vector4(32.5, 6, 0, 1)]
	for o in origins:
		var step := Vector3(o.z, 0.0, o.w) * 1.9
		var base := Vector3(o.x, 0.0, o.y)
		low.append(base + Vector3(0, 0.5, 0))
		mid.append(base + step + Vector3(0, 0.7, 0))
		tall.append(base + step * 2.0 + Vector3(0, 0.9, 0))
	multi_boxes(low, Vector3(1.8, 1.0, 1.8), m_accent)
	multi_boxes(mid, Vector3(1.8, 1.4, 1.8), m_accent)
	multi_boxes(tall, Vector3(1.8, 1.8, 1.8), m_accent)

## Raised side room under a gantry corner. `s` is -1 for NW, +1 for SE; the doorway faces the arena.
func _build_side_room(c: Vector3, s: float) -> void:
	var floor_y: float = 2.0
	var h: float = 4.0
	platform(Vector3(c.x, floor_y, c.z), Vector2(7, 7), m_floor, _trim, 0.4)
	var o: float = 3.3
	wall(Vector3(c.x + s * o, floor_y, c.z - 3.5), Vector3(c.x + s * o, floor_y, c.z + 3.5), h, 0.4, m_wall)
	wall(Vector3(c.x - 3.5, floor_y, c.z + s * o), Vector3(c.x + 3.5, floor_y, c.z + s * o), h, 0.4, m_wall)
	wall(Vector3(c.x - 3.5, floor_y, c.z - s * o), Vector3(c.x + 3.5, floor_y, c.z - s * o), h, 0.4, m_wall)
	var e: float = c.x - s * o
	wall(Vector3(e, floor_y, c.z - 3.5), Vector3(e, floor_y, c.z - 1.2), h, 0.4, m_wall)
	wall(Vector3(e, floor_y, c.z + 1.2), Vector3(e, floor_y, c.z + 3.5), h, 0.4, m_wall)
	box(Vector3(c.x, floor_y + h + 0.2, c.z), Vector3(7, 0.4, 7), m_wall)
	ramp(Vector3(c.x - s * 6.5, 1.0, c.z), Vector3(2.4, 2.0, 6.0), Vector3(s, 0, 0), m_floor)

func _build_movement_aids() -> void:
	# Jump pads: mega platform and gantry.
	jump_pad_to(Vector3(3.6, 0.12, 0), Vector3(0, 4, 0))
	jump_pad_to(Vector3(-3.6, 0.12, 0), Vector3(0, 4, 0))
	jump_pad_to(Vector3(0, 0, -25), Vector3(0, GANTRY_Y, -32.5))
	jump_pad_to(Vector3(0, 0, 25), Vector3(0, GANTRY_Y, 32.5))
	jump_pad_to(Vector3(-25, 0, 10), Vector3(-32.5, GANTRY_Y, 10))
	jump_pad_to(Vector3(25, 0, -10), Vector3(32.5, GANTRY_Y, -10))
	# Grapple anchors: above the mega platform and over each gantry corner.
	platform(Vector3(0, 4.0, 0), Vector2(4, 4), m_floor, _trim, 0.4)
	grapple_link(Vector3(0, 0.12, 3), Vector3(0, 11, 0), Vector3(0, 4, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			grapple_link(Vector3(20.0 * sx, 0, 20.0 * sz), Vector3(27.0 * sx, 13, 27.0 * sz), Vector3(32.5 * sx, GANTRY_Y, 27.0 * sz))

func _place_pickups() -> void:
	pickup(P_ROCKET, Vector3(32.5, GANTRY_Y, -32.5))
	pickup(P_RAILGUN, Vector3(-32.5, GANTRY_Y, 32.5))
	pickup(P_OVERCHARGE, Vector3(-32.5, 2.0, -32.5))
	pickup(P_HASTE, Vector3(-17, 0, 37.2))
	pickup(P_SHOTGUN, Vector3(-22, 0, 6))
	pickup(P_SMG, Vector3(22, 0, -6))
	pickup(P_PLASMA, Vector3(0, 0.12, -2))
	pickup(P_PISTOL, Vector3(12, 0, 12))
	pickup(P_PISTOL, Vector3(-12, 0, -12))
	pickup(P_PORTAL, Vector3(0, GANTRY_Y, 0))
	pickup(P_MEGA, Vector3(0, 4, 0))
	pickup(P_PLATE, Vector3(-32.5, GANTRY_Y, -32.5))
	pickup(P_PLATE, Vector3(32.5, GANTRY_Y, 32.5))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pickup(P_STIM, Vector3(20.0 * sx, 0, 20.0 * sz))
	pickup(P_MEDKIT, Vector3(0, GANTRY_Y, -32.5))
	pickup(P_MEDKIT, Vector3(0, GANTRY_Y, 32.5))
	pickup(P_MEDKIT, Vector3(32.5, 2.0, 32.5))
	pickup(P_SHARD, Vector3(-32.5, GANTRY_Y, 0))
	pickup(P_SHARD, Vector3(32.5, GANTRY_Y, 0))
	for p in [Vector3(0, 0, -9.5), Vector3(0, 0, 9.5), Vector3(-9.5, 0, 0), Vector3(9.5, 0, 0)]:
		pickup(P_AMMO, p as Vector3)
