class_name MatchConfig
extends Resource

enum Difficulty { ROOKIE, VETERAN, ELITE, NIGHTMARE, MIXED }
enum Mutator { LOW_GRAVITY, INSTAGIB, ROCKETS_ONLY }

@export var map_id: String = "foundry"
@export var bot_count: int = 7
@export var difficulty: Difficulty = Difficulty.VETERAN
@export var kill_limit: int = 25
@export var time_limit_sec: int = 480 ## 0 = unlimited
@export var powerups_enabled: bool = true
@export var pickup_respawn_scale: float = 1.0
@export var mutators: Array[int] = []
@export var seed: int = 0
@export var practice: bool = false

func duplicate_config() -> MatchConfig:
	var c := MatchConfig.new()
	c.map_id = map_id
	c.bot_count = bot_count
	c.difficulty = difficulty
	c.kill_limit = kill_limit
	c.time_limit_sec = time_limit_sec
	c.powerups_enabled = powerups_enabled
	c.pickup_respawn_scale = pickup_respawn_scale
	c.mutators = mutators.duplicate()
	c.seed = seed
	c.practice = practice
	return c

func has_mutator(m: Mutator) -> bool:
	return mutators.has(int(m))

static func preset_quick() -> MatchConfig:
	return MatchConfig.new()

static func preset_movement_frenzy() -> MatchConfig:
	var c := MatchConfig.new()
	c.map_id = "sprawl"
	c.difficulty = Difficulty.ELITE
	c.mutators = [int(Mutator.LOW_GRAVITY)]
	return c

static func preset_rocket_arena() -> MatchConfig:
	var c := MatchConfig.new()
	c.map_id = "foundry"
	c.mutators = [int(Mutator.ROCKETS_ONLY)]
	return c

static func preset_instagib() -> MatchConfig:
	var c := MatchConfig.new()
	c.map_id = "spire"
	c.mutators = [int(Mutator.INSTAGIB)]
	c.powerups_enabled = false
	return c

static func preset_sweat() -> MatchConfig:
	var c := MatchConfig.new()
	c.bot_count = 11
	c.difficulty = Difficulty.NIGHTMARE
	c.time_limit_sec = 900
	c.kill_limit = 50
	return c
