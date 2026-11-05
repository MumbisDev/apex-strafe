class_name ResultsScreen
extends Control
## Post-match results: winner banner, ranked table, highlights for the human, Rematch / Change Settings / Main Menu.
## Reads Game meta "last_results" (Scoring.build_results) and optional "weapon_kills" (written by the HUD).

const SETUP_SCENE: String = "res://scenes/match_setup.tscn"
const COLUMNS: Array[String] = ["#", "", "NAME", "K", "D", "K/D", "ACC%", "STREAK", "MEDALS", "DMG", "TOP SPEED"]
const FADE_IN: float = 0.2

var rows: Array = []
var local_id: int = -1
var _recorded: bool = false

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var results: Dictionary = Game.get_meta("last_results", {}) as Dictionary
	rows = results.get("rows", []) as Array
	local_id = int(results.get("local_id", -1))
	_build(str(results.get("map", "")))
	_record_stats()
	_play_audio()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)

func local_row() -> Dictionary:
	for r: Dictionary in rows:
		if int(r["id"]) == local_id:
			return r
	return {}

func local_rank() -> int:
	for i in rows.size():
		if int((rows[i] as Dictionary)["id"]) == local_id:
			return i + 1
	return 0

func favorite_weapon() -> String:
	var kills := Game.get_meta("weapon_kills", {}) as Dictionary
	var best_id := -1
	var best := 0
	for wid: int in kills:
		if int(kills[wid]) > best:
			best = int(kills[wid])
			best_id = wid
	return KillFeed.weapon_name(best_id) if best_id >= 0 else "--"

# -- build ---------------------------------------------------------------------

func _build(map_id: String) -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 48
	root.offset_right = -48
	root.offset_top = 32
	root.offset_bottom = -32
	root.add_theme_constant_override("separation", 18)
	add_child(root)
	root.add_child(_banner(map_id))
	if rows.is_empty():
		var none := Label.new()
		none.text = "No match results available."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(none)
	else:
		root.add_child(_table())
		root.add_child(_highlights())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	root.add_child(_buttons())

func _banner(map_id: String) -> Label:
	var l := Label.new()
	var won := local_rank() == 1
	if rows.is_empty():
		l.text = "MATCH OVER"
	elif won:
		l.text = "VICTORY"
	else:
		l.text = "%s WINS" % str((rows[0] as Dictionary)["name"]).to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", UITheme.ACCENT if won else UITheme.ACCENT2)
	l.tooltip_text = map_id
	return l

func _table() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL, Color(0, 0, 0, 0), 0, 8, 16))
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	for h in COLUMNS:
		var hl := Label.new()
		hl.text = h
		hl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		grid.add_child(hl)
	for i in rows.size():
		_add_row(grid, i + 1, rows[i] as Dictionary)
	return panel

func _add_row(grid: GridContainer, rank: int, r: Dictionary) -> void:
	var chip := ColorRect.new()
	chip.color = r["color"] as Color
	chip.custom_minimum_size = Vector2(14, 14)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cells: Array[String] = [
		str(rank), "", str(r["name"]), str(r["kills"]), str(r["deaths"]), "%.2f" % float(r["kd"]),
		"%d" % roundi(float(r["accuracy"])), str(r["best_streak"]), str(r["medals"]),
		"%d" % roundi(float(r["damage"])), "%.1f m/s" % float(r["top_speed"]),
	]
	var mine := int(r["id"]) == local_id
	for i in cells.size():
		if i == 1:
			grid.add_child(chip)
			continue
		var l := Label.new()
		l.text = cells[i]
		if mine:
			l.add_theme_color_override("font_color", UITheme.ACCENT)
		grid.add_child(l)

func _highlights() -> Control:
	var r := local_row()
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	if r.is_empty():
		return box
	box.add_child(_card("TOP SPEED", "%.1f m/s" % float(r["top_speed"])))
	box.add_child(_card("BEST STREAK", str(r["best_streak"])))
	box.add_child(_card("FAVORITE WEAPON", favorite_weapon()))
	return box

func _card(title: String, value: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL, UITheme.ACCENT, 1, 8, 16))
	var v := VBoxContainer.new()
	p.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 30)
	v.add_child(t)
	v.add_child(val)
	return p

func _buttons() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	var rematch := UITheme.button("REMATCH", Game.restart_match)
	h.add_child(rematch)
	h.add_child(UITheme.button("CHANGE SETTINGS", _on_change_settings))
	h.add_child(UITheme.button("MAIN MENU", Game.go_menu))
	rematch.grab_focus.call_deferred()
	return h

func _on_change_settings() -> void:
	get_tree().change_scene_to_file(SETUP_SCENE)

# -- side effects (once per screen) -----------------------------------------------

func _record_stats() -> void:
	if _recorded or rows.is_empty():
		return
	_recorded = true
	var r := local_row()
	if r.is_empty():
		return
	var won := local_rank() == 1
	Settings.add_stat("matches_played", 1)
	if won:
		Settings.add_stat("wins", 1)
	Settings.add_stat("kills", int(r["kills"]))
	Settings.add_stat("deaths", int(r["deaths"]))
	Settings.set_stat("best_top_speed", maxf(float(Settings.get_stat("best_top_speed", 0.0)), float(r["top_speed"])))
	Settings.set_stat("best_kill_streak", maxi(int(Settings.get_stat("best_kill_streak", 0)), int(r["best_streak"])))
	Settings.set_stat("last_match_summary", "%s: %s place, %d kills / %d deaths" % [
		"Victory" if won else "Defeat", Hud.ordinal(local_rank()), int(r["kills"]), int(r["deaths"])])

func _play_audio() -> void:
	if rows.is_empty():
		return
	Audio.play_music("music_results")
	Audio.play_ui("match_win" if local_rank() == 1 else "match_lose")
