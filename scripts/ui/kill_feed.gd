class_name KillFeed
extends VBoxContainer
## Top-right feed: last 5 lines `Killer [weapon] Victim`, fading after 5 s. Rows are built once and reused.

const MAX_LINES: int = 5
const LIFETIME: float = 5.0
const FADE_TIME: float = 0.6
## Slot id -> display name. Mirrors WeaponLibrary slots (0 = environment).
const WEAPON_NAMES: Dictionary = {
	0: "Void", 1: "Blade", 2: "Arc Pistol", 3: "SMG", 4: "Shotgun",
	5: "Plasma", 6: "Rocket", 7: "Railgun",
}

var _entries: Array[Dictionary] = [] ## oldest first
var _rows: Array[Dictionary] = []
var _clock: float = 0.0

static func weapon_name(weapon_id: int) -> String:
	return str(WEAPON_NAMES.get(weapon_id, "Unknown"))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	for i in MAX_LINES:
		_rows.append(_build_row())
	_refresh()

func add_entry(killer: String, killer_color: Color, weapon_id: int, victim: String,
		victim_color: Color, is_head: bool, involves_local: bool) -> void:
	_entries.append({
		"killer": killer, "killer_color": killer_color, "weapon": weapon_name(weapon_id),
		"victim": victim, "victim_color": victim_color, "head": is_head,
		"local": involves_local, "t0": _clock,
	})
	while _entries.size() > MAX_LINES:
		_entries.remove_at(0)
	_refresh()

func line_count() -> int:
	return _entries.size()

func get_line_text(index: int) -> String:
	if index < 0 or index >= _entries.size():
		return ""
	var e := _entries[index]
	var head := " (HS)" if bool(e["head"]) else ""
	return "%s [%s] %s%s" % [e["killer"], e["weapon"], e["victim"], head]

func clear() -> void:
	_entries.clear()
	_refresh()

func _process(delta: float) -> void:
	_clock += delta
	if _entries.is_empty():
		return
	var changed := false
	while not _entries.is_empty() and _clock - float(_entries[0]["t0"]) >= LIFETIME:
		_entries.remove_at(0)
		changed = true
	if changed:
		_refresh()
	_apply_alpha()

func _build_row() -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 8)
	panel.add_child(hb)
	var killer := _label()
	var weapon := _label()
	weapon.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	var head := _label()
	head.text = "HS"
	head.add_theme_color_override("font_color", Color("#FFD24D"))
	var victim := _label()
	for l: Label in [killer, weapon, head, victim]:
		hb.add_child(l)
	add_child(panel)
	return {"panel": panel, "killer": killer, "weapon": weapon, "head": head, "victim": victim}

func _label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 16)
	return l

func _refresh() -> void:
	for i in MAX_LINES:
		var row: Dictionary = _rows[i]
		var panel := row["panel"] as PanelContainer
		if i >= _entries.size():
			panel.visible = false
			continue
		var e := _entries[i]
		panel.visible = true
		var is_local := bool(e["local"])
		panel.add_theme_stylebox_override("panel", UITheme.box(
			Color(UITheme.BG, 0.72),
			UITheme.ACCENT if is_local else Color(0, 0, 0, 0),
			1 if is_local else 0, 4, 4))
		(row["killer"] as Label).text = str(e["killer"])
		(row["killer"] as Label).add_theme_color_override("font_color", e["killer_color"] as Color)
		(row["weapon"] as Label).text = "[%s]" % str(e["weapon"])
		(row["head"] as Label).visible = bool(e["head"])
		(row["victim"] as Label).text = str(e["victim"])
		(row["victim"] as Label).add_theme_color_override("font_color", e["victim_color"] as Color)
	_apply_alpha()

func _apply_alpha() -> void:
	for i in _entries.size():
		var remaining := LIFETIME - (_clock - float(_entries[i]["t0"]))
		(_rows[i]["panel"] as PanelContainer).modulate.a = clampf(remaining / FADE_TIME, 0.0, 1.0)
