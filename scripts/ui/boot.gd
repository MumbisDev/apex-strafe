extends Control

var _t: float = 0.0
var _done: bool = false
var _logo: Label
var _stripe: ColorRect

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = UITheme.build()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	_logo = Label.new()
	_logo.text = "APEX STRAFE"
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_logo.set_anchors_preset(PRESET_FULL_RECT)
	_logo.add_theme_font_size_override("font_size", 64)
	_logo.add_theme_color_override("font_color", UITheme.ACCENT)
	add_child(_logo)
	_stripe = ColorRect.new()
	_stripe.color = UITheme.ACCENT2
	_stripe.size = Vector2(0, 4)
	_stripe.position = Vector2(0, size.y * 0.55)
	add_child(_stripe)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var w := get_viewport_rect().size.x * clampf(_t / 1.0, 0.0, 1.0)
	_stripe.size = Vector2(w, 4)
	_stripe.position = Vector2((get_viewport_rect().size.x - w) * 0.5, get_viewport_rect().size.y * 0.58)
	if _t >= 1.2:
		_finish()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_finish()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	Game.go_menu()
