extends SceneTree
## Synthesizes every sound in GDD section 15 to res://assets/audio/*.wav (16-bit PCM, deterministic seed).
## SFX are mono 44.1 kHz, music is stereo 32 kHz. Loop clips carry a WAV "smpl" chunk so Godot imports them looped.
##   godot --headless --path . --script res://tools/generate_audio.gd
##   godot --headless --path . --import      (so load() can see the new files)
## Exit code 1 when a required sound is missing or fails verification.

const S = preload("res://tools/audio/synth.gd")
const SfxCombat = preload("res://tools/audio/sfx_combat.gd")
const SfxWorld = preload("res://tools/audio/sfx_world.gd")
const MusicGen = preload("res://tools/audio/music_gen.gd")

const OUT_DIR: String = "res://assets/audio"
const TARGET_PEAK_DB: float = -1.0
const MIN_RMS: float = 0.003
const STING_FADE_MS: float = 800.0
## Names are the Audio.play_sfx / play_ui / play_music keys (GDD section 15).
const REQUIRED: PackedStringArray = [
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

func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var clips: Dictionary = {}
	SfxCombat.build(clips)
	SfxWorld.build(clips)
	MusicGen.build(clips)
	var errors := 0
	for key in REQUIRED:
		if not clips.has(key):
			push_error("generate_audio: required sound '%s' was not synthesized" % key)
			errors += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var names: Array = clips.keys()
	names.sort()
	for sound_name: String in names:
		var clip := _finish(sound_name, clips[sound_name] as Dictionary)
		var problem := _verify(clip)
		var path := "%s/%s.wav" % [OUT_DIR, sound_name]
		if problem != "":
			push_error("generate_audio: %s failed verification: %s" % [sound_name, problem])
			errors += 1
		elif not _write_wav(path, clip):
			push_error("generate_audio: could not write %s" % path)
			errors += 1
	print("generate_audio: %d files, %d errors, %.1f s" % [names.size(), errors, float(Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if errors > 0 else 0)

## Normalizes (jointly for stereo) to TARGET_PEAK_DB scaled by the clip gain; fades non-loops.
func _finish(sound_name: String, clip: Dictionary) -> Dictionary:
	var l := clip["l"] as PackedFloat32Array
	var r := clip["r"] as PackedFloat32Array
	var rate := int(clip["rate"])
	var loop := bool(clip["loop"])
	var pk := maxf(S.peak(l), S.peak(r))
	if pk > 0.00001:
		var g := pow(10.0, TARGET_PEAK_DB / 20.0) / pk * minf(float(clip["gain"]), 1.0)
		S.scale(l, g)
		if not r.is_empty():
			S.scale(r, g)
	if not loop:
		var out_ms := STING_FADE_MS if sound_name == "music_results" else 8.0
		S.fade_edges(l, 2.0, out_ms, rate)
		if not r.is_empty():
			S.fade_edges(r, 2.0, out_ms, rate)
	return {"l": l, "r": r, "rate": rate, "loop": loop, "name": sound_name}

## Returns "" when the clip is audible, below 0 dBFS and (for loops) free of a click at the seam.
func _verify(clip: Dictionary) -> String:
	for key in ["l", "r"]:
		var x := clip[key] as PackedFloat32Array
		if x.is_empty():
			continue
		var sum_sq := 0.0
		var sum_delta := 0.0
		for i in x.size():
			sum_sq += x[i] * x[i]
			if i > 0:
				sum_delta += absf(x[i] - x[i - 1])
		var rms := sqrt(sum_sq / float(x.size()))
		if rms < MIN_RMS:
			return "silent (rms %.5f)" % rms
		if S.peak(x) >= 1.0:
			return "peak at or above 0 dBFS"
		if bool(clip["loop"]):
			var seam := absf(x[0] - x[x.size() - 1])
			var typical := sum_delta / float(x.size() - 1)
			if seam > maxf(typical * 4.0, 0.05):
				return "click at loop seam (%.4f vs typical %.4f)" % [seam, typical]
	return ""

func _write_wav(path: String, clip: Dictionary) -> bool:
	var l := clip["l"] as PackedFloat32Array
	var r := clip["r"] as PackedFloat32Array
	var stereo := not r.is_empty()
	var channels := 2 if stereo else 1
	var rate := int(clip["rate"])
	var frames := l.size()
	var loop := bool(clip["loop"])
	var data := PackedByteArray()
	data.resize(frames * channels * 2)
	for i in frames:
		data.encode_s16(i * channels * 2, clampi(roundi(l[i] * 32767.0), -32767, 32767))
		if stereo:
			data.encode_s16((i * channels + 1) * 2, clampi(roundi(r[i] * 32767.0), -32767, 32767))
	var smpl_size := 36 + 24
	var riff_size := 4 + 24 + (8 + smpl_size if loop else 0) + 8 + data.size()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(riff_size)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(channels)
	f.store_32(rate)
	f.store_32(rate * channels * 2)
	f.store_16(channels * 2)
	f.store_16(16)
	if loop:
		f.store_buffer("smpl".to_ascii_buffer())
		f.store_32(smpl_size)
		for v in [0, 0, int(1.0e9 / float(rate)), 60, 0, 0, 0, 1, 0]:
			f.store_32(int(v))
		for v in [0, 0, 0, frames - 1, 0, 0]: ## cue id, forward loop, start, end, fraction, play count
			f.store_32(int(v))
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	return true
