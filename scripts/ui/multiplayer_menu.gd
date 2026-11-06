extends Control
## Private lobby UI: Host creates a 6-char code; friends Join with the code.

const MAPS: Array[String] = ["foundry", "spire", "sprawl"]
const KILLS: Array[int] = [10, 15, 25, 40, 50]
const TIMES: Array[int] = [180, 300, 480, 600, 900, 0]

var _status: Label
var _code_label: Label
var _roster: ItemList
var _join_edit: LineEdit
var _map_label: Label
var _bots_label: Label
var _kill_label: Label
var _time_label: Label
var _start_btn: Button
var _host_options: VBoxContainer
var _cfg: MatchConfig

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cfg = MatchConfig.new()
	_cfg.online = true
	_cfg.bot_count = 0
	# Returning from a finished match: restore lobby options from the live session.
	if Game.match_config != null and Game.match_config.online:
		_cfg.kill_limit = Game.match_config.kill_limit
		_cfg.time_limit_sec = Game.match_config.time_limit_sec
		_cfg.map_id = Game.match_config.map_id
		_cfg.bot_count = Game.match_config.bot_count
		_cfg.difficulty = Game.match_config.difficulty
	var lobby_data := NetSession.get_lobby_match_data()
	if not lobby_data.is_empty():
		_cfg = MatchConfig.from_net_dict(lobby_data)
		_cfg.online = true
	_build()
	_wire_session()
	NetSession.connect_cloud()
	_restore_lobby_ui()

func _exit_tree() -> void:
	_unwire_session()

func _wire_session() -> void:
	if not NetSession.status_changed.is_connected(_on_status):
		NetSession.status_changed.connect(_on_status)
		NetSession.roster_changed.connect(_refresh_roster)
		NetSession.lobby_ready.connect(_on_lobby_ready)
		NetSession.lobby_failed.connect(_on_lobby_failed)
		NetSession.connection_error.connect(_on_lobby_failed)
		NetSession.match_start_requested.connect(_on_local_start)

func _unwire_session() -> void:
	if NetSession.status_changed.is_connected(_on_status):
		NetSession.status_changed.disconnect(_on_status)
		NetSession.roster_changed.disconnect(_refresh_roster)
		NetSession.lobby_ready.disconnect(_on_lobby_ready)
		NetSession.lobby_failed.disconnect(_on_lobby_failed)
		NetSession.connection_error.disconnect(_on_lobby_failed)
		NetSession.match_start_requested.disconnect(_on_local_start)

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
	title.text = "MULTIPLAYER"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	root.add_child(title)

	_status = Label.new()
	_status.text = "Connecting…"
	_status.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	root.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)

	var host_btn := Button.new()
	host_btn.text = "HOST LOBBY"
	host_btn.pressed.connect(_on_host)
	row.add_child(host_btn)

	_join_edit = LineEdit.new()
	_join_edit.placeholder_text = "CODE"
	_join_edit.custom_minimum_size = Vector2(140, 0)
	_join_edit.max_length = 8
	row.add_child(_join_edit)

	var join_btn := Button.new()
	join_btn.text = "JOIN"
	join_btn.pressed.connect(_on_join)
	row.add_child(join_btn)

	var copy_btn := Button.new()
	copy_btn.text = "COPY CODE"
	copy_btn.pressed.connect(_on_copy)
	row.add_child(copy_btn)

	_code_label = Label.new()
	_code_label.text = "Lobby: —"
	_code_label.add_theme_font_size_override("font_size", 28)
	_code_label.add_theme_color_override("font_color", UITheme.ACCENT2)
	root.add_child(_code_label)

	var roster_h := Label.new()
	roster_h.text = "PLAYERS"
	roster_h.add_theme_color_override("font_color", UITheme.ACCENT)
	root.add_child(roster_h)

	_roster = ItemList.new()
	_roster.custom_minimum_size = Vector2(0, 160)
	_roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_roster)

	_host_options = VBoxContainer.new()
	_host_options.add_theme_constant_override("separation", 8)
	root.add_child(_host_options)

	_map_label = Label.new()
	_map_label.text = "Map: %s" % _cfg.map_id
	_host_options.add_child(_map_label)
	var map_cycle := Button.new()
	map_cycle.text = "Cycle map ▶"
	map_cycle.pressed.connect(func() -> void:
		var i := MAPS.find(_cfg.map_id)
		_cfg.map_id = MAPS[(i + 1) % MAPS.size()]
		_map_label.text = "Map: %s" % _cfg.map_id
		_push_lobby_data()
	)
	_host_options.add_child(map_cycle)

	_bots_label = Label.new()
	_bots_label.text = "Bot fill: %d" % _cfg.bot_count
	_host_options.add_child(_bots_label)
	var bot_slider := HSlider.new()
	bot_slider.min_value = 0
	bot_slider.max_value = 11
	bot_slider.step = 1
	bot_slider.value = _cfg.bot_count
	bot_slider.value_changed.connect(func(v: float) -> void:
		_cfg.bot_count = int(v)
		_bots_label.text = "Bot fill: %d" % _cfg.bot_count
		_push_lobby_data()
	)
	_host_options.add_child(bot_slider)

	_kill_label = Label.new()
	_kill_label.text = "Kill limit: %d" % _cfg.kill_limit
	_host_options.add_child(_kill_label)
	var kill_cycle := Button.new()
	kill_cycle.text = "Cycle kill limit ▶"
	kill_cycle.pressed.connect(func() -> void:
		var i := KILLS.find(_cfg.kill_limit)
		_cfg.kill_limit = KILLS[(maxi(i, 0) + 1) % KILLS.size()]
		_kill_label.text = "Kill limit: %d" % _cfg.kill_limit
		_push_lobby_data()
	)
	_host_options.add_child(kill_cycle)

	_time_label = Label.new()
	_time_label.text = "Time: %s" % _fmt_time(_cfg.time_limit_sec)
	_host_options.add_child(_time_label)
	var time_cycle := Button.new()
	time_cycle.text = "Cycle time ▶"
	time_cycle.pressed.connect(func() -> void:
		var i := TIMES.find(_cfg.time_limit_sec)
		_cfg.time_limit_sec = TIMES[(maxi(i, 0) + 1) % TIMES.size()]
		_time_label.text = "Time: %s" % _fmt_time(_cfg.time_limit_sec)
		_push_lobby_data()
	)
	_host_options.add_child(time_cycle)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)

	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func() -> void:
		Audio.play_ui("ui_back")
		NetSession.leave()
		Game.go_menu()
	)
	actions.add_child(back)

	var leave := Button.new()
	leave.text = "LEAVE LOBBY"
	leave.pressed.connect(func() -> void:
		Audio.play_ui("ui_back")
		NetSession.leave()
		_code_label.text = "Lobby: —"
		_refresh_roster()
		_update_host_ui()
	)
	actions.add_child(leave)

	_start_btn = Button.new()
	_start_btn.text = "START MATCH"
	_start_btn.pressed.connect(_on_start)
	actions.add_child(_start_btn)

	_update_host_ui()

func _fmt_time(sec: int) -> String:
	if sec <= 0:
		return "Unlimited"
	return "%d min" % int(sec / 60)

func _on_status(text: String) -> void:
	_status.text = text

func _on_lobby_ready(code: String) -> void:
	_code_label.text = "Lobby: %s" % code
	_refresh_roster()
	_update_host_ui()
	_push_lobby_data()

func _on_lobby_failed(msg: String) -> void:
	_status.text = msg
	Audio.play_ui("ui_error")

func _on_host() -> void:
	Audio.play_ui("ui_confirm")
	# Re-host after a match: leave the old lobby first so create isn't rejected.
	if not NetSession.lobby_code.is_empty():
		NetSession.leave()
	NetSession.host_lobby()

func _on_join() -> void:
	Audio.play_ui("ui_confirm")
	if not NetSession.lobby_code.is_empty():
		NetSession.leave()
	NetSession.join_lobby(_join_edit.text)

func _restore_lobby_ui() -> void:
	if NetSession.lobby_code.is_empty():
		_code_label.text = "Lobby: —"
		_update_host_ui()
		return
	_code_label.text = "Lobby: %s" % NetSession.lobby_code
	_map_label.text = "Map: %s" % _cfg.map_id
	_bots_label.text = "Bot fill: %d" % _cfg.bot_count
	_kill_label.text = "Kill limit: %d" % _cfg.kill_limit
	_time_label.text = "Time: %s" % _fmt_time(_cfg.time_limit_sec)
	_refresh_roster()
	_update_host_ui()
	if NetSession.is_online:
		_status.text = "In lobby %s" % NetSession.lobby_code
	else:
		_status.text = "Reconnecting…"

func _on_copy() -> void:
	if NetSession.lobby_code.is_empty():
		return
	DisplayServer.clipboard_set(NetSession.lobby_code)
	_status.text = "Code copied"
	Audio.play_ui("ui_click")

func _refresh_roster() -> void:
	_roster.clear()
	var host_id := NetSession.host_client_id()
	var local_id := NetSession.local_client_id()
	for id in NetSession.peer_ids:
		var tag := "P%d" % id
		if id == local_id:
			tag += " (you)"
		if id == host_id:
			tag += " [host]"
		_roster.add_item(tag)
	_update_host_ui()

func _update_host_ui() -> void:
	var in_lobby := not NetSession.lobby_code.is_empty()
	var host := NetSession.is_host()
	_host_options.visible = in_lobby and host
	_start_btn.disabled = not (in_lobby and host and NetSession.peer_ids.size() >= 1)

func _push_lobby_data() -> void:
	if NetSession.is_host():
		NetSession.set_lobby_match_data(_cfg.to_net_dict())

func _on_start() -> void:
	if not NetSession.is_host():
		return
	Audio.play_ui("ui_confirm")
	_cfg.online = true
	_cfg.seed = int(Time.get_unix_time_from_system())
	var payload := _cfg.to_net_dict()
	NetSession.set_lobby_match_data(payload)
	NetSession.broadcast_start_match(payload)

func _on_local_start(cfg: Dictionary) -> void:
	# Host also receives via broadcast_start_match
	Game.go_online_match(MatchConfig.from_net_dict(cfg))
