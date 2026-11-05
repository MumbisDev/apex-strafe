class_name RebindRow
extends HBoxContainer
## One row of the Controls tab: action name plus a button that captures the next key or mouse button.
## Escape cancels. If the input is already bound to another action, asks to swap before applying.

signal rebound(action: String)

const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Mouse 1", MOUSE_BUTTON_RIGHT: "Mouse 2", MOUSE_BUTTON_MIDDLE: "Mouse 3",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

var action: String = ""
var listening: bool = false
var _button: Button
var _pending: InputEvent
var _conflict: Control ## inline confirm bar, shown on duplicate binds
var _conflict_label: Label

static func describe_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		var idx := (ev as InputEventMouseButton).button_index
		return str(MOUSE_NAMES.get(idx, "Mouse %d" % int(idx)))
	return "?"

static func pretty_action(action_name: String) -> String:
	return action_name.replace("_", " ").capitalize()

func setup(action_name: String) -> void:
	action = action_name
	var label := Label.new()
	label.text = pretty_action(action)
	label.custom_minimum_size = Vector2(220, 0)
	add_child(label)
	_button = UITheme.button("", _begin_listening)
	_button.custom_minimum_size = Vector2(180, 36)
	add_child(_button)
	_conflict = HBoxContainer.new()
	_conflict.visible = false
	_conflict_label = Label.new()
	_conflict_label.add_theme_color_override("font_color", UITheme.WARN)
	_conflict.add_child(_conflict_label)
	_conflict.add_child(UITheme.button("SWAP", _confirm_swap))
	_conflict.add_child(UITheme.button("CANCEL", _cancel))
	add_child(_conflict)
	refresh()

## Re-reads the current InputMap events into the button text.
func refresh() -> void:
	if _button == null:
		return
	var names: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		names.append(describe_event(ev))
	_button.text = ", ".join(names) if not names.is_empty() else "(none)"

## Another rebindable action already using this event, or "".
func find_conflict(ev: InputEvent) -> String:
	var enc := InputSetup.encode_event(ev)
	for other in InputSetup.get_rebindable_actions():
		if other == action:
			continue
		for existing in InputMap.action_get_events(other):
			if InputSetup.encode_event(existing) == enc:
				return other
	return ""

## Applies a captured event, asking for confirmation when it would steal another action's input.
func submit_event(ev: InputEvent) -> void:
	var other := find_conflict(ev)
	if other == "":
		_apply(ev)
		return
	_pending = ev
	_conflict_label.text = "Used by %s. " % pretty_action(other)
	_conflict.visible = true
	_button.text = describe_event(ev)

func _begin_listening() -> void:
	listening = true
	_conflict.visible = false
	_button.text = "Press a key..."

func _input(event: InputEvent) -> void:
	if not listening:
		return
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if key != null and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		listening = false
		if key.keycode == KEY_ESCAPE:
			refresh()
		else:
			submit_event(key)
	elif mouse != null and mouse.pressed:
		get_viewport().set_input_as_handled()
		listening = false
		submit_event(mouse)

func _apply(ev: InputEvent) -> void:
	InputSetup.rebind(action, ev, true)
	_pending = null
	_conflict.visible = false
	Audio.play_ui("ui_confirm")
	refresh()
	rebound.emit(action)

func _confirm_swap() -> void:
	if _pending != null:
		_apply(_pending)

func _cancel() -> void:
	_pending = null
	_conflict.visible = false
	refresh()
