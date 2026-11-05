extends Control

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = UITheme.build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	Audio.play_music("music_menu")

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	# Parallax grid FALLBACK attract (full attract mode later)
	var grid := ColorRect.new()
	grid.color = Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.04)
	grid.set_anchors_preset(PRESET_FULL_RECT)
	add_child(grid)

	var root := HBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.offset_left = 48
	root.offset_top = 48
	root.offset_right = -48
	root.offset_bottom = -48
	add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	root.add_child(left)

	var title := Label.new()
	title.text = "APEX STRAFE"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	left.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Movement is the skill ceiling"
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	left.add_child(subtitle)

	left.add_child(_btn("PLAY", _on_play))
	left.add_child(_btn("PRACTICE RANGE", _on_practice))
	var mp := _btn("MULTIPLAYER", func() -> void: pass)
	mp.disabled = true
	mp.tooltip_text = "Coming soon"
	left.add_child(mp)
	left.add_child(_btn("SETTINGS", _on_settings))
	left.add_child(_btn("QUIT", _on_quit))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 16)
	root.add_child(right)

	right.add_child(_stats_card())
	right.add_child(_last_match_card())

	var ver := Label.new()
	ver.text = "v0.1.0-dev  |  Godot 4.7.2"
	ver.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	ver.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -16
	ver.offset_bottom = -12
	add_child(ver)

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 44)
	b.pressed.connect(func() -> void:
		Audio.play_ui("ui_click")
		cb.call()
	)
	b.mouse_entered.connect(func() -> void: Audio.play_ui("ui_hover"))
	return b

func _stats_card() -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	p.add_child(v)
	var h := Label.new()
	h.text = "LIFETIME STATS"
	h.add_theme_color_override("font_color", UITheme.ACCENT)
	v.add_child(h)
	v.add_child(_stat_line("Matches", str(Settings.get_stat("matches_played", 0))))
	v.add_child(_stat_line("Wins", str(Settings.get_stat("wins", 0))))
	v.add_child(_stat_line("Kills", str(Settings.get_stat("kills", 0))))
	v.add_child(_stat_line("Deaths", str(Settings.get_stat("deaths", 0))))
	v.add_child(_stat_line("Best speed", "%.1f m/s" % float(Settings.get_stat("best_top_speed", 0.0))))
	return p

func _last_match_card() -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	p.add_child(v)
	var h := Label.new()
	h.text = "LAST MATCH"
	h.add_theme_color_override("font_color", UITheme.ACCENT2)
	v.add_child(h)
	var summary := str(Settings.get_stat("last_match_summary", "No matches yet."))
	var l := Label.new()
	l.text = summary
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return p

func _stat_line(k: String, v: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var a := Label.new()
	a.text = k
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	var b := Label.new()
	b.text = v
	row.add_child(a)
	row.add_child(b)
	return row

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/match_setup.tscn")

func _on_practice() -> void:
	Game.go_practice()

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _on_quit() -> void:
	Game.quit_game()
