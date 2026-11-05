class_name WeaponStrip
extends HBoxContainer
## Weapon strip. Slot states: EMPTY (not owned), OWNED, NO_AMMO (owned but dry).

enum SlotState { EMPTY, OWNED, NO_AMMO }

const SLOTS: int = 8
const SHORT_NAMES: Array[String] = ["BLD", "ARC", "SMG", "SHT", "PLS", "RKT", "RAIL", "PRT"]

var selected: int = 0 ## slot 1..7, 0 = none
var _panels: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _states: PackedInt32Array = PackedInt32Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	_states.resize(SLOTS)
	for i in SLOTS:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.custom_minimum_size = Vector2(48, 44)
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text = "%d\n%s" % [i + 1, SHORT_NAMES[i]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 12)
		p.add_child(l)
		add_child(p)
		_panels.append(p)
		_labels.append(l)
	_refresh()

## states: one SlotState per slot (index 0 = slot 1). selected_slot: 1..7.
func set_states(states: PackedInt32Array, selected_slot: int) -> void:
	if states == _states and selected_slot == selected:
		return
	_states = states
	selected = selected_slot
	_refresh()

func get_slot_state(slot: int) -> int:
	return _states[slot - 1] if slot >= 1 and slot <= _states.size() else SlotState.EMPTY

func _refresh() -> void:
	for i in mini(SLOTS, _panels.size()):
		var state: int = _states[i] if i < _states.size() else SlotState.EMPTY
		var is_sel := selected == i + 1
		var border := UITheme.ACCENT if is_sel else Color(UITheme.TEXT_DIM, 0.4)
		var bg := Color(UITheme.PANEL, 0.9) if state != SlotState.EMPTY else Color(UITheme.BG, 0.5)
		_panels[i].add_theme_stylebox_override("panel", UITheme.box(bg, border, 2 if is_sel else 1, 4, 3))
		var col := UITheme.TEXT
		if state == SlotState.EMPTY:
			col = Color(UITheme.TEXT_DIM, 0.4)
		elif state == SlotState.NO_AMMO:
			col = Color("#FF3B3B")
		_labels[i].add_theme_color_override("font_color", col)
