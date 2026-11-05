class_name BotPerception
extends RefCounted
## Line-of-sight vision, hearing stimuli, and per-enemy memory for one bot.
## No wallhacks: enemies are only learned about through view cone + ray checks,
## sounds, or taking damage. Pure logic; world access goes through `los_blocked`.

enum Stimulus { SHOT, EXPLOSION, GRAPPLE, DAMAGE }

const UPDATE_INTERVAL := 0.1
const MAX_RAYS := 4
const HEAR_SHOT := 35.0
const HEAR_EXPLOSION := 50.0
const HEAR_GRAPPLE := 25.0
const REACQUIRE_GAP := 1.0 ## unseen longer than this = "newly seen" (reaction restarts)
const STIMULUS_TTL := 10.0
const MAX_STIMULI := 8
const TORSO_HEIGHT := 1.1
const HEAD_HEIGHT := 1.62

## Snapshot of one enemy handed to the perception update.
class EnemyView extends RefCounted:
	var id: int = -1
	var pos: Vector3 = Vector3.ZERO ## feet position
	var vel: Vector3 = Vector3.ZERO
	var health: float = 100.0
	var armor: float = 0.0
	var powerup: bool = false
	var grounded: bool = true

## What the bot remembers about one enemy.
class Sighting extends RefCounted:
	var id: int = -1
	var last_pos: Vector3 = Vector3.ZERO
	var last_vel: Vector3 = Vector3.ZERO
	var last_seen: float = -999.0
	var first_seen: float = -999.0
	var visible: bool = false
	var health: float = 100.0
	var armor: float = 0.0
	var powerup: bool = false
	var grounded: bool = true

class Heard extends RefCounted:
	var kind: Stimulus = Stimulus.SHOT
	var pos: Vector3 = Vector3.ZERO
	var time: float = 0.0
	var source_id: int = -1

var profile: BotProfile
var owner_id: int = -1
var sightings: Dictionary = {} ## enemy id -> Sighting
var stimuli: Array[Heard] = []
var rays_used: int = 0 ## raycasts spent by the most recent update
## Callable(from: Vector3, to: Vector3) -> bool; true when the ray is blocked by the world.
var los_blocked: Callable = Callable()

var _timer: float = 0.0
var _now: float = 0.0
var _listener_pos: Vector3 = Vector3.ZERO

func _init(p: BotProfile, id: int = 0) -> void:
	profile = p
	owner_id = id
	_timer = float(id % 5) * UPDATE_INTERVAL / 5.0 ## stagger bots across ticks

## Call every physics tick; returns true when a 0.1 s perception update is due (staggered
## by owner id). The caller then builds enemy views and calls `update()`.
func tick(dt: float, now: float, eye: Vector3) -> bool:
	_timer += dt
	_now = now
	_listener_pos = eye
	if _timer < UPDATE_INTERVAL:
		return false
	_timer -= UPDATE_INTERVAL
	return true

func update(now: float, eye: Vector3, forward: Vector3, enemies: Array[EnemyView]) -> void:
	_now = now
	_listener_pos = eye
	rays_used = 0
	for id in sightings:
		(sightings[id] as Sighting).visible = false
	var candidates: Array[EnemyView] = []
	for e in enemies:
		if e.id != owner_id and _in_view(eye, forward, e):
			candidates.append(e)
	candidates.sort_custom(func(a: EnemyView, b: EnemyView) -> bool:
		return eye.distance_squared_to(a.pos) < eye.distance_squared_to(b.pos))
	for e in candidates:
		if rays_used >= MAX_RAYS:
			break
		if _can_see(eye, e):
			_register_sighting(e, now)
	_prune(now)

func _in_view(eye: Vector3, forward: Vector3, e: EnemyView) -> bool:
	var to_enemy: Vector3 = e.pos + Vector3.UP * TORSO_HEIGHT - eye
	var dist: float = to_enemy.length()
	if dist > profile.view_range:
		return false
	if dist < 0.5:
		return true
	var half_fov: float = deg_to_rad(profile.view_fov_deg * 0.5)
	return forward.angle_to(to_enemy / dist) <= half_fov

## Torso ray first, head ray only when the torso is hidden and budget remains.
func _can_see(eye: Vector3, e: EnemyView) -> bool:
	if not _ray_blocked(eye, e.pos + Vector3.UP * TORSO_HEIGHT):
		return true
	if rays_used >= MAX_RAYS:
		return false
	return not _ray_blocked(eye, e.pos + Vector3.UP * HEAD_HEIGHT)

func _ray_blocked(from: Vector3, to: Vector3) -> bool:
	rays_used += 1
	if not los_blocked.is_valid():
		return false
	return bool(los_blocked.call(from, to))

func _register_sighting(e: EnemyView, now: float) -> void:
	var s: Sighting = sightings.get(e.id) as Sighting
	if s == null:
		s = Sighting.new()
		s.id = e.id
		sightings[e.id] = s
	if now - s.last_seen > REACQUIRE_GAP:
		s.first_seen = now
	s.last_seen = now
	s.last_pos = e.pos
	s.last_vel = e.vel
	s.health = e.health
	s.armor = e.armor
	s.powerup = e.powerup
	s.grounded = e.grounded
	s.visible = true

func _prune(now: float) -> void:
	for id in sightings.keys():
		if now - (sightings[id] as Sighting).last_seen > profile.memory_time:
			sightings.erase(id)
	var i: int = stimuli.size() - 1
	while i >= 0:
		if now - stimuli[i].time > STIMULUS_TTL:
			stimuli.remove_at(i)
		i -= 1

## Sound/damage input. Range checks are made against the last known listener position.
func hear(kind: Stimulus, pos: Vector3, source_id: int = -1) -> bool:
	if source_id == owner_id and source_id >= 0:
		return false
	if kind != Stimulus.DAMAGE and _listener_pos.distance_to(pos) > _hear_range(kind):
		return false
	var h := Heard.new()
	h.kind = kind
	h.pos = pos
	h.time = _now
	h.source_id = source_id
	stimuli.append(h)
	if stimuli.size() > MAX_STIMULI:
		stimuli.remove_at(0)
	return true

static func _hear_range(kind: Stimulus) -> float:
	match kind:
		Stimulus.EXPLOSION: return HEAR_EXPLOSION
		Stimulus.GRAPPLE: return HEAR_GRAPPLE
	return HEAR_SHOT

func latest_stimulus() -> Heard:
	if stimuli.is_empty():
		return null
	return stimuli[stimuli.size() - 1]

func clear_stimuli() -> void:
	stimuli.clear()

func sighting_of(id: int) -> Sighting:
	return sightings.get(id) as Sighting

## Visible now, or remembered within `memory_time`, and the reaction delay has elapsed.
func is_engageable(id: int, now: float) -> bool:
	var s: Sighting = sightings.get(id) as Sighting
	if s == null:
		return false
	if not s.visible and now - s.last_seen > profile.memory_time:
		return false
	return now - s.first_seen >= profile.reaction_time

func engageable_sightings(now: float) -> Array[Sighting]:
	var out: Array[Sighting] = []
	for id in sightings:
		if is_engageable(id as int, now):
			out.append(sightings[id] as Sighting)
	return out

func clear() -> void:
	sightings.clear()
	stimuli.clear()

## Builds an EnemyView from a live Fighter.
static func view_of(f: Fighter) -> EnemyView:
	var v := EnemyView.new()
	v.id = f.id
	v.pos = f.global_position
	v.vel = f.velocity
	v.health = f.health.health
	v.armor = f.health.armor
	v.powerup = f.health.overcharge_t > 0.0 or f.health.haste_t > 0.0
	v.grounded = f.is_on_floor()
	return v

## World ray test used as the default `los_blocked` via `.bind(fighter)` (bound args come
## last). World layer only.
static func world_ray_blocked(from: Vector3, to: Vector3, fighter: Fighter) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [fighter.get_rid()]
	return not fighter.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
