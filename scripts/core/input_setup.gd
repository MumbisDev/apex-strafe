extends Node
## Registers InputMap actions and applies saved bindings.

const DEFAULTS: Dictionary = {
	"move_forward": [{"type": "key", "keycode": KEY_W}],
	"move_back": [{"type": "key", "keycode": KEY_S}],
	"move_left": [{"type": "key", "keycode": KEY_A}],
	"move_right": [{"type": "key", "keycode": KEY_D}],
	"jump": [{"type": "key", "keycode": KEY_SPACE}],
	"crouch": [{"type": "key", "keycode": KEY_CTRL}, {"type": "key", "keycode": KEY_C}],
	"fire": [{"type": "mouse", "button": MOUSE_BUTTON_LEFT}],
	"alt_fire": [{"type": "mouse", "button": MOUSE_BUTTON_RIGHT}],
	"grapple": [{"type": "key", "keycode": KEY_E}],
	"weapon_1": [{"type": "key", "keycode": KEY_1}],
	"weapon_2": [{"type": "key", "keycode": KEY_2}],
	"weapon_3": [{"type": "key", "keycode": KEY_3}],
	"weapon_4": [{"type": "key", "keycode": KEY_4}],
	"weapon_5": [{"type": "key", "keycode": KEY_5}],
	"weapon_6": [{"type": "key", "keycode": KEY_6}],
	"weapon_7": [{"type": "key", "keycode": KEY_7}],
	"weapon_8": [{"type": "key", "keycode": KEY_8}],
	"weapon_next": [{"type": "mouse", "button": MOUSE_BUTTON_WHEEL_DOWN}],
	"weapon_prev": [{"type": "mouse", "button": MOUSE_BUTTON_WHEEL_UP}],
	"weapon_last": [{"type": "key", "keycode": KEY_Q}],
	"scoreboard": [{"type": "key", "keycode": KEY_TAB}],
	"pause": [{"type": "key", "keycode": KEY_ESCAPE}],
	"debug_overlay": [{"type": "key", "keycode": KEY_F3}],
	"practice_infinite_ammo": [{"type": "key", "keycode": KEY_T}],
	"practice_spawn_bot": [{"type": "key", "keycode": KEY_F5}],
	"practice_remove_bot": [{"type": "key", "keycode": KEY_F6}],
	"practice_reset": [{"type": "key", "keycode": KEY_R}],
}

func _ready() -> void:
	apply_defaults()
	call_deferred("_apply_saved_overrides")

func apply_defaults() -> void:
	for action: String in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for spec: Dictionary in DEFAULTS[action]:
			InputMap.action_add_event(action, _make_event(spec))

func _apply_saved_overrides() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	var binds: Dictionary = settings.get("bindings") as Dictionary
	for action: String in binds:
		if not InputMap.has_action(action):
			continue
		var encoded: Array = binds[action] as Array
		if encoded.is_empty():
			continue
		InputMap.action_erase_events(action)
		for enc: Variant in encoded:
			var ev := decode_event(str(enc))
			if ev != null:
				InputMap.action_add_event(action, ev)

func _make_event(spec: Dictionary) -> InputEvent:
	if str(spec.get("type", "")) == "mouse":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(spec["button"]) as MouseButton
		return mb
	var key := InputEventKey.new()
	key.physical_keycode = int(spec["keycode"]) as Key
	return key

func encode_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return "key:%d" % int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if ev is InputEventMouseButton:
		return "mouse:%d" % int((ev as InputEventMouseButton).button_index)
	return ""

func decode_event(enc: String) -> InputEvent:
	var parts := enc.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = int(parts[1]) as Key
		return key
	if parts[0] == "mouse":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(parts[1]) as MouseButton
		return mb
	return null

func rebind(action: String, ev: InputEvent, swap_if_taken: bool = true) -> void:
	if not InputMap.has_action(action):
		return
	var enc := encode_event(ev)
	if enc == "":
		return
	var taken_action := ""
	for a in InputMap.get_actions():
		if str(a).begins_with("ui_"):
			continue
		for existing in InputMap.action_get_events(a):
			if encode_event(existing) == enc and str(a) != action:
				taken_action = str(a)
				break
	if taken_action != "" and swap_if_taken:
		var old_events := InputMap.action_get_events(action)
		InputMap.action_erase_events(taken_action)
		for oe in old_events:
			InputMap.action_add_event(taken_action, oe)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	_persist_bindings()

func _persist_bindings() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	var binds: Dictionary = {}
	for action: String in DEFAULTS:
		var arr: Array[String] = []
		for ev in InputMap.action_get_events(action):
			var enc := encode_event(ev)
			if enc != "":
				arr.append(enc)
		binds[action] = arr
	settings.set("bindings", binds)
	if settings.has_method("save_settings"):
		settings.call("save_settings")

func get_rebindable_actions() -> Array[String]:
	var out: Array[String] = []
	for a: String in DEFAULTS:
		out.append(a)
	return out
