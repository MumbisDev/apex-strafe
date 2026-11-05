extends Node
## Loads/saves user://settings.cfg with typed getters. Applies display/audio/input.

const PATH := "user://settings.cfg"

var _cfg: ConfigFile = ConfigFile.new()

# Controls
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var crouch_toggle: bool = false
var grapple_toggle: bool = false
var auto_bhop: bool = true
var auto_switch_on_pickup: bool = true

# Video
var window_mode: int = 0 ## 0 windowed, 1 borderless, 2 exclusive
var resolution: Vector2i = Vector2i(1920, 1080)
var vsync: bool = true
var fps_cap: int = 144 ## 0 = unlimited
var fov: float = 100.0
var render_scale: float = 1.0
var msaa: int = 1 ## 0 off, 1=2x, 2=4x
var shadow_quality: int = 2 ## 0 off .. 3 high
var ssao: bool = false
var glow: bool = true
var brightness: float = 1.0
var screen_shake_amount: float = 1.0
var speed_lines_amount: float = 1.0

# Audio
var vol_master: float = 0.8
var vol_music: float = 0.6
var vol_sfx: float = 0.8
var vol_ui: float = 0.7
var mute_on_focus_loss: bool = true

# Gameplay / HUD
var crosshair_style: String = "cross"
var crosshair_color: Color = Color(1, 1, 1, 0.9)
var crosshair_size: float = 1.0
var crosshair_thickness: float = 2.0
var crosshair_gap: float = 4.0
var crosshair_opacity: float = 0.9
var crosshair_outline: bool = true
var hit_markers: bool = true
var damage_numbers: bool = false
var speedometer: bool = true
var fov_kick: bool = true
var camera_tilt: bool = true
var viewmodel_mode: int = 0 ## 0 full, 1 minimal, 2 hidden
var nameplates: bool = true
var show_fps: bool = false

# Bindings: action -> Array of event encode strings
var bindings: Dictionary = {}

# Last match config + stats keys stored in cfg sections

func _ready() -> void:
	load_settings()
	apply_all()

func load_settings() -> void:
	var err := _cfg.load(PATH)
	if err != OK:
		_write_defaults_to_cfg()
		save_settings()
		return
	mouse_sensitivity = float(_cfg.get_value("controls", "mouse_sensitivity", 1.0))
	invert_y = bool(_cfg.get_value("controls", "invert_y", false))
	crouch_toggle = bool(_cfg.get_value("controls", "crouch_toggle", false))
	grapple_toggle = bool(_cfg.get_value("controls", "grapple_toggle", false))
	auto_bhop = bool(_cfg.get_value("controls", "auto_bhop", true))
	auto_switch_on_pickup = bool(_cfg.get_value("gameplay", "auto_switch_on_pickup", true))
	window_mode = int(_cfg.get_value("video", "window_mode", 0))
	resolution = Vector2i(
		int(_cfg.get_value("video", "res_x", 1920)),
		int(_cfg.get_value("video", "res_y", 1080))
	)
	vsync = bool(_cfg.get_value("video", "vsync", true))
	fps_cap = int(_cfg.get_value("video", "fps_cap", 144))
	fov = float(_cfg.get_value("video", "fov", 100.0))
	render_scale = float(_cfg.get_value("video", "render_scale", 1.0))
	msaa = int(_cfg.get_value("video", "msaa", 1))
	shadow_quality = int(_cfg.get_value("video", "shadow_quality", 2))
	ssao = bool(_cfg.get_value("video", "ssao", false))
	glow = bool(_cfg.get_value("video", "glow", true))
	brightness = float(_cfg.get_value("video", "brightness", 1.0))
	screen_shake_amount = float(_cfg.get_value("video", "screen_shake", 1.0))
	speed_lines_amount = float(_cfg.get_value("video", "speed_lines", 1.0))
	vol_master = float(_cfg.get_value("audio", "master", 0.8))
	vol_music = float(_cfg.get_value("audio", "music", 0.6))
	vol_sfx = float(_cfg.get_value("audio", "sfx", 0.8))
	vol_ui = float(_cfg.get_value("audio", "ui", 0.7))
	mute_on_focus_loss = bool(_cfg.get_value("audio", "mute_on_focus_loss", true))
	crosshair_style = str(_cfg.get_value("gameplay", "crosshair_style", "cross"))
	hit_markers = bool(_cfg.get_value("gameplay", "hit_markers", true))
	damage_numbers = bool(_cfg.get_value("gameplay", "damage_numbers", false))
	speedometer = bool(_cfg.get_value("gameplay", "speedometer", true))
	fov_kick = bool(_cfg.get_value("gameplay", "fov_kick", true))
	camera_tilt = bool(_cfg.get_value("gameplay", "camera_tilt", true))
	viewmodel_mode = int(_cfg.get_value("gameplay", "viewmodel_mode", 0))
	nameplates = bool(_cfg.get_value("gameplay", "nameplates", true))
	show_fps = bool(_cfg.get_value("gameplay", "show_fps", false))
	if _cfg.has_section("bindings"):
		bindings.clear()
		for key in _cfg.get_section_keys("bindings"):
			bindings[key] = str(_cfg.get_value("bindings", key, "")).split("|", false)

func _write_defaults_to_cfg() -> void:
	# populated on first save
	pass

func save_settings() -> void:
	_cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	_cfg.set_value("controls", "invert_y", invert_y)
	_cfg.set_value("controls", "crouch_toggle", crouch_toggle)
	_cfg.set_value("controls", "grapple_toggle", grapple_toggle)
	_cfg.set_value("controls", "auto_bhop", auto_bhop)
	_cfg.set_value("video", "window_mode", window_mode)
	_cfg.set_value("video", "res_x", resolution.x)
	_cfg.set_value("video", "res_y", resolution.y)
	_cfg.set_value("video", "vsync", vsync)
	_cfg.set_value("video", "fps_cap", fps_cap)
	_cfg.set_value("video", "fov", fov)
	_cfg.set_value("video", "render_scale", render_scale)
	_cfg.set_value("video", "msaa", msaa)
	_cfg.set_value("video", "shadow_quality", shadow_quality)
	_cfg.set_value("video", "ssao", ssao)
	_cfg.set_value("video", "glow", glow)
	_cfg.set_value("video", "brightness", brightness)
	_cfg.set_value("video", "screen_shake", screen_shake_amount)
	_cfg.set_value("video", "speed_lines", speed_lines_amount)
	_cfg.set_value("audio", "master", vol_master)
	_cfg.set_value("audio", "music", vol_music)
	_cfg.set_value("audio", "sfx", vol_sfx)
	_cfg.set_value("audio", "ui", vol_ui)
	_cfg.set_value("audio", "mute_on_focus_loss", mute_on_focus_loss)
	_cfg.set_value("gameplay", "auto_switch_on_pickup", auto_switch_on_pickup)
	_cfg.set_value("gameplay", "crosshair_style", crosshair_style)
	_cfg.set_value("gameplay", "hit_markers", hit_markers)
	_cfg.set_value("gameplay", "damage_numbers", damage_numbers)
	_cfg.set_value("gameplay", "speedometer", speedometer)
	_cfg.set_value("gameplay", "fov_kick", fov_kick)
	_cfg.set_value("gameplay", "camera_tilt", camera_tilt)
	_cfg.set_value("gameplay", "viewmodel_mode", viewmodel_mode)
	_cfg.set_value("gameplay", "nameplates", nameplates)
	_cfg.set_value("gameplay", "show_fps", show_fps)
	for action: String in bindings:
		var arr: Array = bindings[action]
		_cfg.set_value("bindings", action, "|".join(PackedStringArray(arr)))
	_cfg.save(PATH)

func apply_all() -> void:
	apply_video()
	apply_audio()

func apply_video() -> void:
	match window_mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = fps_cap
	var msaa_val: Viewport.MSAA = Viewport.MSAA_DISABLED
	match msaa:
		1: msaa_val = Viewport.MSAA_2X
		2: msaa_val = Viewport.MSAA_4X
	get_viewport().msaa_3d = msaa_val
	get_viewport().scaling_3d_scale = clampf(render_scale, 0.5, 1.0)

func apply_audio() -> void:
	_set_bus_linear("Master", vol_master)
	_set_bus_linear("Music", vol_music)
	_set_bus_linear("SFX", vol_sfx)
	_set_bus_linear("UI", vol_ui)

func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var db: float = -80.0 if linear <= 0.0001 else (20.0 * log(linear) / log(10.0))
	AudioServer.set_bus_volume_db(idx, db)

func reset_section(section: String) -> void:
	match section:
		"controls":
			mouse_sensitivity = 1.0
			invert_y = false
			crouch_toggle = false
			grapple_toggle = false
			auto_bhop = true
			bindings.clear()
			var setup := get_node_or_null("/root/InputSetup")
			if setup and setup.has_method("apply_defaults"):
				setup.call("apply_defaults")
		"video":
			window_mode = 0
			resolution = Vector2i(1920, 1080)
			vsync = true
			fps_cap = 144
			fov = 100.0
			render_scale = 1.0
			msaa = 1
			shadow_quality = 2
			ssao = false
			glow = true
			brightness = 1.0
			screen_shake_amount = 1.0
			speed_lines_amount = 1.0
		"audio":
			vol_master = 0.8
			vol_music = 0.6
			vol_sfx = 0.8
			vol_ui = 0.7
			mute_on_focus_loss = true
		"gameplay":
			auto_switch_on_pickup = true
			crosshair_style = "cross"
			hit_markers = true
			damage_numbers = false
			speedometer = true
			fov_kick = true
			camera_tilt = true
			viewmodel_mode = 0
			nameplates = true
			show_fps = false
	save_settings()
	apply_all()

func save_match_config(mc: MatchConfig) -> void:
	_cfg.set_value("match", "map_id", mc.map_id)
	_cfg.set_value("match", "bot_count", mc.bot_count)
	_cfg.set_value("match", "difficulty", int(mc.difficulty))
	_cfg.set_value("match", "kill_limit", mc.kill_limit)
	_cfg.set_value("match", "time_limit_sec", mc.time_limit_sec)
	_cfg.set_value("match", "powerups_enabled", mc.powerups_enabled)
	_cfg.set_value("match", "pickup_respawn_scale", mc.pickup_respawn_scale)
	_cfg.set_value("match", "mutators", ",".join(PackedStringArray(mc.mutators.map(func(x: int) -> String: return str(x)))))
	_cfg.save(PATH)

func load_match_config() -> MatchConfig:
	var mc := MatchConfig.new()
	if _cfg.load(PATH) != OK and not FileAccess.file_exists(PATH):
		return mc
	_cfg.load(PATH)
	mc.map_id = str(_cfg.get_value("match", "map_id", "foundry"))
	mc.bot_count = int(_cfg.get_value("match", "bot_count", 7))
	mc.difficulty = int(_cfg.get_value("match", "difficulty", 1)) as MatchConfig.Difficulty
	mc.kill_limit = int(_cfg.get_value("match", "kill_limit", 25))
	mc.time_limit_sec = int(_cfg.get_value("match", "time_limit_sec", 480))
	mc.powerups_enabled = bool(_cfg.get_value("match", "powerups_enabled", true))
	mc.pickup_respawn_scale = float(_cfg.get_value("match", "pickup_respawn_scale", 1.0))
	var mut_str := str(_cfg.get_value("match", "mutators", ""))
	mc.mutators.clear()
	if mut_str != "":
		for p in mut_str.split(",", false):
			mc.mutators.append(int(p))
	return mc

func get_stat(key: String, default: Variant = 0) -> Variant:
	_cfg.load(PATH)
	return _cfg.get_value("stats", key, default)

func set_stat(key: String, value: Variant) -> void:
	_cfg.load(PATH)
	_cfg.set_value("stats", key, value)
	_cfg.save(PATH)

func add_stat(key: String, delta: int) -> void:
	set_stat(key, int(get_stat(key, 0)) + delta)
