extends Node
## Bus layout, SFX pooling, music crossfade. FALLBACK: synthesize at runtime if files missing.

const SFX_POOL := 16
const SFX3D_POOL := 32

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_primary: bool = true

func _ready() -> void:
	_ensure_buses()
	_build_pools()
	_load_or_synth_all()
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("apply_audio"):
		settings.call("apply_audio")

func _ensure_buses() -> void:
	_ensure_bus("Music", "Master")
	_ensure_bus("SFX", "Master")
	_ensure_bus("UI", "Master")
	_ensure_bus("Ambient", "Master")
	_ensure_bus("Muffle", "Master")
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0 and AudioServer.get_bus_effect_count(master_idx) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(master_idx, lim)
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0 and AudioServer.get_bus_effect_count(sfx_idx) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -12.0
		AudioServer.add_bus_effect(sfx_idx, comp)

func _ensure_bus(bus_name: String, send: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)

func _build_pools() -> void:
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in SFX3D_POOL:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 8.0
		p3.max_distance = 80.0
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		add_child(p3)
		_players_3d.append(p3)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)

func _load_or_synth_all() -> void:
	var keys: Array[String] = [
		"shot_pistol", "shot_smg", "shot_shotgun", "shot_plasma", "rocket_launch", "rocket_loop",
		"explosion", "rail_shot", "rail_zoom", "blade_swing", "blade_hit", "weapon_switch", "empty_click",
		"impact_world", "impact_flesh", "hitmarker", "hit_head", "kill_confirm", "damage_taken",
		"heartbeat_loop", "medal_1", "medal_2", "medal_3",
		"jump", "land_light", "land_heavy", "footstep", "slide_loop", "wallrun_loop", "wall_jump",
		"mantle", "grapple_fire", "grapple_attach", "grapple_reel_loop", "grapple_release", "jump_pad",
		"speed_whoosh_loop",
		"pickup_health", "pickup_armor", "pickup_ammo", "pickup_weapon", "powerup_pickup",
		"powerup_respawn", "pickup_respawn", "death", "respawn", "spawn_protection_end",
		"ui_hover", "ui_click", "ui_back", "ui_confirm", "ui_error",
		"countdown_tick", "countdown_go", "match_win", "match_lose",
		"amb_foundry", "amb_spire", "amb_sprawl",
		"music_menu", "music_match_a", "music_match_b", "music_results",
	]
	for k in keys:
		var path := "res://assets/audio/%s.wav" % k
		if ResourceLoader.exists(path):
			_streams[k] = load(path)
		else:
			_streams[k] = _synth_placeholder(k)

func _synth_placeholder(key: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = key.begins_with("music_")
	var dur := 0.12
	if key.ends_with("_loop") or key.begins_with("amb_") or key.begins_with("music_"):
		dur = 1.0 if not key.begins_with("music_") else 2.0
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var n := int(dur * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(n * (4 if stream.stereo else 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var base_f := 220.0 + float(rng.randi() % 600)
	for i in n:
		var t := float(i) / float(stream.mix_rate)
		var env := 1.0
		if not (key.ends_with("_loop") or key.begins_with("amb_") or key.begins_with("music_")):
			env = clampf(1.0 - t / dur, 0.0, 1.0)
		var s := sin(TAU * base_f * t) * 0.25 * env
		if key.begins_with("shot_") or key == "explosion" or key == "footstep":
			s = (rng.randf() * 2.0 - 1.0) * 0.2 * env
		var sample := int(clampf(s, -1.0, 1.0) * 32767.0)
		var o := i * (4 if stream.stereo else 2)
		data[o] = sample & 0xFF
		data[o + 1] = (sample >> 8) & 0xFF
		if stream.stereo:
			data[o + 2] = data[o]
			data[o + 3] = data[o + 1]
	stream.data = data
	if stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		stream.loop_end = n
	return stream

func play_sfx(sfx_name: String, position: Vector3 = Vector3.INF, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(sfx_name) as AudioStream
	if stream == null:
		return
	if position != Vector3.INF:
		var p3 := _steal_3d()
		p3.stream = stream
		p3.pitch_scale = pitch * randf_range(0.95, 1.05)
		p3.global_position = position
		p3.play()
	else:
		var p := _steal_2d("SFX")
		p.stream = stream
		p.pitch_scale = pitch * randf_range(0.95, 1.05)
		p.play()

func play_ui(sfx_name: String) -> void:
	var stream: AudioStream = _streams.get(sfx_name) as AudioStream
	if stream == null:
		return
	var p := _steal_2d("UI")
	p.stream = stream
	p.pitch_scale = 1.0
	p.play()

func play_music(sfx_name: String, crossfade: float = 1.5) -> void:
	var stream: AudioStream = _streams.get(sfx_name) as AudioStream
	if stream == null:
		return
	var incoming: AudioStreamPlayer = _music_b if _music_primary else _music_a
	var outgoing: AudioStreamPlayer = _music_a if _music_primary else _music_b
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(incoming, "volume_db", 0.0, crossfade)
	tw.tween_property(outgoing, "volume_db", -40.0, crossfade)
	tw.chain().tween_callback(func() -> void:
		outgoing.stop()
	)
	_music_primary = not _music_primary

func _steal_2d(bus: String) -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			p.bus = bus
			return p
	_players[0].bus = bus
	return _players[0]

func _steal_3d() -> AudioStreamPlayer3D:
	for p in _players_3d:
		if not p.playing:
			return p
	return _players_3d[0]

func has_stream(sfx_name: String) -> bool:
	return _streams.has(sfx_name)

func get_stream_keys() -> Array:
	return _streams.keys()
