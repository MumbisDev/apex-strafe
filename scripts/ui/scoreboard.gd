class_name Scoreboard
extends PanelContainer
## Hold-Tab scoreboard. Owns per-fighter stats, fed by the HUD from Events. Rows are pooled.

const MAX_ROWS: int = 12
const HEADERS: Array[String] = ["", "NAME", "", "SCORE", "K", "D"]

## id -> {name: String, color: Color, is_bot: bool, tag: String}. Shared by reference with the HUD.
var roster: Dictionary = {}
var local_id: int = -1
var _stats: Dictionary = {} ## id -> {score: int, kills: int, deaths: int}
var _rows: Array[Array] = [] ## per row: [chip, name, tag, score, kills, deaths]
var _grid: GridContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.BG, 0.86), UITheme.ACCENT, 1, 8, 14))
	_grid = GridContainer.new()
	_grid.columns = HEADERS.size()
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	for h in HEADERS:
		var l := Label.new()
		l.text = h
		l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_grid.add_child(l)
	for i in MAX_ROWS:
		_rows.append(_build_row())
	refresh()

func register(id: int, display_name: String, color: Color, is_bot: bool, tag: String = "") -> void:
	roster[id] = {"name": display_name, "color": color, "is_bot": is_bot, "tag": tag}
	_ensure(id)

func clear_stats() -> void:
	_stats.clear()
	for id: int in roster:
		_ensure(id)

func set_score(id: int, score: int) -> void:
	_ensure(id)["score"] = score

## Absolute sync from MatchManager / network snapshot (avoids double-count and score/kill drift).
func set_stats(id: int, score: int, kills: int, deaths: int) -> void:
	var st := _ensure(id)
	st["score"] = score
	st["kills"] = kills
	st["deaths"] = deaths

func record_kill(killer_id: int, victim_id: int) -> void:
	if killer_id != victim_id and killer_id >= 0:
		var k := _ensure(killer_id)
		k["kills"] = int(k["kills"]) + 1
	var v := _ensure(victim_id)
	v["deaths"] = int(v["deaths"]) + 1
	if visible:
		refresh()

func get_score(id: int) -> int:
	return int(_ensure(id)["score"])

func get_kills(id: int) -> int:
	return int(_ensure(id)["kills"])

func get_deaths(id: int) -> int:
	return int(_ensure(id)["deaths"])

func sorted_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _stats:
		ids.append(id)
	ids.sort_custom(_before)
	return ids

## 1-based rank (score desc, deaths asc, kills desc, id asc).
func get_rank(id: int) -> int:
	return sorted_ids().find(id) + 1

func get_leader_score() -> int:
	var ids := sorted_ids()
	return get_score(ids[0]) if not ids.is_empty() else 0

## True when `id` has a strictly higher score than every other fighter.
func is_sole_leader(id: int) -> bool:
	var mine := get_score(id)
	for other: int in _stats:
		if other != id and get_score(other) >= mine:
			return false
	return _stats.size() > 1

func refresh() -> void:
	if _rows.is_empty():
		return
	var ids := sorted_ids()
	for i in MAX_ROWS:
		var cells: Array = _rows[i]
		for c: Control in cells:
			c.visible = i < ids.size()
		if i >= ids.size():
			continue
		var id := ids[i]
		var info := get_info(id)
		var st := _stats[id] as Dictionary
		(cells[0] as ColorRect).color = info["color"] as Color
		var name_label := cells[1] as Label
		name_label.text = str(info["name"])
		name_label.add_theme_color_override("font_color", UITheme.ACCENT if id == local_id else UITheme.TEXT)
		(cells[2] as Label).text = ("BOT %s" % info["tag"]).strip_edges() if bool(info["is_bot"]) else ""
		(cells[3] as Label).text = str(st["score"])
		(cells[4] as Label).text = str(st["kills"])
		(cells[5] as Label).text = str(st["deaths"])

func _before(a: int, b: int) -> bool:
	var sa := _stats[a] as Dictionary
	var sb := _stats[b] as Dictionary
	if sa["score"] != sb["score"]:
		return int(sa["score"]) > int(sb["score"])
	if sa["deaths"] != sb["deaths"]:
		return int(sa["deaths"]) < int(sb["deaths"])
	if sa["kills"] != sb["kills"]:
		return int(sa["kills"]) > int(sb["kills"])
	return a < b

func _ensure(id: int) -> Dictionary:
	if not _stats.has(id):
		_stats[id] = {"score": 0, "kills": 0, "deaths": 0}
	return _stats[id] as Dictionary

func get_info(id: int) -> Dictionary:
	if roster.has(id):
		return roster[id] as Dictionary
	return {"name": "Fighter %d" % id, "color": UITheme.TEXT_DIM, "is_bot": false, "tag": ""}

func _build_row() -> Array:
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(14, 14)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := Label.new()
	name_l.custom_minimum_size = Vector2(180, 0)
	var tag := Label.new()
	tag.add_theme_color_override("font_color", UITheme.WARN)
	tag.add_theme_font_size_override("font_size", 14)
	var cells: Array = [chip, name_l, tag, Label.new(), Label.new(), Label.new()]
	for c: Control in cells:
		_grid.add_child(c)
	return cells
