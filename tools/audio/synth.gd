extends RefCounted
## Deterministic synth toolkit for tools/generate_audio.gd. Buffers are mono PackedFloat32Array in [-1, 1].
## Deliberately has no class_name: it is preload()ed so the generator runs before the class cache exists.

const SR: int = 44100
enum Wave { SINE, SQUARE, SAW, TRI }

# -- buffers -------------------------------------------------------------------

static func silence(seconds: float, sr: int = SR) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(1, int(seconds * float(sr))))
	return b

static func noise(seconds: float, rng: RandomNumberGenerator, sr: int = SR) -> PackedFloat32Array:
	var b := silence(seconds, sr)
	for i in b.size():
		b[i] = rng.randf() * 2.0 - 1.0
	return b

static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)

## Adds `src * gain` into `dst` starting at `offset` samples; grows `dst` if needed.
static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float = 1.0, offset: int = 0) -> PackedFloat32Array:
	if offset + src.size() > dst.size():
		dst.resize(offset + src.size())
	for i in src.size():
		dst[offset + i] += src[i] * gain
	return dst

static func mul(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := mini(a.size(), b.size())
	for i in n:
		a[i] *= b[i]
	return a

static func scale(a: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	for i in a.size():
		a[i] *= gain
	return a

static func concat_silence(a: PackedFloat32Array, seconds: float, sr: int = SR) -> PackedFloat32Array:
	a.resize(a.size() + int(seconds * float(sr)))
	return a

# -- oscillators ------------------------------------------------------------------

static func wave_sample(kind: int, ph: float) -> float:
	match kind:
		Wave.SQUARE:
			return 1.0 if ph < 0.5 else -1.0
		Wave.SAW:
			return 2.0 * ph - 1.0
		Wave.TRI:
			return 4.0 * absf(ph - 0.5) - 1.0
	return sin(TAU * ph)

## Oscillator with an exponential pitch sweep f0 -> f1 across the buffer.
static func sweep(kind: int, f0: float, f1: float, seconds: float, sr: int = SR, phase0: float = 0.0) -> PackedFloat32Array:
	var out := silence(seconds, sr)
	var n := out.size()
	var mult := pow(f1 / f0, 1.0 / float(maxi(n - 1, 1)))
	var f := f0
	var ph := phase0
	for i in n:
		ph += f / float(sr)
		ph -= floorf(ph)
		out[i] = wave_sample(kind, ph)
		f *= mult
	return out

static func tone(kind: int, freq: float, seconds: float, sr: int = SR) -> PackedFloat32Array:
	return sweep(kind, freq, freq, seconds, sr)

# -- envelopes --------------------------------------------------------------------

static func env_exp(n: int, tau: float, sr: int = SR, attack: float = 0.001) -> PackedFloat32Array:
	var e := PackedFloat32Array()
	e.resize(n)
	var a := maxf(attack * float(sr), 1.0)
	for i in n:
		var t := float(i) / float(sr)
		e[i] = exp(-t / tau) * minf(float(i) / a, 1.0)
	return e

static func env_adsr(n: int, a: float, d: float, s: float, r: float, sr: int = SR) -> PackedFloat32Array:
	var e := PackedFloat32Array()
	e.resize(n)
	var an := a * float(sr)
	var dn := d * float(sr)
	var rn := r * float(sr)
	var rel_start := float(n) - rn
	for i in n:
		var f := float(i)
		var v := 1.0
		if f < an:
			v = f / maxf(an, 1.0)
		elif f < an + dn:
			v = lerpf(1.0, s, (f - an) / maxf(dn, 1.0))
		else:
			v = s
		if f > rel_start:
			v *= clampf((float(n) - f) / maxf(rn, 1.0), 0.0, 1.0)
		e[i] = v
	return e

## Shapes `x` with an exponential decay (tau seconds).
static func decay(x: PackedFloat32Array, tau: float, sr: int = SR, attack: float = 0.001) -> PackedFloat32Array:
	return mul(x, env_exp(x.size(), tau, sr, attack))

# -- filters ----------------------------------------------------------------------

static func lowpass(x: PackedFloat32Array, cutoff: float, sr: int = SR) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / float(sr))
	var out := x.duplicate()
	var y := 0.0
	for i in out.size():
		y += a * (out[i] - y)
		out[i] = y
	return out

static func lowpass_sweep(x: PackedFloat32Array, c0: float, c1: float, sr: int = SR) -> PackedFloat32Array:
	var out := x.duplicate()
	var n := out.size()
	var mult := pow(c1 / c0, 1.0 / float(maxi(n - 1, 1)))
	var c := c0
	var y := 0.0
	for i in n:
		y += (1.0 - exp(-TAU * c / float(sr))) * (out[i] - y)
		out[i] = y
		c *= mult
	return out

static func highpass(x: PackedFloat32Array, cutoff: float, sr: int = SR) -> PackedFloat32Array:
	var lp := lowpass(x, cutoff, sr)
	var out := x.duplicate()
	for i in out.size():
		out[i] -= lp[i]
	return out

## RBJ band-pass biquad (constant 0 dB peak gain).
static func bandpass(x: PackedFloat32Array, freq: float, q: float, sr: int = SR) -> PackedFloat32Array:
	var w0 := TAU * freq / float(sr)
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w0) / a0
	var a2 := (1.0 - alpha) / a0
	var out := x.duplicate()
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in out.size():
		var x0 := out[i]
		var y0 := b0 * x0 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x0
		y2 = y1
		y1 = y0
		out[i] = y0
	return out

# -- effects ----------------------------------------------------------------------

static func bitcrush(x: PackedFloat32Array, bits: int, hold: int) -> PackedFloat32Array:
	var levels := pow(2.0, float(bits - 1))
	var out := x.duplicate()
	var held := 0.0
	for i in out.size():
		if i % maxi(hold, 1) == 0:
			held = roundf(out[i] * levels) / levels
		out[i] = held
	return out

static func ring_mod(x: PackedFloat32Array, freq: float, mix: float, sr: int = SR) -> PackedFloat32Array:
	var out := x.duplicate()
	for i in out.size():
		var m := sin(TAU * freq * float(i) / float(sr))
		out[i] = out[i] * (1.0 - mix) + out[i] * m * mix
	return out

static func soft_clip(x: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var norm := tanh(drive)
	var out := x.duplicate()
	for i in out.size():
		out[i] = tanh(out[i] * drive) / norm
	return out

## Feedback delay; output is extended by `tail` seconds so echoes ring out.
static func feedback_delay(x: PackedFloat32Array, time: float, feedback: float, mix: float, tail: float, sr: int = SR) -> PackedFloat32Array:
	var d := maxi(1, int(time * float(sr)))
	var n := x.size() + int(tail * float(sr))
	var line := PackedFloat32Array()
	line.resize(n)
	var res := PackedFloat32Array()
	res.resize(n)
	for i in n:
		var dry := x[i] if i < x.size() else 0.0
		var echo := line[i - d] if i >= d else 0.0
		line[i] = dry + echo * feedback
		res[i] = dry * (1.0 - mix) + echo * mix
	return res
## Four parallel comb filters into two allpasses. Output extended by `tail` seconds.
static func comb_reverb(x: PackedFloat32Array, rt60: float, mix: float, tail: float, sr: int = SR) -> PackedFloat32Array:
	var n := x.size() + int(tail * float(sr))
	var delays: Array[float] = [0.0297, 0.0371, 0.0411, 0.0437]
	var wet := PackedFloat32Array()
	wet.resize(n)
	for dly in delays:
		var d := int(dly * float(sr))
		var g := pow(10.0, -3.0 * dly / maxf(rt60, 0.05))
		var buf := PackedFloat32Array()
		buf.resize(n)
		for i in n:
			var inp := x[i] if i < x.size() else 0.0
			buf[i] = inp + (buf[i - d] * g if i >= d else 0.0)
			wet[i] += buf[i] * 0.25
	for ap in [0.005, 0.0017]:
		var d := int(float(ap) * float(sr))
		var y := PackedFloat32Array()
		y.resize(n)
		for i in n:
			var xin := wet[i]
			y[i] = -0.5 * xin + (wet[i - d] if i >= d else 0.0) + 0.5 * (y[i - d] if i >= d else 0.0)
		wet = y
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (x[i] if i < x.size() else 0.0) * (1.0 - mix) + wet[i] * mix * 0.6
	return out

## Two-voice modulated-delay chorus.
static func chorus(x: PackedFloat32Array, depth_ms: float, rate: float, sr: int = SR) -> PackedFloat32Array:
	var out := x.duplicate()
	var base := 0.012 * float(sr)
	var depth := depth_ms * 0.001 * float(sr)
	for i in out.size():
		var lfo := sin(TAU * rate * float(i) / float(sr))
		var idx := float(i) - base - depth * lfo
		var i0 := int(floorf(idx))
		var frac := idx - float(i0)
		var s0 := x[i0] if i0 >= 0 and i0 < x.size() else 0.0
		var s1 := x[i0 + 1] if i0 + 1 >= 0 and i0 + 1 < x.size() else 0.0
		out[i] = (x[i] + lerpf(s0, s1, frac)) * 0.6
	return out

# -- finishing ----------------------------------------------------------------------

static func peak(x: PackedFloat32Array) -> float:
	var p := 0.0
	for v in x:
		p = maxf(p, absf(v))
	return p

static func normalize(x: PackedFloat32Array, target_db: float = -1.0) -> PackedFloat32Array:
	var p := peak(x)
	if p > 0.00001:
		scale(x, pow(10.0, target_db / 20.0) / p)
	return x

static func fade_edges(x: PackedFloat32Array, in_ms: float = 2.0, out_ms: float = 8.0, sr: int = SR) -> PackedFloat32Array:
	var fi := mini(int(in_ms * 0.001 * float(sr)), x.size())
	var fo := mini(int(out_ms * 0.001 * float(sr)), x.size())
	for i in fi:
		x[i] *= float(i) / float(fi)
	for i in fo:
		x[x.size() - 1 - i] *= float(i) / float(fo)
	return x

## Makes `x` loop seamlessly: crossfades the last `fade` samples (rendered past the loop point) into the head.
## `x` must be loop_len + fade samples long; returns exactly loop_len samples.
static func make_loop(x: PackedFloat32Array, loop_len: int) -> PackedFloat32Array:
	var fade := x.size() - loop_len
	var out := x.slice(0, loop_len)
	for i in fade:
		var w := float(i) / float(fade)
		out[i] = out[i] * w + x[loop_len + i] * (1.0 - w)
	# Also ease the tail into the head so x[0] ≈ x[end] (avoids seam clicks on noisy beds).
	var tail_fade: int = mini(fade, maxi(loop_len / 32, 64))
	for i in tail_fade:
		var w2 := float(i) / float(tail_fade)
		var idx: int = loop_len - 1 - i
		out[idx] = out[idx] * (1.0 - w2) + out[tail_fade - 1 - i] * w2
	out[loop_len - 1] = out[0]
	return out

## Wraps a reverb/delay tail beyond `loop_len` back onto the start (for pattern loops such as music).
static func wrap_tail(x: PackedFloat32Array, loop_len: int) -> PackedFloat32Array:
	for i in range(loop_len, x.size()):
		x[i - loop_len] += x[i]
	x.resize(loop_len)
	return x

# -- authoring helpers ------------------------------------------------------------

const MASTER_SEED: int = 20261105

## Stable (platform independent) per-sound RNG: FNV-1a of the name mixed with the master seed.
static func rng_for(sound_name: String) -> RandomNumberGenerator:
	var h: int = 2166136261
	for b in sound_name.to_utf8_buffer():
		h = ((h ^ int(b)) * 16777619) & 0xFFFFFFFF
	var r := RandomNumberGenerator.new()
	r.seed = h ^ MASTER_SEED
	return r

## Decaying oscillator note.
static func note(kind: int, freq: float, seconds: float, tau: float, sr: int = SR) -> PackedFloat32Array:
	return decay(tone(kind, freq, seconds, sr), tau, sr)

## Mixes `src` into `dst` at `t` seconds.
static func place(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, t: float, sr: int = SR) -> PackedFloat32Array:
	return mix_into(dst, src, gain, int(t * float(sr)))

## Filtered noise burst: noise -> high-pass -> low-pass -> exponential decay.
static func burst(rng: RandomNumberGenerator, seconds: float, hp: float, lp: float, tau: float, sr: int = SR) -> PackedFloat32Array:
	var n := noise(seconds, rng, sr)
	if hp > 0.0:
		n = highpass(n, hp, sr)
	if lp > 0.0:
		n = lowpass(n, lp, sr)
	return decay(n, tau, sr)

## A finished sound. `loop` clips are expected to be seamless already; the driver will not fade them.
static func clip(x: PackedFloat32Array, gain: float = 1.0, loop: bool = false) -> Dictionary:
	return {"l": x, "r": PackedFloat32Array(), "rate": SR, "loop": loop, "gain": gain}