class_name BotInput
extends InputSource
## InputSource for bot fighters; wraps a BotBrain. Create with `configure()` (match scene)
## or `setup()` (explicit profile). Call `shutdown()` when the fighter is freed.

var brain: BotBrain = null

## Match-scene entry point: resolves the match difficulty (including Mixed) into a varied profile.
func configure(f: Fighter, mm: MatchManager, difficulty: MatchConfig.Difficulty, index: int) -> void:
	var base: BotProfile
	match difficulty:
		MatchConfig.Difficulty.ROOKIE: base = BotProfile.rookie()
		MatchConfig.Difficulty.ELITE: base = BotProfile.elite()
		MatchConfig.Difficulty.NIGHTMARE: base = BotProfile.nightmare()
		MatchConfig.Difficulty.MIXED: base = BotProfile.mixed(mm.rng)
		_: base = BotProfile.veteran()
	var seed_value: int = mm.rng.randi() + index
	setup(f.id, base.varied(mm.rng), seed_value, BotNavigator.graph_from_map(mm.map_root))

func setup(fighter_id: int, profile: BotProfile, seed_value: int, graph: AStar3D = null, links: Object = null) -> void:
	shutdown()
	brain = BotBrain.new(profile, fighter_id, seed_value, graph, links)

func sample(dt: float, fighter: Fighter) -> InputFrame:
	if brain == null:
		return InputFrame.new()
	var frame: InputFrame = brain.tick(dt, fighter)
	if brain.teleport_pending:
		_teleport(fighter)
	return frame

func shutdown() -> void:
	if brain != null:
		brain.unbind()

## Stuck for 5 s: jump to the nearest waypoint and count it (soak test limit).
func _teleport(fighter: Fighter) -> void:
	brain.teleport_pending = false
	fighter.global_position = brain.teleport_to
	fighter.velocity = Vector3.ZERO
	var mm := fighter.match_manager as MatchManager
	if mm != null:
		mm.teleport_counts[fighter.id] = int(mm.teleport_counts.get(fighter.id, 0)) + 1
	brain.navigator.force_repath()
