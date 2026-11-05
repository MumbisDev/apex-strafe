class_name Crosshair
extends Control
## Dynamic crosshair: dot/cross/circle/chevron styles, bloom, grapple ring, hit markers, damage arcs.

const STYLES: Array[String] = ["dot", "cross", "circle", "chevron"]
const BLOOM_MAX: float = 18.0
const BLOOM_RECOVER_TIME: float = 0.25
const HIT_TIME: float = 0.22
const INDICATOR_TIME: float = 1.0
const MAX_INDICATORS: int = 8
const ARM_LENGTH: float = 8.0
const COLOR_HIT: Color = Color(1, 1, 1)
const COLOR_KILL: Color = Color("#FF3B3B")
const COLOR_HEAD: Color = Color("#FFD24D")
const COLOR_OUTLINE: Color = Color(0, 0, 0, 0.75)

var style: String = "cross"
var color: Color = Color(1, 1, 1, 0.9)
var size_scale: float = 1.0
var thickness: float = 2.0
var gap: float = 4.0
var opacity: float = 0.9
var outline: bool = true
var hit_markers_enabled: bool = true
var base_spread: float = 0.0 ## px, static spread of the equipped weapon
var grapple_ready: float = 1.0 ## 0..1, ring shows while < 1

var _bloom: float = 0.0
var _hit_t: float = 0.0
var _hit_color: Color = COLOR_HIT
var _indicators: Array[Vector2] = [] ## x = angle (0 = ahead, +right), y = age

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply_settings()

func apply_settings() -> void:
	style = Settings.crosshair_style if STYLES.has(Settings.crosshair_style) else "cross"
	color = Settings.crosshair_color
	size_scale = Settings.crosshair_size
	thickness = Settings.crosshair_thickness
	gap = Settings.crosshair_gap
	opacity = Settings.crosshair_opacity
	outline = Settings.crosshair_outline
	hit_markers_enabled = Settings.hit_markers
	queue_redraw()

## Adds bloom (px) for one shot; recovers over BLOOM_RECOVER_TIME.
func kick(px: float) -> void:
	_bloom = minf(BLOOM_MAX, _bloom + px)

func show_hit(is_kill: bool, is_head: bool) -> void:
	if not hit_markers_enabled:
		return
	_hit_color = COLOR_HEAD if is_head else (COLOR_KILL if is_kill else COLOR_HIT)
	_hit_t = HIT_TIME

## angle: radians relative to view direction, 0 = attacker ahead, positive = to the right.
func add_damage_indicator(angle: float) -> void:
	if _indicators.size() >= MAX_INDICATORS:
		_indicators.remove_at(0)
	_indicators.append(Vector2(angle, 0.0))

func get_indicator_count() -> int:
	return _indicators.size()

func get_bloom() -> float:
	return _bloom

func is_hit_marker_active() -> bool:
	return _hit_t > 0.0

func _process(delta: float) -> void:
	_bloom = maxf(0.0, _bloom - BLOOM_MAX / BLOOM_RECOVER_TIME * delta)
	_hit_t = maxf(0.0, _hit_t - delta)
	var i := _indicators.size() - 1
	while i >= 0:
		var ind := _indicators[i]
		ind.y += delta
		if ind.y >= INDICATOR_TIME:
			_indicators.remove_at(i)
		else:
			_indicators[i] = ind
		i -= 1
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var col := Color(color.r, color.g, color.b, color.a * opacity)
	var spread := (gap + base_spread + _bloom) * size_scale
	var arm := ARM_LENGTH * size_scale
	match style:
		"dot":
			if outline:
				draw_circle(c, thickness * size_scale + 2.0, COLOR_OUTLINE)
			draw_circle(c, thickness * size_scale + 0.5, col)
		"circle":
			var r := spread + arm * 0.5
			if outline:
				draw_arc(c, r, 0.0, TAU, 48, COLOR_OUTLINE, thickness + 2.0, true)
			draw_arc(c, r, 0.0, TAU, 48, col, thickness, true)
			draw_circle(c, 1.0, col)
		"chevron":
			var apex := c + Vector2(0, spread * 0.5)
			_seg(apex, apex + Vector2(-arm, arm), col)
			_seg(apex, apex + Vector2(arm, arm), col)
		_:
			_seg(c + Vector2(-spread - arm, 0), c + Vector2(-spread, 0), col)
			_seg(c + Vector2(spread, 0), c + Vector2(spread + arm, 0), col)
			_seg(c + Vector2(0, -spread - arm), c + Vector2(0, -spread), col)
			_seg(c + Vector2(0, spread), c + Vector2(0, spread + arm), col)
	_draw_grapple_ring(c, spread + arm + 8.0)
	_draw_hit_marker(c)
	_draw_indicators(c)

func _seg(a: Vector2, b: Vector2, col: Color) -> void:
	if outline:
		draw_line(a, b, COLOR_OUTLINE, thickness + 2.0)
	draw_line(a, b, col, thickness)

func _draw_grapple_ring(c: Vector2, radius: float) -> void:
	if grapple_ready >= 1.0:
		return
	draw_arc(c, radius, 0.0, TAU, 48, Color(UITheme.TEXT_DIM, 0.25), 1.5, true)
	var end := -PI * 0.5 + TAU * clampf(grapple_ready, 0.0, 1.0)
	draw_arc(c, radius, -PI * 0.5, end, 48, Color(UITheme.ACCENT, 0.85), 1.5, true)

func _draw_hit_marker(c: Vector2) -> void:
	if _hit_t <= 0.0:
		return
	var k := _hit_t / HIT_TIME
	var col := Color(_hit_color.r, _hit_color.g, _hit_color.b, k)
	var r1 := 6.0 + (1.0 - k) * 3.0
	var r2 := r1 + 7.0
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_line(c + d * r1, c + d * r2, Color(0, 0, 0, k * 0.6), 4.0)
		draw_line(c + d * r1, c + d * r2, col, 2.0)

func _draw_indicators(c: Vector2) -> void:
	for ind in _indicators:
		var a := ind.x - PI * 0.5
		var alpha := 1.0 - ind.y / INDICATOR_TIME
		draw_arc(c, 84.0, a - 0.28, a + 0.28, 12, Color(1.0, 0.18, 0.18, alpha), 6.0, true)
