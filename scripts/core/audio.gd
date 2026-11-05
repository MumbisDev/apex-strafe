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
	## Quiet procedural stand-ins. Never emit a continuous midrange sine — that
	## reads as a painful mains-hum on Music/Ambient buses when looped.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var is_music := key.begins_with("music_")
	var is_amb := key.begins_with("amb_")
	var is_loop := key.ends_with("_loop") or is_amb or is_music
	stream.mix_rate = 32000 if is_music else 44100
	stream.stereo = is_music
	var dur := 0.12
	if is_music:
		dur = 4.0
	elif is_amb:
		dur = 3.0
	elif is_loop:
		dur = 1.0
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if is_loop else AudioStreamWAV.LOOP_DISABLED
	var n := int(dur * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(n * (4 if stream.stereo else 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	# Soft chord roots well below vocal range for pads; noise beds elsewhere.
	var root: float = 55.0 + float(abs(hash(key)) % 30)
	var fifth: float = root * 1.5
	var octave: float = root * 2.0
	var brown_l := 0.0
	var brown_r := 0.0
	for i in n:
		var t := float(i) / float(stream.mix_rate)
		var env := 1.0
		if not is_loop:
			# Short one-shots: fast attack, linear decay.
			var attack := clampf(t / 0.008, 0.0, 1.0)
			env = attack * clampf(1.0 - t / dur, 0.0, 1.0)
		# Seam fade for loops so the wrap is inaudible.
		if is_loop:
			var edge := 0.04
			var fade_in := clampf(t / edge, 0.0, 1.0)
			var fade_out := clampf((dur - t) / edge, 0.0, 1.0)
			env = minf(fade_in, fade_out)
		var s_l := 0.0
		var s_r := 0.0
		if is_music:
			# Very quiet low pad + soft brown noise — no piercing mid sine.
			var pad := (
				sin(TAU * root * t) * 0.35
				+ sin(TAU * fifth * t) * 0.22
				+ sin(TAU * octave * t) * 0.12
			) * 0.035
			brown_l = (brown_l + (rng.randf() * 2.0 - 1.0) * 0.02) * 0.98
			brown_r = (brown_r + (rng.randf() * 2.0 - 1.0) * 0.02) * 0.98
			s_l = (pad + brown_l * 0.04) * env
			s_r = (pad * 0.92 + brown_r * 0.05) * env
		elif is_amb:
			brown_l = (brown_l + (rng.randf() * 2.0 - 1.0) * 0.03) * 0.97
			s_l = brown_l * 0.06 * env
			s_r = s_l
		elif key.begins_with("shot_") or key == "explosion" or key == "footstep" or key == "impact_world":
			s_l = (rng.randf() * 2.0 - 1.0) * 0.18 * env
			s_r = s_l
		elif key.begins_with("ui_") or key.begins_with("countdown_") or key.begins_with("medal_"):
			var blip_f := 880.0 + float(abs(hash(key)) % 400)
			s_l = sin(TAU * blip_f * t) * 0.12 * env
			s_r = s_l
		else:
			# Short soft blip, not a held tone.
			var f := 180.0 + float(abs(hash(key)) % 220)
			s_l = sin(TAU * f * t) * 0.1 * env
			s_r = s_l
		_write_sample(data, i, stream.stereo, s_l, s_r)
	stream.data = data
	if stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		stream.loop_begin = 0
		stream.loop_end = n
	return stream

func _write_sample(data: PackedByteArray, i: int, stereo: bool, left: float, right: float) -> void:
	var sl := int(clampf(left, -1.0, 1.0) * 32767.0)
	var sr := int(clampf(right, -1.0, 1.0) * 32767.0)
	var o := i * (4 if stereo else 2)
	data[o] = sl & 0xFF
	data[o + 1] = (sl >> 8) & 0xFF
	if stereo:
		data[o + 2] = sr & 0xFF
		data[o + 3] = (sr >> 8) & 0xFF

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
	# Keep placeholder music well under SFX; file music can sit closer to 0 dB.
	var target_db := -14.0 if not ResourceLoader.exists("res://assets/audio/%s.wav" % sfx_name) else -6.0
	incoming.volume_db = -40.0
	incoming.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(incoming, "volume_db", target_db, crossfade)
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
