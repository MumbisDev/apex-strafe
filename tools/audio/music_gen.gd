extends RefCounted
## Procedural music (GDD section 15): A minor pentatonic over i-VI-III-VII, 16 bars, seeded.
## Synthesized kick/snare/hats, saw bass with filter envelope, square arpeggio, detuned saw pad.
## Loops wrap their reverb/delay tails onto the start so the end flows into the beginning.

const S = preload("res://tools/audio/synth.gd")
const SR: int = 32000
const TAIL_SECONDS: float = 1.0
## Pad voicings (Am, F, C, G) and bass roots (A2, F2, C3, G2).
const CHORDS: Array = [[57, 60, 64], [57, 60, 65], [60, 64, 67], [59, 62, 67]]
const BASS_ROOTS: Array[int] = [45, 41, 48, 43]
const PENTA: Array[int] = [0, 3, 5, 7, 10]
const PROG_LOOP: Array[int] = [0, 1, 2, 3]
const PROG_STING: Array[int] = [0, 1, 2, 0]

static func build(out: Dictionary) -> void:
	out["music_menu"] = _render(_menu())
	out["music_match_a"] = _render(_match_a())
	out["music_match_b"] = _render(_match_b())
	out["music_results"] = _render(_sting())

# -- track configs ------------------------------------------------------------------

static func _base(track: String, bpm: float) -> Dictionary:
	return {
		"name": track, "bpm": bpm, "bars": 16, "loop": true, "prog": PROG_LOOP,
		"kick": [], "kick_gain": 0.9, "snare": [], "snare_gain": 0.5, "hat_every": 2, "hat_gain": 0.18, "open": [],
		"bass": [], "bass_gain": 0.5, "arp_step": 2, "arp_prob": 0.7, "arp_gain": 0.16, "pad_gain": 0.25,
		"reverb": 0.5,
	}

static func _menu() -> Dictionary:
	var c := _base("music_menu", 100.0)
	c.merge({"kick": [0, 10], "kick_gain": 0.6, "snare": [8], "snare_gain": 0.35, "hat_every": 2, "hat_gain": 0.1,
		"bass": [[0, 6, 0], [6, 4, 0], [10, 6, 0]], "bass_gain": 0.45, "arp_step": 2, "arp_prob": 0.55,
		"arp_gain": 0.14, "pad_gain": 0.32, "reverb": 0.7}, true)
	return c

static func _match_a() -> Dictionary:
	var c := _base("music_match_a", 138.0)
	var bass: Array = []
	var octs: Array[int] = [0, 0, 12, 0, 0, 0, 12, 0]
	for i in 8:
		bass.append([i * 2, 2, octs[i]])
	c.merge({"kick": [0, 4, 8, 12], "snare": [4, 12], "hat_every": 2, "open": [14], "bass": bass}, true)
	return c

static func _match_b() -> Dictionary:
	var c := _base("music_match_b", 150.0)
	var bass: Array = []
	var octs: Array[int] = [0, 0, 12, 0, 0, 12, 0, 0, 0, 0, 12, 0, 0, 12, 0, 12]
	for i in 16:
		bass.append([i, 1, octs[i]])
	c.merge({"kick": [0, 4, 8, 12, 14], "kick_gain": 1.0, "snare": [4, 12, 15], "hat_every": 1, "hat_gain": 0.14,
		"open": [14], "bass": bass, "bass_gain": 0.5, "arp_step": 1, "arp_prob": 0.8, "arp_gain": 0.14}, true)
	return c

static func _sting() -> Dictionary:
	var c := _base("music_results", 120.0)
	c.merge({"bars": 4, "loop": false, "prog": PROG_STING, "kick": [0], "snare": [], "hat_every": 4, "hat_gain": 0.12,
		"bass": [[0, 12, 0]], "bass_gain": 0.5, "arp_step": 1, "arp_prob": 0.6, "arp_gain": 0.18,
		"pad_gain": 0.3, "reverb": 0.8}, true)
	return c

# -- rendering -------------------------------------------------------------------------

static func _zeros(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	return b

static func _render(c: Dictionary) -> Dictionary:
	var beat := 60.0 / float(c["bpm"]) * float(SR)
	var step := beat * 0.25
	var bar := int(round(beat * 4.0))
	var bars := int(c["bars"])
	var loop_len := bar * bars
	var total := loop_len + int(TAIL_SECONDS * float(SR))
	var rng := S.rng_for(str(c["name"]))
	var drums := _zeros(total)
	var bass := _zeros(total)
	var arp := _zeros(total)
	var pad_l := _zeros(total)
	var pad_r := _zeros(total)
	var kick := _kick()
	var snare := _snare(rng)
	var hat := _hat(rng, 0.05, 0.012)
	var open_hat := _hat(rng, 0.2, 0.06)
	var bass_cache: Dictionary = {}
	var pad_cache: Dictionary = {}
	var arp_cache: Dictionary = {}
	var prog: Array = c["prog"]
	var arp_idx := 5
	for b in bars:
		var chord_i: int = int(prog[b % prog.size()])
		var base := b * 16
		for s: int in c["kick"]:
			S.mix_into(drums, kick, float(c["kick_gain"]), int(round(float(base + s) * step)))
		for s: int in c["snare"]:
			S.mix_into(drums, snare, float(c["snare_gain"]), int(round(float(base + s) * step)))
		for s in range(0, 16, int(c["hat_every"])):
			var accent := 1.0 if s % 4 == 0 else 0.6
			S.mix_into(drums, hat, float(c["hat_gain"]) * accent, int(round(float(base + s) * step)))
		for s: int in c["open"]:
			S.mix_into(drums, open_hat, float(c["hat_gain"]) * 1.2, int(round(float(base + s) * step)))
		for note: Array in c["bass"]:
			var midi := BASS_ROOTS[chord_i] + int(note[2])
			var len_steps := int(note[1])
			var key := "%d_%d" % [midi, len_steps]
			if not bass_cache.has(key):
				bass_cache[key] = _bass_note(midi, int(round(step * float(len_steps))))
			S.mix_into(bass, bass_cache[key] as PackedFloat32Array, 1.0, int(round(float(base + int(note[0])) * step)))
		for s in range(0, 16, int(c["arp_step"])):
			var play := rng.randf() <= float(c["arp_prob"])
			arp_idx = clampi(arp_idx + rng.randi_range(-2, 2), 0, 9)
			var use_chord := rng.randf() < 0.5
			if not play:
				continue
			var octave := 12 * floori(float(arp_idx) / 5.0)
			var chord: Array = CHORDS[chord_i]
			var midi := (int(chord[arp_idx % 3]) + 12 + octave) if use_chord else (69 + PENTA[arp_idx % 5] + octave)
			if not arp_cache.has(midi):
				arp_cache[midi] = S.lowpass(S.note(S.Wave.SQUARE, S.midi_hz(float(midi)), 0.28, 0.08, SR), 5500.0, SR)
			S.mix_into(arp, arp_cache[midi] as PackedFloat32Array, 1.0, int(round(float(base + s) * step)))
		if not pad_cache.has(chord_i):
			pad_cache[chord_i] = _pad(chord_i, bar)
		var pads: Array = pad_cache[chord_i]
		S.mix_into(pad_l, pads[0] as PackedFloat32Array, 1.0, b * bar)
		S.mix_into(pad_r, pads[1] as PackedFloat32Array, 1.0, b * bar)
	arp = S.feedback_delay(arp, beat * 0.75 / float(SR), 0.38, 0.4, 0.0, SR)
	var send := _zeros(total)
	for i in total:
		send[i] = (pad_l[i] + pad_r[i]) * 0.5 + arp[i] * 0.5
	var wet := S.comb_reverb(send, 1.4, 1.0, 0.0, SR)
	var l := _zeros(total)
	var r := _zeros(total)
	var pg := float(c["pad_gain"])
	var ag := float(c["arp_gain"])
	var bg := float(c["bass_gain"])
	var rv := float(c["reverb"]) * 0.4
	for i in total:
		var mid := drums[i] + bass[i] * bg
		l[i] = mid + arp[i] * ag * 0.8 + pad_l[i] * pg + wet[i] * rv
		r[i] = mid + arp[i] * ag + pad_r[i] * pg + wet[i] * rv
	l = S.soft_clip(l, 1.3)
	r = S.soft_clip(r, 1.3)
	if bool(c["loop"]):
		S.wrap_tail(l, loop_len)
		S.wrap_tail(r, loop_len)
	else:
		l.resize(loop_len)
		r.resize(loop_len)
	return {"l": l, "r": r, "rate": SR, "loop": bool(c["loop"]), "gain": 0.8}

# -- instruments -----------------------------------------------------------------------

static func _kick() -> PackedFloat32Array:
	var k := S.decay(S.sweep(S.Wave.SINE, 150.0, 45.0, 0.3, SR), 0.09, SR)
	return S.soft_clip(k, 1.5)

static func _snare(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := S.bandpass(S.burst(rng, 0.2, 0.0, 0.0, 0.07, SR), 1800.0, 0.8, SR)
	var m := S.silence(0.2, SR)
	S.mix_into(m, n, 1.4)
	S.mix_into(m, S.note(S.Wave.SINE, 190.0, 0.15, 0.05, SR), 0.6)
	return m

static func _hat(rng: RandomNumberGenerator, seconds: float, tau: float) -> PackedFloat32Array:
	return S.burst(rng, seconds, 7000.0, 0.0, tau, SR)

static func _bass_note(midi: int, n: int) -> PackedFloat32Array:
	var secs := float(n) / float(SR)
	var f := S.midi_hz(float(midi))
	var saw := S.lowpass_sweep(S.tone(S.Wave.SAW, f, secs, SR), 2200.0, 260.0, SR)
	S.mix_into(saw, S.tone(S.Wave.SINE, f, secs, SR), 0.7)
	return S.mul(saw, S.env_adsr(saw.size(), 0.005, 0.06, 0.75, 0.04, SR))

## Returns [left, right]: three-note detuned saw chord, opposite detune per side.
static func _pad(chord_i: int, bar: int) -> Array:
	var secs := float(bar + int(0.35 * float(SR))) / float(SR)
	var pl := S.silence(secs, SR)
	var pr := S.silence(secs, SR)
	var chord: Array = CHORDS[chord_i]
	for midi in chord:
		var f := S.midi_hz(float(midi))
		var up := S.tone(S.Wave.SAW, f * 1.004, secs, SR)
		var down := S.tone(S.Wave.SAW, f * 0.996, secs, SR)
		S.mix_into(pl, up, 0.22, 0)
		S.mix_into(pl, down, 0.12, 0)
		S.mix_into(pr, down, 0.22, 0)
		S.mix_into(pr, up, 0.12, 0)
	var env := S.env_adsr(pl.size(), 0.3, 0.2, 0.85, 0.35, SR)
	return [S.mul(S.lowpass(pl, 1500.0, SR), env), S.mul(S.lowpass(pr, 1500.0, SR), env.duplicate())]
