class_name Speedometer
extends Control
## Bottom-center speedometer: numeric ups plus a half-arc bar whose color changes at 9, 14 and 20 m/s.

const MAX_SPEED: float = 28.0
const T1: float = 9.0
const T2: float = 14.0
const T3: float = 20.0
const ARC_RADIUS: float = 78.0

var speed: float = 0.0

static func color_for(ups: float) -> Color:
	if ups >= T3:
		return UITheme.ACCENT2
	if ups >= T2:
		return UITheme.WARN
	if ups >= T1:
		return UITheme.ACCENT
	return UITheme.TEXT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 100)

func set_speed(ups: float) -> void:
	if absf(ups - speed) < 0.05:
		return
	speed = ups
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y - 14.0)
	draw_arc(center, ARC_RADIUS, PI, TAU, 48, Color(UITheme.PANEL, 0.8), 8.0, true)
	var frac := clampf(speed / MAX_SPEED, 0.0, 1.0)
	var col := color_for(speed)
	if frac > 0.0:
		draw_arc(center, ARC_RADIUS, PI, PI + PI * frac, 48, col, 8.0, true)
	for t: float in [T1, T2, T3]:
		var a := PI + PI * (t / MAX_SPEED)
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (ARC_RADIUS - 7.0), center + dir * (ARC_RADIUS + 7.0), Color(1, 1, 1, 0.35), 1.5)
	var font := get_theme_default_font()
	var fsize := 40
	draw_string(font, center + Vector2(-60, -8), str(roundi(speed)), HORIZONTAL_ALIGNMENT_CENTER, 120.0, fsize, col)
	draw_string(font, center + Vector2(-60, 12), "m/s", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 14, UITheme.TEXT_DIM)
