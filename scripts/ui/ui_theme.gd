class_name UITheme
extends RefCounted

const BG := Color("#0E1118")
const PANEL := Color("#161B26")
const ACCENT := Color("#19E3FF")
const ACCENT2 := Color("#FF2E88")
const WARN := Color("#FFB020")
const TEXT := Color("#EAF0FF")
const TEXT_DIM := Color("#8A93A8")

const BOT_COLORS: Array[Color] = [
	Color("#FF4D4D"), Color("#4D9FFF"), Color("#4DFF88"), Color("#FFD24D"),
	Color("#FF4DD2"), Color("#4DFFE9"), Color("#B84DFF"), Color("#FF8A4D"),
	Color("#4DFFD2"), Color("#D2FF4D"), Color("#FF6B9D"), Color("#6B9DFF"),
]

static func build() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial", "DejaVu Sans"])
	t.default_font = font
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	var sb := _flat(PANEL, ACCENT)
	var sb_hover := _flat(PANEL.lightened(0.08), ACCENT)
	var sb_pressed := _flat(PANEL.darkened(0.1), ACCENT2)
	var sb_disabled := _flat(PANEL.darkened(0.2), TEXT_DIM)
	t.set_stylebox("normal", "Button", sb)
	t.set_stylebox("hover", "Button", sb_hover)
	t.set_stylebox("pressed", "Button", sb_pressed)
	t.set_stylebox("disabled", "Button", sb_disabled)
	t.set_stylebox("focus", "Button", sb_hover)
	t.set_stylebox("panel", "PanelContainer", _flat(PANEL, Color(0, 0, 0, 0)))
	t.set_stylebox("panel", "Panel", _flat(PANEL, Color(0, 0, 0, 0)))
	t.set_constant("h_separation", "BoxContainer", 8)
	t.set_constant("v_separation", "BoxContainer", 8)
	return t

## Shared flat box for HUD widgets (panels, bars, chips).
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, radius: int = 6, margin: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

## Themed button with hover scale (1.03 over 0.1 s, pause-safe), hover/click sounds and a press handler.
static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 44)
	b.pressed.connect(func() -> void:
		Audio.play_ui("ui_click")
		on_press.call()
	)
	b.mouse_entered.connect(func() -> void: _hover(b, true, true))
	b.mouse_exited.connect(func() -> void: _hover(b, false, false))
	b.focus_entered.connect(func() -> void: _hover(b, true, false))
	b.focus_exited.connect(func() -> void: _hover(b, false, false))
	return b

static func _hover(b: Button, on: bool, sound: bool) -> void:
	if on and sound and not b.disabled:
		Audio.play_ui("ui_hover")
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(b, "scale", Vector2.ONE * (1.03 if on else 1.0), 0.1)

static func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
