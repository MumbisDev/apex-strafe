class_name BotPlanner
extends RefCounted
## Destination picking for the Roam, Retreat, and Reposition goals. Pure functions of
## positions plus the navigator's waypoint samples (no scene access).

const ROAM_SAMPLES := 8
const RETREAT_SAMPLES := 10
const REPOSITION_SAMPLES := 12
const REPOSITION_RAYS := 3
const REPOSITION_MIN := 6.0
const REPOSITION_MAX := 35.0
const PICKUP_NEAR := 8.0
const LEADER_RANGE := 60.0
const FALLBACK_RADIUS := 15.0
const EYE := 1.2

var nav: BotNavigator
var profile: BotProfile
var rng: RandomNumberGenerator
## Callable(from: Vector3, to: Vector3) -> bool, true when the world blocks the ray.
var los_blocked: Callable = Callable()

func _init(n: BotNavigator, p: BotProfile, r: RandomNumberGenerator) -> void:
	nav = n
	profile = p
	rng = r

## Weighted random waypoint: favors spots near pickups; Elite/Nightmare bias toward the leader.
func roam(pos: Vector3, pickup_positions: PackedVector3Array, leader_pos: Variant = null) -> Vector3:
	var samples: PackedVector3Array = nav.sample_waypoints(ROAM_SAMPLES, rng)
	if samples.is_empty():
		return _fallback(pos)
	var weights: Array[float] = []
	var total: float = 0.0
	for p in samples:
		var w: float = 1.0
		for pk in pickup_positions:
			if p.distance_to(pk) < PICKUP_NEAR:
				w += 2.0
				break
		if profile.hunts_leader() and leader_pos is Vector3:
			w += 3.0 * maxf(0.0, 1.0 - p.distance_to(leader_pos as Vector3) / LEADER_RANGE)
		weights.append(w)
		total += w
	var roll: float = rng.randf() * total
	for i in samples.size():
		roll -= weights[i]
		if roll <= 0.0:
			return samples[i]
	return samples[samples.size() - 1]

## Nearest health pickup if any, else the sampled waypoint farthest from the threat.
func retreat(pos: Vector3, threat_pos: Vector3, health_pickups: PackedVector3Array) -> Vector3:
	var best_pk: Vector3 = Vector3.ZERO
	var best_d: float = INF
	for pk in health_pickups:
		var d: float = pos.distance_to(pk)
		if d < best_d and pk.distance_to(threat_pos) > 6.0:
			best_d = d
			best_pk = pk
	if best_d < INF:
		return best_pk
	var samples: PackedVector3Array = nav.sample_waypoints(RETREAT_SAMPLES, rng)
	if samples.is_empty():
		return pos + (pos - threat_pos).normalized() * FALLBACK_RADIUS
	var best: Vector3 = samples[0]
	var best_score: float = -INF
	for p in samples:
		var score: float = p.distance_to(threat_pos) - 0.4 * p.distance_to(pos)
		if score > best_score:
			best_score = score
			best = p
	return best

## High ground first; among the highest candidates prefer ones the threat cannot see.
func reposition(pos: Vector3, threat_pos: Vector3) -> Vector3:
	var candidates: Array[Vector3] = []
	for p in nav.sample_waypoints(REPOSITION_SAMPLES, rng):
		var d: float = p.distance_to(pos)
		if d >= REPOSITION_MIN and d <= REPOSITION_MAX:
			candidates.append(p)
	if candidates.is_empty():
		return roam(pos, PackedVector3Array())
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	var best: Vector3 = candidates[0]
	var best_score: float = -INF
	for i in mini(REPOSITION_RAYS, candidates.size()):
		var c: Vector3 = candidates[i]
		var score: float = clampf(c.y - pos.y, 0.0, 8.0)
		if los_blocked.is_valid() and bool(los_blocked.call(c + Vector3.UP * EYE, threat_pos + Vector3.UP * EYE)):
			score += 4.0
		if score > best_score:
			best_score = score
			best = c
	return best

func _fallback(pos: Vector3) -> Vector3:
	var a: float = rng.randf() * TAU
	return pos + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(5.0, FALLBACK_RADIUS)
