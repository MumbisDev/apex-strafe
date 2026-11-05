extends Control

var _cfg: MatchConfig
var _map_label: Label
var _bots_label: Label
var _diff_label: Label
var _kill_label: Label
var _time_label: Label

const MAPS: Array[String] = ["foundry", "spire", "sprawl"]
const DIFFS: Array[String] = ["Rookie", "Veteran", "Elite", "Nightmare", "Mixed"]
const KILLS: Array[int] = [10, 15, 25, 40, 50]
const TIMES: Array[int] = [180, 300, 480, 600, 900, 0]

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(PRESET_FULL_RECT)
	_cfg = Settings.load_match_config()
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_top = 30
	root.offset_right = -40
	root.offset_bottom = -30
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "MATCH SETUP"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	root.add_child(title)

	var presets := HBoxContainer.new()
	root.add_child(presets)
	_preset_btn(presets, "Quick Match", MatchConfig.preset_quick)
	_preset_btn(presets, "Movement Frenzy", MatchConfig.preset_movement_frenzy)
	_preset_btn(presets, "Rocket Arena", MatchConfig.preset_rocket_arena)
	_preset_btn(presets, "Instagib", MatchConfig.preset_instagib)
	_preset_btn(presets, "Sweat", MatchConfig.preset_sweat)

	_map_label = _row(root, "Map", _cfg.map_id)
	_add_cycle(root, func() -> void:
		var i := MAPS.find(_cfg.map_id)
		_cfg.map_id = MAPS[(i + 1) % MAPS.size()]
		_map_label.text = "Map: %s" % _cfg.map_id
	)

	_bots_label = _row(root, "Bots", str(_cfg.bot_count))
	_add_slider_row(root, 1, 11, _cfg.bot_count, func(v: float) -> void:
		_cfg.bot_count = int(v)
		_bots_label.text = "Bots: %d" % _cfg.bot_count
	)

	_diff_label = _row(root, "Difficulty", DIFFS[int(_cfg.difficulty)])
	_add_cycle(root, func() -> void:
		_cfg.difficulty = ((int(_cfg.difficulty) + 1) % DIFFS.size()) as MatchConfig.Difficulty
		_diff_label.text = "Difficulty: %s" % DIFFS[int(_cfg.difficulty)]
	)

	_kill_label = _row(root, "Kill limit", str(_cfg.kill_limit))
	_add_cycle(root, func() -> void:
		var i := KILLS.find(_cfg.kill_limit)
		_cfg.kill_limit = KILLS[(maxi(i, 0) + 1) % KILLS.size()]
		_kill_label.text = "Kill limit: %d" % _cfg.kill_limit
	)

	_time_label = _row(root, "Time", _fmt_time(_cfg.time_limit_sec))
	_add_cycle(root, func() -> void:
		var i := TIMES.find(_cfg.time_limit_sec)
		_cfg.time_limit_sec = TIMES[(maxi(i, 0) + 1) % TIMES.size()]
		_time_label.text = "Time: %s" % _fmt_time(_cfg.time_limit_sec)
	)

	var mut_row := HBoxContainer.new()
	root.add_child(mut_row)
	_mut_toggle(mut_row, "Low Gravity", MatchConfig.Mutator.LOW_GRAVITY)
	_mut_toggle(mut_row, "Instagib", MatchConfig.Mutator.INSTAGIB)
	_mut_toggle(mut_row, "Rockets Only", MatchConfig.Mutator.ROCKETS_ONLY)

	var pu := CheckButton.new()
	pu.text = "Powerups"
	pu.button_pressed = _cfg.powerups_enabled
	pu.toggled.connect(func(on: bool) -> void: _cfg.powerups_enabled = on)
	root.add_child(pu)

	var actions := HBoxContainer.new()
	root.add_child(actions)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func() -> void:
		Audio.play_ui("ui_back")
		Game.go_menu()
	)
	actions.add_child(back)
	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(200, 48)
	start.pressed.connect(func() -> void:
		Audio.play_ui("ui_confirm")
		_sanitize_mutators()
		if _cfg.seed == 0:
			_cfg.seed = int(Time.get_unix_time_from_system())
		Game.go_match_setup_then_load(_cfg)
	)
	actions.add_child(start)

func _sanitize_mutators() -> void:
	if _cfg.has_mutator(MatchConfig.Mutator.INSTAGIB) and _cfg.has_mutator(MatchConfig.Mutator.ROCKETS_ONLY):
		_cfg.mutators.erase(int(MatchConfig.Mutator.ROCKETS_ONLY))

func _preset_btn(parent: Node, text: String, factory: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		Audio.play_ui("ui_click")
		_cfg = factory.call()
		# rebuild simple labels
		_map_label.text = "Map: %s" % _cfg.map_id
		_bots_label.text = "Bots: %d" % _cfg.bot_count
		_diff_label.text = "Difficulty: %s" % DIFFS[int(_cfg.difficulty)]
		_kill_label.text = "Kill limit: %d" % _cfg.kill_limit
		_time_label.text = "Time: %s" % _fmt_time(_cfg.time_limit_sec)
	)
	parent.add_child(b)

func _row(parent: Node, key: String, val: String) -> Label:
	var l := Label.new()
	l.text = "%s: %s" % [key, val]
	parent.add_child(l)
	return l

func _add_cycle(parent: Node, cb: Callable) -> void:
	var b := Button.new()
	b.text = "Cycle ▶"
	b.pressed.connect(func() -> void:
		Audio.play_ui("ui_click")
		cb.call()
	)
	parent.add_child(b)

func _add_slider_row(parent: Node, mn: float, mx: float, cur: float, cb: Callable) -> void:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 1
	s.value = cur
	s.custom_minimum_size = Vector2(300, 24)
	s.value_changed.connect(cb)
	parent.add_child(s)

func _mut_toggle(parent: Node, text: String, m: MatchConfig.Mutator) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = _cfg.has_mutator(m)
	c.toggled.connect(func(on: bool) -> void:
		if on:
			if not _cfg.mutators.has(int(m)):
				_cfg.mutators.append(int(m))
		else:
			_cfg.mutators.erase(int(m))
		_sanitize_mutators()
	)
	parent.add_child(c)

func _fmt_time(sec: int) -> String:
	if sec <= 0:
		return "Unlimited"
	return "%d min" % int(sec / 60.0)
