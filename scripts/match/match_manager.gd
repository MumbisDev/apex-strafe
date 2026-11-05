class_name MatchManager
extends Node

enum Phase { LOADING, INTRO, COUNTDOWN, LIVE, OVERTIME, ENDING, RESULTS }

var config: MatchConfig
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var phase: Phase = Phase.LOADING
var fighters: Dictionary = {} ## id -> Fighter
var scores: Dictionary = {}
var time_left: float = 0.0
var countdown: float = 0.0
var intro_t: float = 0.0
var ending_t: float = 0.0
var event_log: PackedStringArray = PackedStringArray()
var pickups: Array = []
var spawn_system: SpawnSystem
var medals: Medals
var scoring: Scoring
var map_root: Node3D
var local_player_id: int = 0
var _next_id: int = 1
var teleport_counts: Dictionary = {}

func _ready() -> void:
	add_to_group("match_manager")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	spawn_system = SpawnSystem.new()
	medals = Medals.new()
	scoring = Scoring.new()

func setup(cfg: MatchConfig, map: Node3D) -> void:
	config = cfg
	map_root = map
	rng.seed = cfg.seed if cfg.seed != 0 else 1
	time_left = float(cfg.time_limit_sec)
	phase = Phase.INTRO
	intro_t = 2.5
	event_log.clear()

func auth_register_fighter(f: Fighter) -> void:
	fighters[f.id] = f
	scores[f.id] = 0
	f.match_manager = self
	Events.fighter_spawned.emit(f.id)

func alloc_id() -> int:
	var id := _next_id
	_next_id += 1
	return id

func auth_apply_damage(victim_id: int, info: DamageInfo) -> void:
	if phase != Phase.LIVE and phase != Phase.OVERTIME:
		return
	var victim: Fighter = fighters.get(victim_id) as Fighter
	if victim == null or not victim.health.alive:
		return
	# Attacker powerup
	var attacker: Fighter = fighters.get(info.attacker_id) as Fighter
	if attacker and attacker.health.overcharge_t > 0.0 and not info.is_self:
		info.amount *= 2.0
	var dealt := victim.health.apply_damage(info)
	if dealt > 0.0:
		_log("dmg %d->%d %.1f" % [info.attacker_id, victim_id, dealt])
		Events.fighter_damaged.emit(victim_id, info.attacker_id, dealt, info.hit_pos, info.is_head)
		if attacker and not info.is_self:
			attacker.damage_dealt += dealt
			Events.hit_confirmed.emit(info.attacker_id, false, info.is_head)
		if info.impulse.length_squared() > 0.0:
			victim.apply_impulse(info.impulse)
	if not victim.health.alive:
		auth_kill(victim_id, info)

func auth_kill(victim_id: int, info: DamageInfo) -> void:
	var victim: Fighter = fighters.get(victim_id) as Fighter
	if victim == null:
		return
	var killer_id := info.attacker_id
	if info.is_self or killer_id == victim_id:
		scoring.apply_suicide(self, victim_id)
		killer_id = victim_id
	else:
		scoring.apply_kill(self, killer_id, victim_id)
		medals.on_kill(self, killer_id, victim_id, info)
	victim.deaths += 1
	victim.current_streak = 0
	Events.fighter_killed.emit(victim_id, killer_id, info.weapon_id, info.is_head)
	if killer_id != victim_id:
		Events.hit_confirmed.emit(killer_id, true, info.is_head)
	_log("kill %d by %d w%d" % [victim_id, killer_id, info.weapon_id])
	# Death drop backpack via pickup spawner if present
	var parent := get_parent()
	if parent and parent.has_method("on_fighter_killed"):
		parent.call("on_fighter_killed", victim)
	# Schedule respawn
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		auth_request_respawn(victim_id)
	)
	_check_end_conditions(killer_id)

func auth_request_respawn(id: int) -> void:
	var f: Fighter = fighters.get(id) as Fighter
	if f == null or f.health.alive:
		return
	var spawn := spawn_system.pick_spawn(self, f)
	f.global_position = spawn["pos"]
	f.movement.yaw = spawn["yaw"]
	f.velocity = Vector3.ZERO
	f.health.reset()
	f.health.begin_spawn_protect(2.0)
	f.visible = true
	Events.fighter_respawned.emit(id)
	_log("respawn %d" % id)

func auth_collect_pickup(fighter_id: int, pickup_id: int) -> bool:
	var parent := get_parent()
	if parent and parent.has_method("auth_collect_pickup"):
		return bool(parent.call("auth_collect_pickup", fighter_id, pickup_id))
	return false

func auth_void_death(victim_id: int) -> void:
	var victim: Fighter = fighters.get(victim_id) as Fighter
	if victim == null or not victim.health.alive:
		return
	var info := DamageInfo.new()
	info.amount = 9999.0
	info.victim_id = victim_id
	info.attacker_id = victim_id
	info.is_self = true
	info.weapon_id = 0
	# Attribute to last attacker within 4s
	var now := Time.get_ticks_msec() / 1000.0
	if victim.health.last_attacker_id >= 0 and now - victim.health.last_attacker_time <= 4.0:
		info.attacker_id = victim.health.last_attacker_id
		info.is_self = false
	victim.health.alive = false
	victim.health.health = 0.0
	auth_kill(victim_id, info)

func _physics_process(dt: float) -> void:
	match phase:
		Phase.INTRO:
			intro_t -= dt
			if intro_t <= 0.0:
				phase = Phase.COUNTDOWN
				countdown = 3.0
				Events.match_countdown.emit(3)
		Phase.COUNTDOWN:
			var prev := int(ceil(countdown))
			countdown -= dt
			var cur := int(ceil(countdown))
			if cur != prev and cur > 0:
				Events.match_countdown.emit(cur)
				Audio.play_ui("countdown_tick")
			if countdown <= 0.0:
				phase = Phase.LIVE
				_unfreeze_all()
				Events.match_started.emit()
				Audio.play_ui("countdown_go")
				Audio.play_music("music_match_a")
		Phase.LIVE, Phase.OVERTIME:
			if config.time_limit_sec > 0 and phase == Phase.LIVE:
				time_left -= dt
				if time_left <= 0.0:
					if _is_tied_for_first():
						phase = Phase.OVERTIME
						Events.message.emit("OVERTIME")
					else:
						_begin_ending()
		Phase.ENDING:
			ending_t -= dt
			if ending_t <= 0.0:
				Engine.time_scale = 1.0
				phase = Phase.RESULTS
				var results := scoring.build_results(self)
				Events.match_ended.emit(results)
				Game.go_results(results)

func _unfreeze_all() -> void:
	for id in fighters:
		var f: Fighter = fighters[id]
		f.frozen = false

func freeze_all() -> void:
	for id in fighters:
		var f: Fighter = fighters[id]
		f.frozen = true

func _check_end_conditions(killer_id: int) -> void:
	if phase != Phase.LIVE and phase != Phase.OVERTIME:
		return
	if phase == Phase.OVERTIME:
		_begin_ending()
		return
	var sc: int = int(scores.get(killer_id, 0))
	if sc >= config.kill_limit:
		_begin_ending()

func _begin_ending() -> void:
	phase = Phase.ENDING
	ending_t = 1.5
	Engine.time_scale = 0.3
	freeze_all()

func _is_tied_for_first() -> bool:
	var best := -999999
	var count := 0
	for id in scores:
		var s: int = int(scores[id])
		if s > best:
			best = s
			count = 1
		elif s == best:
			count += 1
	return count > 1

func event_log_hash() -> int:
	return hash("|".join(event_log))

func _log(s: String) -> void:
	event_log.append(s)

func get_fighter(id: int) -> Fighter:
	return fighters.get(id) as Fighter

func living_enemies(of_id: int) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for id in fighters:
		if id == of_id:
			continue
		var f: Fighter = fighters[id]
		if f.health.alive:
			out.append(f)
	return out
