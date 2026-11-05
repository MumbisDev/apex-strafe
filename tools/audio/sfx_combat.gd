extends RefCounted
## Weapon, impact and feedback sounds (GDD section 15). Preload-only, no class_name.

const S = preload("res://tools/audio/synth.gd")

static func build(out: Dictionary) -> void:
	_weapons(out)
	_impacts(out)
	_feedback(out)

static func _variant_name(base: String, v: int) -> String:
	return base if v == 0 else "%s_%d" % [base, v + 1]

static func _weapons(out: Dictionary) -> void:
	for v in 2:
		var p := 1.0 + 0.12 * float(v)
		var rng := S.rng_for(_variant_name("shot_pistol", v))
		var m := S.silence(0.18)
		S.mix_into(m, S.burst(rng, 0.12, 800.0, 0.0, 0.025), 0.9)
		S.mix_into(m, S.decay(S.sweep(S.Wave.SQUARE, 600.0 * p, 200.0 * p, 0.14), 0.05), 0.5)
		out[_variant_name("shot_pistol", v)] = S.clip(S.lowpass(m, 9000.0), 0.9)
	var smg_pitch: Array[float] = [1.0, 1.1, 0.92]
	for v in 3:
		var p := smg_pitch[v]
		var rng := S.rng_for(_variant_name("shot_smg", v))
		var m := S.silence(0.09)
		S.mix_into(m, S.bandpass(S.burst(rng, 0.07, 0.0, 0.0, 0.012), 2500.0 * p, 0.8), 1.2)
		S.mix_into(m, S.decay(S.sweep(S.Wave.SQUARE, 420.0 * p, 160.0 * p, 0.08), 0.025), 0.45)
		out[_variant_name("shot_smg", v)] = S.clip(m, 0.8)
	var rng_sg := S.rng_for("shot_shotgun")
	var sg := S.silence(0.4)
	var body := S.lowpass_sweep(S.noise(0.4, rng_sg), 7000.0, 500.0)
	S.mix_into(sg, S.decay(body, 0.12), 1.0)
	S.mix_into(sg, S.decay(S.sweep(S.Wave.SINE, 80.0, 48.0, 0.25), 0.07), 1.3)
	S.mix_into(sg, S.burst(rng_sg, 0.03, 2500.0, 0.0, 0.006), 0.5)
	out["shot_shotgun"] = S.clip(S.soft_clip(sg, 1.6), 1.0)
	var pl := S.decay(S.sweep(S.Wave.SAW, 900.0, 300.0, 0.22), 0.09)
	pl = S.chorus(pl, 3.0, 0.7)
	S.mix_into(pl, S.decay(S.sweep(S.Wave.SINE, 450.0, 150.0, 0.22), 0.07), 0.6)
	out["shot_plasma"] = S.clip(S.lowpass(S.soft_clip(pl, 1.4), 7000.0), 0.8)
	var rng_rl := S.rng_for("rocket_launch")
	var rl := S.lowpass_sweep(S.noise(0.7, rng_rl), 400.0, 2500.0)
	S.mul(rl, S.env_adsr(rl.size(), 0.1, 0.3, 0.3, 0.3))
	S.mix_into(rl, S.decay(S.sweep(S.Wave.SINE, 90.0, 45.0, 0.4), 0.15), 1.1)
	S.mix_into(rl, S.lowpass(S.mul(S.tone(S.Wave.SAW, 120.0, 0.7), S.env_adsr(30870, 0.05, 0.2, 0.5, 0.3)), 600.0), 0.5)
	out["rocket_launch"] = S.clip(rl, 0.9)
	var rng_loop := S.rng_for("rocket_loop")
	var loop_len := 44100
	var rk := S.bandpass(S.noise(1.0 + 0.15, rng_loop), 600.0, 0.7)
	rk = S.lowpass(rk, 2500.0)
	S.mix_into(rk, S.lowpass(S.tone(S.Wave.SAW, 70.0, 1.0 + 0.15), 300.0), 0.7)
	out["rocket_loop"] = S.clip(S.make_loop(rk, loop_len), 0.6, true)
	var rng_ex := S.rng_for("explosion")
	var ex := S.lowpass_sweep(S.noise(2.2, rng_ex), 6000.0, 120.0)
	S.decay(ex, 0.45, S.SR, 0.002)
	S.mix_into(ex, S.decay(S.sweep(S.Wave.SINE, 70.0, 32.0, 1.4), 0.5), 1.3)
	for k in 40:
		var t := 0.15 + pow(rng_ex.randf(), 1.6) * 1.7
		var crackle := S.burst(rng_ex, 0.012, 2000.0, 0.0, 0.004)
		S.place(ex, crackle, 0.35 * exp(-t * 1.2), t)
	ex = S.comb_reverb(ex, 0.8, 0.2, 0.3)
	out["explosion"] = S.clip(S.soft_clip(ex, 1.5), 1.0)
	var rail := S.decay(S.sweep(S.Wave.SINE, 2000.0, 200.0, 0.5), 0.18)
	rail = S.ring_mod(rail, 800.0, 0.5)
	S.mix_into(rail, S.burst(S.rng_for("rail_shot"), 0.1, 3000.0, 0.0, 0.02), 0.4)
	out["rail_shot"] = S.clip(S.comb_reverb(rail, 0.9, 0.3, 0.6), 0.9)
	var rz := S.mul(S.sweep(S.Wave.TRI, 300.0, 1800.0, 0.8), S.env_adsr(35280, 0.5, 0.1, 0.7, 0.2))
	S.mix_into(rz, S.mul(S.sweep(S.Wave.SINE, 600.0, 3600.0, 0.8), S.env_adsr(35280, 0.5, 0.1, 0.5, 0.2)), 0.3)
	out["rail_zoom"] = S.clip(rz, 0.5)
	var sw := S.bandpass(S.noise(0.28, S.rng_for("blade_swing")), 1800.0, 1.2)
	sw = S.lowpass_sweep(sw, 800.0, 4500.0)
	S.mul(sw, S.env_adsr(sw.size(), 0.1, 0.05, 0.6, 0.12))
	out["blade_swing"] = S.clip(sw, 0.8)
	var bh := S.silence(0.6)
	for ratio: float in [1.0, 2.76, 5.4, 8.93]:
		var amp := 1.0 / sqrt(ratio)
		S.mix_into(bh, S.note(S.Wave.SINE, 520.0 * ratio, 0.6, 0.25 * amp), amp)
	S.mix_into(bh, S.burst(S.rng_for("blade_hit"), 0.012, 3000.0, 0.0, 0.004), 0.8)
	out["blade_hit"] = S.clip(bh, 0.9)
	var ws := S.silence(0.2)
	var rng_ws := S.rng_for("weapon_switch")
	S.place(ws, S.bandpass(S.burst(rng_ws, 0.015, 0.0, 0.0, 0.004), 2000.0, 1.0), 1.0, 0.0)
	S.place(ws, S.bandpass(S.burst(rng_ws, 0.015, 0.0, 0.0, 0.004), 3000.0, 1.0), 0.9, 0.07)
	S.place(ws, S.note(S.Wave.SQUARE, 800.0, 0.06, 0.02), 0.2, 0.03)
	out["weapon_switch"] = S.clip(ws, 0.6)
	var ec := S.burst(S.rng_for("empty_click"), 0.05, 1500.0, 0.0, 0.008)
	S.mix_into(ec, S.note(S.Wave.SINE, 300.0, 0.03, 0.01), 0.5)
	out["empty_click"] = S.clip(ec, 0.6)

static func _impacts(out: Dictionary) -> void:
	for v in 3:
		var name := _variant_name("impact_world", v)
		var rng := S.rng_for(name)
		var m := S.silence(0.14)
		S.mix_into(m, S.bandpass(S.burst(rng, 0.12, 0.0, 0.0, 0.025), 1200.0 + 300.0 * float(v), 0.7), 1.3)
		S.mix_into(m, S.decay(S.sweep(S.Wave.SINE, 220.0, 90.0, 0.08), 0.03), 0.5)
		out[name] = S.clip(m, 0.7)
	for v in 2:
		var name := _variant_name("impact_flesh", v)
		var m := S.burst(S.rng_for(name), 0.14, 0.0, 700.0 + 150.0 * float(v), 0.04)
		S.mix_into(m, S.decay(S.sweep(S.Wave.SINE, 140.0, 60.0, 0.12), 0.04), 0.9)
		out[name] = S.clip(m, 0.7)

static func _feedback(out: Dictionary) -> void:
	out["hitmarker"] = S.clip(S.note(S.Wave.SINE, 1800.0, 0.03, 0.008), 0.7)
	var hh := S.note(S.Wave.SINE, 3200.0, 0.1, 0.02)
	S.mix_into(hh, S.note(S.Wave.SINE, 4800.0, 0.1, 0.015), 0.4)
	out["hit_head"] = S.clip(hh, 0.7)
	var kc := S.silence(0.4)
	S.place(kc, S.note(S.Wave.TRI, 880.0, 0.2, 0.06), 0.8, 0.0)
	S.place(kc, S.note(S.Wave.TRI, 1320.0, 0.3, 0.12), 0.9, 0.09)
	S.place(kc, S.note(S.Wave.SINE, 2640.0, 0.3, 0.1), 0.25, 0.09)
	out["kill_confirm"] = S.clip(S.comb_reverb(kc, 0.5, 0.15, 0.3), 0.8)
	var dt := S.decay(S.sweep(S.Wave.SINE, 90.0, 45.0, 0.25), 0.08)
	S.mix_into(dt, S.burst(S.rng_for("damage_taken"), 0.1, 0.0, 300.0, 0.04), 0.5)
	out["damage_taken"] = S.clip(dt, 0.9)
	var hb := S.silence(1.0)
	for beat: Array in [[0.0, 1.0], [0.3, 0.7]]:
		var thump := S.decay(S.sweep(S.Wave.SINE, 70.0, 45.0, 0.18), 0.05)
		S.place(hb, S.lowpass(thump, 160.0), float(beat[1]), float(beat[0]))
	out["heartbeat_loop"] = S.clip(hb, 0.9, true)
	var chimes: Array[Array] = [[880.0, 1319.0], [880.0, 1047.0, 1319.0], [880.0, 1047.0, 1319.0, 1760.0, 2093.0]]
	for i in chimes.size():
		var m := S.silence(1.0)
		var notes: Array = chimes[i]
		for j in notes.size():
			var f := float(notes[j])
			var c := S.note(S.Wave.SINE, f, 0.8, 0.25)
			S.mix_into(c, S.note(S.Wave.SINE, f * 2.0, 0.8, 0.18), 0.3)
			S.mix_into(c, S.note(S.Wave.SINE, f * 3.0, 0.8, 0.1), 0.1)
			S.place(m, c, 0.8, 0.09 * float(j))
		out["medal_%d" % (i + 1)] = S.clip(S.comb_reverb(m, 0.8, 0.25, 0.4), 0.8)
