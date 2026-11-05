class_name BotProfile
extends Resource
## Difficulty tunables for a bot (GDD Section 10). Use the static factories, then
## `varied()` to apply the per-bot +/-10 percent seeded variation.

enum Difficulty { ROOKIE, VETERAN, ELITE, NIGHTMARE }

const VARIATION := 0.1
const MAX_FOV_DEG := 170.0

@export var difficulty: Difficulty = Difficulty.VETERAN
@export var display_name: String = "Veteran"
@export var reaction_time: float = 0.35 ## seconds before engaging a newly seen enemy
@export var aim_error_deg: float = 3.5
@export var aim_tracking_deg_s: float = 220.0
@export var view_fov_deg: float = 120.0
@export var view_range: float = 55.0
@export var memory_time: float = 3.0
@export var lead_accuracy: float = 0.6 ## 0..1 projectile lead
@export var bhop_skill: float = 0.4 ## 0..1
@export var slide_usage: float = 0.4 ## 0..1
@export var grapple_usage: float = 0.3 ## 0..1
@export var wallrun_usage: float = 0.2 ## 0..1
@export var flee_health: float = 30.0
@export var dodge_intensity: float = 0.5 ## 0..1

static func rookie() -> BotProfile:
	return _make(Difficulty.ROOKIE, "Rookie", [0.55, 6.0, 120.0, 110.0, 40.0, 2.0, 0.3, 0.0, 0.1, 0.0, 0.0, 35.0, 0.3])

static func veteran() -> BotProfile:
	return _make(Difficulty.VETERAN, "Veteran", [0.35, 3.5, 220.0, 120.0, 55.0, 3.0, 0.6, 0.4, 0.4, 0.3, 0.2, 30.0, 0.5])

static func elite() -> BotProfile:
	return _make(Difficulty.ELITE, "Elite", [0.22, 1.8, 360.0, 130.0, 70.0, 4.0, 0.85, 0.8, 0.7, 0.7, 0.6, 25.0, 0.8])

static func nightmare() -> BotProfile:
	return _make(Difficulty.NIGHTMARE, "Nightmare", [0.12, 0.8, 600.0, 140.0, 90.0, 5.0, 1.0, 1.0, 1.0, 1.0, 0.9, 20.0, 1.0])

static func from_difficulty(d: Difficulty) -> BotProfile:
	match d:
		Difficulty.ROOKIE: return rookie()
		Difficulty.ELITE: return elite()
		Difficulty.NIGHTMARE: return nightmare()
	return veteran()

## "Mixed" mode: pick the base difficulty or one of its neighbors at random.
static func mixed(rng: RandomNumberGenerator, base: Difficulty = Difficulty.VETERAN) -> BotProfile:
	var idx: int = clampi(int(base) + rng.randi_range(-1, 1), 0, int(Difficulty.NIGHTMARE))
	return from_difficulty(idx as Difficulty)

## Returns a copy with every numeric parameter scaled by a random factor in
## [1 - amount, 1 + amount]. Zero values stay zero. Never mutates `self`.
func varied(rng: RandomNumberGenerator, amount: float = VARIATION) -> BotProfile:
	var p: BotProfile = duplicate() as BotProfile
	p.reaction_time = _vary(reaction_time, rng, amount)
	p.aim_error_deg = _vary(aim_error_deg, rng, amount)
	p.aim_tracking_deg_s = _vary(aim_tracking_deg_s, rng, amount)
	p.view_fov_deg = minf(_vary(view_fov_deg, rng, amount), MAX_FOV_DEG)
	p.view_range = _vary(view_range, rng, amount)
	p.memory_time = _vary(memory_time, rng, amount)
	p.lead_accuracy = clampf(_vary(lead_accuracy, rng, amount), 0.0, 1.0)
	p.bhop_skill = clampf(_vary(bhop_skill, rng, amount), 0.0, 1.0)
	p.slide_usage = clampf(_vary(slide_usage, rng, amount), 0.0, 1.0)
	p.grapple_usage = clampf(_vary(grapple_usage, rng, amount), 0.0, 1.0)
	p.wallrun_usage = clampf(_vary(wallrun_usage, rng, amount), 0.0, 1.0)
	p.flee_health = _vary(flee_health, rng, amount)
	p.dodge_intensity = clampf(_vary(dodge_intensity, rng, amount), 0.0, 1.0)
	return p

## Elite and Nightmare bots hunt the score leader when roaming.
func hunts_leader() -> bool:
	return difficulty == Difficulty.ELITE or difficulty == Difficulty.NIGHTMARE

static func _vary(value: float, rng: RandomNumberGenerator, amount: float) -> float:
	return value * rng.randf_range(1.0 - amount, 1.0 + amount)

## Field order: reaction, aim_error, tracking, fov, range, memory, lead, bhop,
## slide, grapple, wallrun, flee, dodge (matches the GDD table rows).
static func _make(d: Difficulty, label: String, v: Array[float]) -> BotProfile:
	var p := BotProfile.new()
	p.difficulty = d
	p.display_name = label
	p.reaction_time = v[0]
	p.aim_error_deg = v[1]
	p.aim_tracking_deg_s = v[2]
	p.view_fov_deg = v[3]
	p.view_range = v[4]
	p.memory_time = v[5]
	p.lead_accuracy = v[6]
	p.bhop_skill = v[7]
	p.slide_usage = v[8]
	p.grapple_usage = v[9]
	p.wallrun_usage = v[10]
	p.flee_health = v[11]
	p.dodge_intensity = v[12]
	return p
