class_name BotBrain
extends RefCounted
## Utility-based bot decision making (GDD Section 10). Every 0.25 s it scores the goals,
## applies 20 percent hysteresis, and plans a destination; every tick it turns the result
## into an InputFrame through BotNavigator / BotMotor / BotAim / BotCombat.

enum Goal { ENGAGE, GRAB_ITEM, RETREAT, INVESTIGATE, ROAM, REPOSITION }

const GOAL_NAMES: Array[String] = ["Engage", "GrabItem", "Retreat", "Investigate", "Roam", "Reposition"]
const THINK_INTERVAL := 0.25
const HYSTERESIS := 1.2
const ROAM_UTILITY := 0.15
const STIMULUS_MAX_AGE := 8.0
const THREAT_RANGE := 40.0
const TARGET_KEEP_BONUS := 1.3
const DAMAGE_DECAY_PER_S := 0.25
const FEET_TO_TORSO := 1.1

## Snapshot the utility functions score. Plain data so tests can build one directly.
class Situation extends RefCounted:
	var health: float = 100.0
	var flee_health: float = 30.0
	var has_target: bool = false
	var target_health: float = 100.0
	var has_weapon: bool = true
	var own_powerup: bool = false
	var threat_near: bool = false
	var has_stimulus: bool = false
	var item_utility: float = 0.0
	var damage_taken: float = 0.0
	var damage_dealt: float = 0.0

var profile: BotProfile
var perception: BotPerception
var navigator: BotNavigator
var aim: BotAim
var combat: BotCombat
var motor: BotMotor
var planner: BotPlanner
var stuck: BotStuck = BotStuck.new()
var goal: Goal = Goal.ROAM
var target_id: int = -1
var teleport_pending: bool = false
var teleport_to: Vector3 = Vector3.ZERO

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _frame: InputFrame = InputFrame.new()
var _mm: MatchManager = null
var _id: int = -1
var _bound: bool = false
var _clock: float = 0.0
var _think_t: float = 0.0
var _goal_done: bool = true
var _damage_taken: float = 0.0
var _damage_dealt: float = 0.0
var _threat: Dictionary = {} ## attacker id -> clock time of last hit on us
var _item_pos: Vector3 = Vector3.ZERO
var _available: Array[int] = [BotWeapons.BLADE, BotWeapons.PISTOL]
var _select_slot: int = 0

func _init(p: BotProfile, fighter_id: int, seed_value: int, graph: AStar3D = null, links: Object = null) -> void:
	profile = p
	_id = fighter_id
	_rng.seed = seed_value
	perception = BotPerception.new(p, fighter_id)
	navigator = BotNavigator.new(graph, p, seed_value + 1, links)
	aim = BotAim.new(p, seed_value + 2)
	combat = BotCombat.new(p, seed_value + 3)
	motor = BotMotor.new(p, aim, seed_value + 4)
	planner = BotPlanner.new(navigator, p, _rng)

# ---------------------------------------------------------------- utilities (pure)

static func utilities(s: Situation) -> Array[float]:
	var u: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var healthy: bool = s.health > s.flee_health
	if s.has_target and s.has_weapon and healthy:
		u[Goal.ENGAGE] = 0.7 + 0.15 * (1.0 - clampf(s.target_health / 100.0, 0.0, 1.0)) + (0.1 if s.own_powerup else 0.0)
		if s.damage_taken >= 20.0 and s.damage_taken > s.damage_dealt * 1.5:
			u[Goal.REPOSITION] = 1.0 + 0.3 * clampf((s.damage_taken - s.damage_dealt) / 60.0, 0.0, 1.0)
	u[Goal.GRAB_ITEM] = s.item_utility
	if not healthy and s.threat_near:
		u[Goal.RETREAT] = 0.95 + (s.flee_health - s.health) / 100.0
	if s.has_stimulus and not s.has_target:
		u[Goal.INVESTIGATE] = 0.45
	u[Goal.ROAM] = ROAM_UTILITY
	return u

## Picks the goal with hysteresis: switch only when the best beats the current by 20 percent,
## or the current goal is done or no longer valid (utility 0).
func choose(s: Situation) -> Goal:
	var u: Array[float] = utilities(s)
	var best: int = 0
	for i in u.size():
		if u[i] > u[best]:
			best = i
	if _goal_done or u[goal] <= 0.0 or u[best] > u[goal] * HYSTERESIS:
		goal = best as Goal
	return goal

func mark_goal_done() -> void:
	_goal_done = true

# ---------------------------------------------------------------- events

func bind(f: Fighter) -> void:
	if _bound:
		return
	_bound = true
	_id = f.id
	perception.owner_id = f.id
	_mm = f.match_manager as MatchManager
	if navigator.graph == null and _mm != null:
		navigator.graph = BotNavigator.graph_from_map(_mm.map_root)
	perception.los_blocked = BotPerception.world_ray_blocked.bind(f)
	planner.los_blocked = perception.los_blocked
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.explosion.connect(_on_explosion)
	Events.grapple_attached.connect(_on_grapple)
	Events.fighter_damaged.connect(_on_damaged)
	Events.fighter_respawned.connect(_on_respawned)

func unbind() -> void:
	if not _bound:
		return
	_bound = false
	Events.weapon_fired.disconnect(_on_weapon_fired)
	Events.explosion.disconnect(_on_explosion)
	Events.grapple_attached.disconnect(_on_grapple)
	Events.fighter_damaged.disconnect(_on_damaged)
	Events.fighter_respawned.disconnect(_on_respawned)

func _on_weapon_fired(id: int, _weapon: int, origin: Vector3, _dir: Vector3) -> void:
	perception.hear(BotPerception.Stimulus.SHOT, origin, id)

func _on_explosion(pos: Vector3, _radius: float, owner_id: int) -> void:
	perception.hear(BotPerception.Stimulus.EXPLOSION, pos, owner_id)

func _on_grapple(id: int, anchor: Vector3) -> void:
	perception.hear(BotPerception.Stimulus.GRAPPLE, anchor, id)

func _on_damaged(victim: int, attacker: int, amount: float, _pos: Vector3, _head: bool) -> void:
	if victim == _id and attacker != _id:
		_damage_taken += amount
		_threat[attacker] = _clock
		var a: Fighter = _mm.get_fighter(attacker) if _mm != null else null
		if a != null:
			perception.hear(BotPerception.Stimulus.DAMAGE, a.global_position, attacker)
	elif attacker == _id and victim != _id:
		_damage_dealt += amount

func _on_respawned(id: int) -> void:
	if id != _id:
		return
	perception.clear()
	navigator.clear_destination()
	stuck.reset(Vector3.ZERO)
	target_id = -1
	_damage_taken = 0.0
	_damage_dealt = 0.0
	_threat.clear()
	_goal_done = true

# ---------------------------------------------------------------- per tick

func tick(dt: float, f: Fighter) -> InputFrame:
	bind(f)
	_clock += dt
	_frame.clear()
	var eye: Vector3 = f.aim_origin()
	if perception.tick(dt, _clock, eye) and _mm != null:
		perception.update(_clock, eye, f.aim_dir(), _enemy_views())
	var decay: float = maxf(0.0, 1.0 - DAMAGE_DECAY_PER_S * dt)
	_damage_taken *= decay
	_damage_dealt *= decay
	_think_t -= dt
	if _think_t <= 0.0:
		_think_t = THINK_INTERVAL
		_think(f)
	_act(dt, f)
	return _frame

func _enemy_views() -> Array[BotPerception.EnemyView]:
	var out: Array[BotPerception.EnemyView] = []
	for e in _mm.living_enemies(_id):
		out.append(BotPerception.view_of(e))
	return out

func _think(f: Fighter) -> void:
	_select_target(f)
	_available = BotWeapons.available_slots(f)
	var s: Situation = _build_situation(f)
	var prev: Goal = goal
	if navigator.has_destination and (navigator.arrived or not navigator.last_request_ok):
		_goal_done = true
		if goal == Goal.INVESTIGATE:
			perception.clear_stimuli()
	choose(s)
	if goal != prev or _goal_done:
		_goal_done = false
		_plan(f)
	elif goal == Goal.ENGAGE:
		_plan_engage()
	_select_slot = 0
	if target_id < 0:
		var best: int = BotWeapons.choose(18.0, false, _available)
		if best != BotWeapons.current_slot(f):
			_select_slot = best

func _select_target(f: Fighter) -> void:
	var best_id: int = -1
	var best_score: float = 0.0
	var pos: Vector3 = f.global_position
	for sg in perception.engageable_sightings(_clock):
		var e: Fighter = _mm.get_fighter(sg.id) if _mm != null else null
		if e == null or not e.health.alive:
			perception.sightings.erase(sg.id)
			continue
		var threat: float = 0.6 if _clock - float(_threat.get(sg.id, -99.0)) < 5.0 else 0.0
		var score: float = 1.0 / (pos.distance_to(sg.last_pos) + 5.0)
		score *= 1.0 + (1.0 - sg.health / 100.0) * 0.8 + (1.0 - sg.armor / 100.0) * 0.3 + threat
		score *= 1.0 if sg.visible else 0.5
		if sg.id == target_id:
			score *= TARGET_KEEP_BONUS
		if score > best_score:
			best_score = score
			best_id = sg.id
	target_id = best_id

func _build_situation(f: Fighter) -> Situation:
	var s := Situation.new()
	s.health = f.health.health
	s.flee_health = profile.flee_health
	s.own_powerup = f.health.overcharge_t > 0.0 or f.health.haste_t > 0.0
	s.damage_taken = _damage_taken
	s.damage_dealt = _damage_dealt
	var sg: BotPerception.Sighting = perception.sighting_of(target_id)
	if sg != null:
		s.has_target = true
		s.target_health = sg.health
	for other in perception.engageable_sightings(_clock):
		if f.global_position.distance_to(other.last_pos) < THREAT_RANGE:
			s.threat_near = true
	s.threat_near = s.threat_near or _damage_taken > 5.0
	var heard: BotPerception.Heard = perception.latest_stimulus()
	s.has_stimulus = heard != null and _clock - heard.time <= STIMULUS_MAX_AGE
	s.item_utility = _scan_items(f)
	return s

func _scan_items(f: Fighter) -> float:
	var best: float = 0.0
	var pos: Vector3 = f.global_position
	for n in f.get_tree().get_nodes_in_group("pickups"):
		var it: BotItems.Item = BotItems.read(n)
		var owned: bool = it.slot > 0 and BotWeapons.owns(f, it.slot)
		var u: float = BotItems.utility(it.type, f.health.health, f.health.armor, owned, pos.distance_to(it.pos), it.respawn_in)
		if u > best:
			best = u
			_item_pos = it.pos
	return best

func _plan(f: Fighter) -> void:
	var pos: Vector3 = f.global_position
	match goal:
		Goal.ENGAGE:
			_plan_engage()
		Goal.GRAB_ITEM:
			navigator.set_destination(_item_pos)
		Goal.RETREAT:
			navigator.set_destination(planner.retreat(pos, _threat_pos(pos), _health_pickups(f)))
		Goal.INVESTIGATE:
			var heard: BotPerception.Heard = perception.latest_stimulus()
			if heard != null:
				navigator.set_destination(heard.pos)
		Goal.ROAM:
			navigator.set_destination(planner.roam(pos, _pickup_positions(f), _leader_pos()))
		Goal.REPOSITION:
			navigator.set_destination(planner.reposition(pos, _threat_pos(pos)))

## Engage: combat movement while the target is visible, otherwise chase its last known spot.
func _plan_engage() -> void:
	var sg: BotPerception.Sighting = perception.sighting_of(target_id)
	if sg == null or sg.visible:
		navigator.clear_destination()
	else:
		navigator.set_destination(sg.last_pos)

func _threat_pos(fallback: Vector3) -> Vector3:
	var sg: BotPerception.Sighting = perception.sighting_of(target_id)
	if sg != null:
		return sg.last_pos
	var heard: BotPerception.Heard = perception.latest_stimulus()
	return heard.pos if heard != null else fallback + Vector3.FORWARD

func _pickup_positions(f: Fighter) -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in f.get_tree().get_nodes_in_group("pickups"):
		out.append(BotItems.read(n).pos)
	return out

func _health_pickups(f: Fighter) -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in f.get_tree().get_nodes_in_group("pickups"):
		var it: BotItems.Item = BotItems.read(n)
		if it.available and BotItems.is_health(it.type):
			out.append(it.pos)
	return out

## Position of the current score leader (other than us), or null.
func _leader_pos() -> Variant:
	if _mm == null:
		return null
	var best_id: int = -1
	var best_score: int = -999999
	for id in _mm.scores:
		var sc: int = int(_mm.scores[id])
		if id != _id and sc > best_score:
			best_score = sc
			best_id = id as int
	var leader: Fighter = _mm.get_fighter(best_id)
	if leader == null or not leader.health.alive:
		return null
	return leader.global_position

func _act(dt: float, f: Fighter) -> void:
	var pos: Vector3 = f.global_position
	var sg: BotPerception.Sighting = perception.sighting_of(target_id)
	var shooting: bool = sg != null and sg.visible
	navigator.update(dt, _clock, pos, f.velocity)
	var wants_move: bool = shooting or (navigator.has_destination and not navigator.arrived)
	stuck.update(dt, pos, wants_move, _rng)
	if stuck.want_repath:
		navigator.force_repath()
	if stuck.want_teleport:
		teleport_pending = true
		teleport_to = navigator.nearest_waypoint(pos)
	motor.drive(dt, _clock, f, navigator, stuck, _frame, not shooting)
	if _select_slot > 0:
		_frame.weapon_select = _select_slot
		_select_slot = 0
	if shooting:
		_fight(dt, f, sg)

func _fight(dt: float, f: Fighter, sg: BotPerception.Sighting) -> void:
	var mv: MovementController = f.movement
	var eye: Vector3 = f.aim_origin()
	var current: int = BotWeapons.current_slot(f)
	var point: Vector3 = aim.aim_point(eye, sg.last_pos, sg.last_vel, current, sg.grounded)
	_frame.look_delta = aim.step(dt, mv.yaw, mv.pitch, point - eye, true)
	var dist: float = eye.distance_to(sg.last_pos + Vector3.UP * FEET_TO_TORSO)
	var winning: bool = f.health.health >= sg.health
	combat.step(dt, dist, current, _available, winning, true, rad_to_deg(aim.angle_error),
		mv.horizontal_speed(f), f.is_on_floor())
	if combat.weapon_select > 0:
		_frame.weapon_select = combat.weapon_select
	_frame.fire_held = combat.fire
	_frame.fire_pressed = combat.fire
	if goal == Goal.ENGAGE:
		_frame.move = combat.move
	if combat.jump:
		_frame.jump_pressed = true
	if combat.slide:
		motor.begin_slide(_frame)

## F3 debug overlay data.
func debug_summary(f: Fighter) -> Dictionary:
	return {
		"goal": GOAL_NAMES[goal],
		"target": target_id,
		"path_len": navigator.path_length_left(f.global_position),
		"speed": f.movement.horizontal_speed(f),
	}
