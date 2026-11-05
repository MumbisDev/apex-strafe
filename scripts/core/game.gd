extends Node
## Scene flow: boot → menu → loading → match/practice → results. Pause and quit.

var match_config: MatchConfig = MatchConfig.new()
var _paused: bool = false

const SCENE_BOOT := "res://scenes/boot.tscn"
const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_LOADING := "res://scenes/loading.tscn"
const SCENE_MATCH := "res://scenes/match.tscn"
const SCENE_PRACTICE := "res://scenes/practice.tscn"
const SCENE_RESULTS := "res://scenes/results.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var scene := get_tree().current_scene
		if scene != null and (scene.name == "Match" or scene.name == "Practice"):
			toggle_pause()
			get_viewport().set_input_as_handled()

func go_boot() -> void:
	_unpause()
	get_tree().change_scene_to_file(SCENE_BOOT)

func go_menu() -> void:
	_unpause()
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(SCENE_MENU)

func go_practice() -> void:
	match_config = MatchConfig.new()
	match_config.practice = true
	match_config.map_id = "range"
	match_config.bot_count = 0
	_unpause()
	get_tree().change_scene_to_file(SCENE_PRACTICE)

func go_match_setup_then_load(cfg: MatchConfig) -> void:
	match_config = cfg
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("save_match_config"):
		settings.call("save_match_config", cfg)
	_unpause()
	get_tree().change_scene_to_file(SCENE_LOADING)

func go_match() -> void:
	_unpause()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(SCENE_MATCH)

func go_results(results: Dictionary) -> void:
	_unpause()
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_meta("last_results", results)
	get_tree().change_scene_to_file(SCENE_RESULTS)

func toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused else Input.MOUSE_MODE_CAPTURED
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("set_pause_visible"):
		scene.call("set_pause_visible", _paused)

func resume() -> void:
	if _paused:
		toggle_pause()

func restart_match() -> void:
	_unpause()
	Engine.time_scale = 1.0
	match_config.seed = int(Time.get_unix_time_from_system())
	get_tree().change_scene_to_file(SCENE_LOADING)

func quit_game() -> void:
	get_tree().quit()

func _unpause() -> void:
	_paused = false
	get_tree().paused = false
	Engine.time_scale = 1.0

func is_paused() -> bool:
	return _paused
