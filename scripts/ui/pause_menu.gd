class_name PauseMenu
extends Control
## Pause overlay: Resume, Restart Match, Settings (embedded), Quit to Menu (with confirm).
## Lives in its own CanvasLayer so it draws above the HUD; the layer follows this Control's visibility.

const LAYER: int = 20
const SETTINGS_SCRIPT: String = "res://scripts/ui/settings_menu.gd"

var _layer: CanvasLayer
var _root: Control
var _main_panel: Control
var _confirm_panel: Control
var _settings: Control
var _resume_btn: Button
var _confirm_no_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_root = Control.new()
	_root.theme = UITheme.build()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_main_panel = _panel("PAUSED", _fill_main)
	_confirm_panel = _panel("QUIT TO MENU?", _fill_confirm)
	_root.add_child(_main_panel)
	_root.add_child(_confirm_panel)
	_confirm_panel.visible = false
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _fill_main(v: VBoxContainer) -> void:
	_resume_btn = UITheme.button("RESUME", Game.resume)
	v.add_child(_resume_btn)
	v.add_child(UITheme.button("RESTART MATCH", Game.restart_match))
	v.add_child(UITheme.button("SETTINGS", _open_settings))
	v.add_child(UITheme.button("QUIT TO MENU", _show_confirm.bind(true)))

func _fill_confirm(v: VBoxContainer) -> void:
	var note := Label.new()
	note.text = "The current match will be lost."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(note)
	v.add_child(UITheme.button("YES, QUIT", Game.go_menu))
	_confirm_no_btn = UITheme.button("NO, GO BACK", _show_confirm.bind(false))
	v.add_child(_confirm_no_btn)

## Full-rect centered panel with a title; `fill` adds the body to the VBox.
func _panel(title_text: String, fill: Callable) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL, UITheme.ACCENT, 1, 10, 28))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	v.add_child(title)
	fill.call(v)
	return center

func _show_confirm(on: bool) -> void:
	_main_panel.visible = not on
	_confirm_panel.visible = on
	if on:
		_confirm_no_btn.grab_focus()
	else:
		_resume_btn.grab_focus()

func _open_settings() -> void:
	var script := load(SETTINGS_SCRIPT) as GDScript
	_settings = script.new() as Control
	_settings.set("embedded", true)
	_settings.connect("closed", _close_settings)
	_root.add_child(_settings)
	_main_panel.visible = false

func _close_settings() -> void:
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
	_settings = null
	_main_panel.visible = true
	_resume_btn.grab_focus()

func _on_visibility_changed() -> void:
	_layer.visible = visible
	if visible and _main_panel != null:
		if _settings != null:
			_close_settings()
		_show_confirm(false)
