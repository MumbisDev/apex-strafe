extends RefCounted
## Movement, pickup, event, UI and ambience sounds (GDD section 15). Preload-only, no class_name.

const S = preload("res://tools/audio/synth.gd")
const LOOP_LEN: int = 44100
const AMB_LEN: int = 176400 ## 4 s
const XFADE: int = 6615 ## 150 ms loop crossfade

static func build(out: Dictionary) -> void:
	_movement(out)
	_loops(out)
	_pickups(out)
	_ui(out)
	_ambience(out)

static func _variant_name(base: String, v: int) -> String:
	return base if v == 0 else "%s_%d" % [base, v + 1]

static func _movement(out: Dictionary) -> void:
	var jump := S.decay(S.sweep(S.Wave.SINE, 200.0, 420.0, 0.14), 0.07)
	S.mix_into(jump, S.burst(S.rng_for("jump"), 0.1, 400.0, 2500.0, 0.04), 0.5)
	out["jump"] = S.clip(jump, 0.6)
	for v in 2:
		var name := _variant_name("land_light", v)
		var m := S.burst(S.rng_for(name), 0.14, 0.0, 450.0 + 120.0 * float(v), 0.04)
		S.mix_into(m, S.decay(S.sweep(S.Wave.SINE, 90.0, 50.0, 0.12), 0.04), 0.8)
		out[name] = S.clip(m, 0.6)
	var heavy := S.burst(S.rng_for("land_heavy"), 0.35, 0.0, 600.0, 0.1)
	S.mix_into(heavy, S.decay(S.sweep(S.Wave.SINE, 80.0, 38.0, 0.3), 0.1), 1.3)
	out["land_heavy"] = S.clip(S.soft_clip(heavy, 1.4), 0.9)
	for v in 4:
		var name := _variant_name("footstep", v)
		var m := S.burst(S.rng_for(name), 0.09, 80.0, 700.0 + 180.0 * float(v), 0.03)
		S.mix_into(m, S.decay(S.sweep(S.Wave.SINE, 110.0 + 12.0 * float(v), 60.0, 0.08), 0.03), 0.6)
		out[name] = S.clip(m, 0.4)
	var wj := S.bandpass(S.burst(S.rng_for("wall_jump"), 0.1, 0.0, 0.0, 0.03), 1800.0, 1.0)
	S.mix_into(wj, S.decay(S.sweep(S.Wave.SINE, 250.0, 520.0, 0.14), 0.06), 0.6)
	out["wall_jump"] = S.clip(wj, 0.7)
	var mantle := S.burst(S.rng_for("mantle"), 0.3, 150.0, 1200.0, 0.1)
	S.mix_into(mantle, S.lowpass(S.decay(S.sweep(S.Wave.SAW, 140.0, 105.0, 0.3), 0.12), 500.0), 0.6)
	out["mantle"] = S.clip(mantle, 0.7)
	var gf := S.decay(S.sweep(S.Wave.SAW, 400.0, 3000.0, 0.16), 0.08)
	S.mix_into(gf, S.burst(S.rng_for("grapple_fire"), 0.12, 2500.0, 0.0, 0.03), 0.4)
	out["grapple_fire"] = S.clip(gf, 0.7)
	var ga := S.decay(S.sweep(S.Wave.SINE, 160.0, 60.0, 0.22), 0.06)
	S.mix_into(ga, S.burst(S.rng_for("grapple_attach"), 0.04, 600.0, 4000.0, 0.01), 0.7)
	out["grapple_attach"] = S.clip(ga, 0.9)
	out["grapple_release"] = S.clip(S.decay(S.sweep(S.Wave.SAW, 1500.0, 300.0, 0.13), 0.05), 0.6)
	var pad := S.decay(S.sweep(S.Wave.SINE, 200.0, 1200.0, 0.4), 0.2)
	S.mix_into(pad, S.decay(S.sweep(S.Wave.SQUARE, 100.0, 600.0, 0.4), 0.15), 0.25)
	out["jump_pad"] = S.clip(S.chorus(pad, 3.0, 5.0), 0.8)

static func _loop(src: PackedFloat32Array, gain: float) -> Dictionary:
	return S.clip(S.make_loop(src, LOOP_LEN), gain, true)

static func _loops(out: Dictionary) -> void:
	var n := LOOP_LEN + XFADE + 1
	var slide := S.bandpass(S.noise(float(n) / 44100.0, S.rng_for("slide_loop")), 1200.0, 0.6)
	out["slide_loop"] = _loop(S.lowpass(slide, 3000.0), 0.6)
	var wr := S.bandpass(S.noise(float(n) / 44100.0, S.rng_for("wallrun_loop")), 2200.0, 0.8)
	for i in wr.size():
		wr[i] *= 0.65 + 0.35 * sin(TAU * 14.0 * float(i) / 44100.0)
	S.mix_into(wr, S.tone(S.Wave.SINE, 70.0, float(n) / 44100.0), 0.4)
	out["wallrun_loop"] = _loop(wr, 0.5)
	var reel := S.silence(float(n) / 44100.0)
	for i in reel.size():
		var t := float(i) / 44100.0
		var rise := 1.0 + 0.5 * t
		reel[i] = (sin(TAU * 240.0 * rise * t) * 0.6 + sin(TAU * 480.0 * rise * t) * 0.25) * (0.6 + 0.4 * sin(TAU * 16.0 * t))
	out["grapple_reel_loop"] = _loop(reel, 0.5)
	var wind := S.bandpass(S.noise(float(n) / 44100.0, S.rng_for("speed_whoosh_loop")), 900.0, 0.5)
	wind = S.lowpass(wind, 1800.0)
	for i in wind.size():
		wind[i] *= 0.7 + 0.3 * sin(TAU * 2.0 * float(i) / 44100.0)
	out["speed_whoosh_loop"] = _loop(wind, 0.6)

static func _pickups(out: Dictionary) -> void:
	out["pickup_health"] = S.clip(_arp(S.Wave.SINE, [523.0, 784.0], 0.08, 0.3), 0.7)
	var armor := S.ring_mod(_arp(S.Wave.SQUARE, [330.0, 440.0], 0.07, 0.25), 220.0, 0.4)
	out["pickup_armor"] = S.clip(S.lowpass(armor, 5000.0), 0.5)
	var rng_a := S.rng_for("pickup_ammo")
	var ammo := S.silence(0.2)
	S.place(ammo, S.bandpass(S.burst(rng_a, 0.02, 0.0, 0.0, 0.005), 1800.0, 1.0), 1.0, 0.0)
	S.place(ammo, S.bandpass(S.burst(rng_a, 0.02, 0.0, 0.0, 0.005), 2600.0, 1.0), 0.9, 0.06)
	S.place(ammo, S.note(S.Wave.SQUARE, 600.0, 0.08, 0.03), 0.25, 0.1)
	out["pickup_ammo"] = S.clip(ammo, 0.6)
	var pw := _arp(S.Wave.TRI, [440.0, 554.0, 659.0], 0.07, 0.3)
	S.place(pw, S.bandpass(S.burst(S.rng_for("pickup_weapon"), 0.02, 0.0, 0.0, 0.005), 2200.0, 1.0), 0.6, 0.0)
	out["pickup_weapon"] = S.clip(pw, 0.7)
	var big := _arp(S.Wave.SQUARE, [220.0, 277.0, 330.0, 440.0, 554.0, 659.0, 880.0], 0.06, 0.4)
	S.mix_into(big, _arp(S.Wave.SAW, [110.0, 138.0, 165.0, 220.0, 277.0, 330.0, 440.0], 0.06, 0.4), 0.5)
	out["powerup_pickup"] = S.clip(S.comb_reverb(S.lowpass(big, 6000.0), 0.8, 0.25, 0.5), 0.8)
	var pr := S.mul(S.sweep(S.Wave.SINE, 300.0, 1800.0, 0.6), S.env_adsr(26460, 0.3, 0.1, 0.6, 0.2))
	S.mix_into(pr, S.mul(S.sweep(S.Wave.SINE, 603.0, 3610.0, 0.6), S.env_adsr(26460, 0.3, 0.1, 0.4, 0.2)), 0.3)
	out["powerup_respawn"] = S.clip(S.chorus(pr, 4.0, 6.0), 0.6)
	out["pickup_respawn"] = S.clip(_arp(S.Wave.SINE, [660.0, 880.0], 0.05, 0.12), 0.4)
	var death := S.decay(S.sweep(S.Wave.SAW, 400.0, 60.0, 0.8), 0.35)
	S.mix_into(death, S.lowpass_sweep(S.burst(S.rng_for("death"), 0.8, 0.0, 0.0, 0.3), 2500.0, 150.0), 0.6)
	out["death"] = S.clip(S.lowpass(death, 3000.0), 0.9)
	var respawn := S.mul(S.sweep(S.Wave.SINE, 150.0, 900.0, 0.5), S.env_adsr(22050, 0.05, 0.1, 0.7, 0.25))
	S.place(respawn, S.note(S.Wave.SINE, 1760.0, 0.3, 0.1), 0.3, 0.2)
	out["respawn"] = S.clip(respawn, 0.7)
	out["spawn_protection_end"] = S.clip(_arp(S.Wave.TRI, [880.0, 587.0], 0.08, 0.15), 0.5)

static func _ui(out: Dictionary) -> void:
	out["ui_hover"] = S.clip(S.note(S.Wave.TRI, 1200.0, 0.04, 0.012), 0.35)
	var click := S.note(S.Wave.SQUARE, 800.0, 0.05, 0.012)
	S.mix_into(click, S.burst(S.rng_for("ui_click"), 0.01, 2000.0, 0.0, 0.003), 0.5)
	out["ui_click"] = S.clip(S.lowpass(click, 6000.0), 0.5)
	out["ui_back"] = S.clip(S.decay(S.sweep(S.Wave.SINE, 500.0, 350.0, 0.08), 0.03), 0.5)
	out["ui_confirm"] = S.clip(_arp(S.Wave.SINE, [700.0, 1050.0], 0.05, 0.12), 0.5)
	var err := S.silence(0.3)
	for t: float in [0.0, 0.13]:
		S.place(err, S.note(S.Wave.SQUARE, 150.0, 0.1, 0.05), 0.5, t)
	out["ui_error"] = S.clip(S.lowpass(err, 1500.0), 0.6)
	out["countdown_tick"] = S.clip(S.note(S.Wave.SINE, 880.0, 0.1, 0.03), 0.6)
	var go := S.note(S.Wave.SINE, 1320.0, 0.5, 0.15)
	S.mix_into(go, S.note(S.Wave.SINE, 1760.0, 0.5, 0.15), 0.7)
	S.mix_into(go, S.note(S.Wave.TRI, 660.0, 0.5, 0.2), 0.5)
	out["countdown_go"] = S.clip(S.comb_reverb(go, 0.6, 0.2, 0.4), 0.8)
	var win := _arp(S.Wave.SQUARE, [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0], 0.14, 0.5)
	S.mix_into(win, _arp(S.Wave.SINE, [262.0, 330.0, 392.0, 523.0, 392.0, 523.0, 659.0], 0.14, 0.5), 0.8)
	out["match_win"] = S.clip(S.comb_reverb(S.lowpass(win, 5000.0), 1.0, 0.25, 0.6), 0.8)
	var lose := _arp(S.Wave.TRI, [440.0, 392.0, 349.0, 330.0, 262.0], 0.22, 0.6)
	S.mix_into(lose, _arp(S.Wave.SINE, [220.0, 196.0, 175.0, 165.0, 131.0], 0.22, 0.6), 0.8)
	out["match_lose"] = S.clip(S.comb_reverb(S.lowpass(lose, 3500.0), 1.0, 0.25, 0.6), 0.8)

static func _ambience(out: Dictionary) -> void:
	var secs := float(AMB_LEN + XFADE + 1) / 44100.0
	var rng_f := S.rng_for("amb_foundry")
	var hum := S.lowpass(S.tone(S.Wave.SAW, 55.0, secs), 400.0)
	S.mix_into(hum, S.lowpass(S.tone(S.Wave.SAW, 110.0, secs), 500.0), 0.4)
	for i in hum.size():
		hum[i] *= 0.8 + 0.2 * sin(TAU * 0.5 * float(i) / 44100.0)
	for k in 5:
		var t := rng_f.randf_range(0.2, 3.2)
		var clank := S.silence(0.6)
		for ratio: float in [1.0, 2.4, 3.9]:
			S.mix_into(clank, S.note(S.Wave.SINE, 320.0 * ratio * rng_f.randf_range(0.9, 1.1), 0.6, 0.12), 1.0 / ratio)
		S.place(hum, S.comb_reverb(clank, 0.9, 0.5, 0.3), 0.18, t)
	out["amb_foundry"] = S.clip(S.make_loop(hum, AMB_LEN), 0.5, true)
	var wind := S.bandpass(S.noise(secs, S.rng_for("amb_spire")), 700.0, 0.4)
	for i in wind.size():
		wind[i] *= 0.6 + 0.4 * sin(TAU * 0.25 * float(i) / 44100.0)
	var whistle := S.tone(S.Wave.SINE, 620.0, secs)
	for i in whistle.size():
		whistle[i] *= 0.04 * (1.0 + sin(TAU * 0.5 * float(i) / 44100.0))
	S.mix_into(wind, whistle, 1.0)
	out["amb_spire"] = S.clip(S.make_loop(wind, AMB_LEN), 0.5, true)
	var city := S.lowpass(S.tone(S.Wave.SQUARE, 60.0, secs), 600.0)
	S.mix_into(city, S.lowpass(S.tone(S.Wave.SQUARE, 120.0, secs), 900.0), 0.4)
	S.mix_into(city, S.highpass(S.noise(secs, S.rng_for("amb_sprawl")), 6000.0), 0.03)
	out["amb_sprawl"] = S.clip(S.make_loop(city, AMB_LEN), 0.45, true)

## Arpeggio of decaying notes `step` seconds apart.
static func _arp(kind: int, freqs: Array, step: float, tail: float) -> PackedFloat32Array:
	var m := S.silence(step * float(freqs.size()) + tail)
	for i in freqs.size():
		S.place(m, S.note(kind, float(freqs[i]), tail, tail * 0.35), 0.7, step * float(i))
	return m
