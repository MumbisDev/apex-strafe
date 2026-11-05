extends Control

## Emitted by BACK when embedded (the pause menu hosts this screen as an overlay).
signal closed

var embedded: bool = false

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_top = 24
	root.offset_right = -40
	root.offset_bottom = -24
	add_child(root)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	root.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_controls_tab())
	tabs.add_child(_video_tab())
	tabs.add_child(_audio_tab())
	tabs.add_child(_gameplay_tab())

	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_on_back)
	root.add_child(back)

func _controls_tab() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Controls"
	v.add_child(_slider("Mouse Sensitivity", 0.1, 5.0, Settings.mouse_sensitivity, func(x: float) -> void:
		Settings.mouse_sensitivity = x
		Settings.save_settings()
	))
	v.add_child(_check("Invert Y", Settings.invert_y, func(on: bool) -> void:
		Settings.invert_y = on
		Settings.save_settings()
	))
	v.add_child(_check("Crouch Toggle", Settings.crouch_toggle, func(on: bool) -> void:
		Settings.crouch_toggle = on
		Settings.save_settings()
	))
	v.add_child(_check("Grapple Toggle", Settings.grapple_toggle, func(on: bool) -> void:
		Settings.grapple_toggle = on
		Settings.save_settings()
	))
	v.add_child(_check("Auto Bunnyhop", Settings.auto_bhop, func(on: bool) -> void:
		Settings.auto_bhop = on
		Settings.save_settings()
	))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	scroll.add_child(list)
	v.add_child(scroll)
	for action in InputSetup.get_rebindable_actions():
		var row := RebindRow.new()
		row.setup(action)
		row.rebound.connect(func(_a: String) -> void: _build())
		list.add_child(row)
	var reset := Button.new()
	reset.text = "Reset Bindings"
	reset.pressed.connect(func() -> void:
		InputSetup.apply_defaults()
		Settings.bindings.clear()
		Settings.save_settings()
		_build()
	)
	v.add_child(reset)
	var reset_all := Button.new()
	reset_all.text = "Reset Controls Defaults"
	reset_all.pressed.connect(func() -> void:
		Settings.reset_section("controls")
		_build()
	)
	v.add_child(reset_all)
	return v

func _video_tab() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Video"
	v.add_child(_slider("FOV", 80, 130, Settings.fov, func(x: float) -> void:
		Settings.fov = x
		Settings.save_settings()
	))
	v.add_child(_check("VSync", Settings.vsync, func(on: bool) -> void:
		Settings.vsync = on
		Settings.save_settings()
		Settings.apply_video()
	))
	v.add_child(_slider("Render Scale %", 50, 100, Settings.render_scale * 100.0, func(x: float) -> void:
		Settings.render_scale = x / 100.0
		Settings.save_settings()
		Settings.apply_video()
	))
	v.add_child(_slider("Screen Shake %", 0, 100, Settings.screen_shake_amount * 100.0, func(x: float) -> void:
		Settings.screen_shake_amount = x / 100.0
		Settings.save_settings()
	))
	v.add_child(_slider("Speed Lines %", 0, 100, Settings.speed_lines_amount * 100.0, func(x: float) -> void:
		Settings.speed_lines_amount = x / 100.0
		Settings.save_settings()
	))
	v.add_child(_check("Glow", Settings.glow, func(on: bool) -> void:
		Settings.glow = on
		Settings.save_settings()
	))
	var reset := Button.new()
	reset.text = "Reset Video Defaults"
	reset.pressed.connect(func() -> void:
		Settings.reset_section("video")
		_build()
	)
	v.add_child(reset)
	return v

func _audio_tab() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Audio"
	v.add_child(_slider("Master", 0, 100, Settings.vol_master * 100.0, func(x: float) -> void:
		Settings.vol_master = x / 100.0
		Settings.save_settings()
		Settings.apply_audio()
	))
	v.add_child(_slider("Music", 0, 100, Settings.vol_music * 100.0, func(x: float) -> void:
		Settings.vol_music = x / 100.0
		Settings.save_settings()
		Settings.apply_audio()
	))
	v.add_child(_slider("SFX", 0, 100, Settings.vol_sfx * 100.0, func(x: float) -> void:
		Settings.vol_sfx = x / 100.0
		Settings.save_settings()
		Settings.apply_audio()
	))
	v.add_child(_slider("UI", 0, 100, Settings.vol_ui * 100.0, func(x: float) -> void:
		Settings.vol_ui = x / 100.0
		Settings.save_settings()
		Settings.apply_audio()
	))
	var reset := Button.new()
	reset.text = "Reset Audio Defaults"
	reset.pressed.connect(func() -> void:
		Settings.reset_section("audio")
		_build()
	)
	v.add_child(reset)
	return v

func _gameplay_tab() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Gameplay"
	v.add_child(_check("Hit Markers", Settings.hit_markers, func(on: bool) -> void:
		Settings.hit_markers = on
		Settings.save_settings()
	))
	v.add_child(_check("Damage Numbers", Settings.damage_numbers, func(on: bool) -> void:
		Settings.damage_numbers = on
		Settings.save_settings()
	))
	v.add_child(_check("Speedometer", Settings.speedometer, func(on: bool) -> void:
		Settings.speedometer = on
		Settings.save_settings()
	))
	v.add_child(_check("FOV Kick", Settings.fov_kick, func(on: bool) -> void:
		Settings.fov_kick = on
		Settings.save_settings()
	))
	v.add_child(_check("Camera Tilt", Settings.camera_tilt, func(on: bool) -> void:
		Settings.camera_tilt = on
		Settings.save_settings()
	))
	v.add_child(_check("Auto-Switch On Pickup", Settings.auto_switch_on_pickup, func(on: bool) -> void:
		Settings.auto_switch_on_pickup = on
		Settings.save_settings()
	))
	v.add_child(_check("Nameplates", Settings.nameplates, func(on: bool) -> void:
		Settings.nameplates = on
		Settings.save_settings()
	))
	v.add_child(_check("Show FPS", Settings.show_fps, func(on: bool) -> void:
		Settings.show_fps = on
		Settings.save_settings()
	))
	var reset := Button.new()
	reset.text = "Reset Gameplay Defaults"
	reset.pressed.connect(func() -> void:
		Settings.reset_section("gameplay")
		_build()
	)
	v.add_child(reset)
	return v

func _slider(label: String, mn: float, mx: float, cur: float, cb: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = "%s: %.1f" % [label, cur]
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.1
	s.value = cur
	s.value_changed.connect(func(x: float) -> void:
		l.text = "%s: %.1f" % [label, x]
		cb.call(x)
	)
	box.add_child(s)
	return box

func _check(text: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(cb)
	return c

func _on_back() -> void:
	Audio.play_ui("ui_back")
	if embedded:
		closed.emit()
	else:
		Game.go_menu()
