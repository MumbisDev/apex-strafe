class_name Medals
extends RefCounted

var _kill_times: Dictionary = {} ## id -> Array[float]
var _life_headshots: Dictionary = {}
var _life_kills: Dictionary = {}
var _first_blood: bool = false

func reset() -> void:
	_kill_times.clear()
	_life_headshots.clear()
	_life_kills.clear()
	_first_blood = false

func on_kill(mm: MatchManager, killer_id: int, victim_id: int, info: DamageInfo) -> void:
	if killer_id == victim_id:
		_life_kills[killer_id] = 0
		_life_headshots[killer_id] = 0
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not _kill_times.has(killer_id):
		_kill_times[killer_id] = []
	var times: Array = _kill_times[killer_id]
	times.append(now)
	_life_kills[killer_id] = int(_life_kills.get(killer_id, 0)) + 1
	if info.is_head:
		_life_headshots[killer_id] = int(_life_headshots.get(killer_id, 0)) + 1

	if not _first_blood:
		_first_blood = true
		_award(mm, killer_id, "First Blood")

	var recent3 := _count_since(times, now, 3.0)
	var recent35 := _count_since(times, now, 3.5)
	var recent4 := _count_since(times, now, 4.0)
	if recent4 >= 4:
		_award(mm, killer_id, "Mega Kill")
	elif recent35 >= 3:
		_award(mm, killer_id, "Triple Kill")
	elif recent3 >= 2:
		_award(mm, killer_id, "Double Kill")

	var life_kills: int = int(_life_kills.get(killer_id, 0))
	if life_kills == 5:
		_award(mm, killer_id, "Rampage")
	elif life_kills == 10:
		_award(mm, killer_id, "Unstoppable")

	if int(_life_headshots.get(killer_id, 0)) >= 3:
		_award(mm, killer_id, "Headhunter")

	var killer := mm.get_fighter(killer_id)
	if killer and not killer.is_on_floor() and killer.movement.coyote <= 0.0:
		# airborne roughly
		_award(mm, killer_id, "Airborne")
		if info.is_splash:
			_award(mm, killer_id, "Rocketeer")

	if killer and killer.movement.grapple_cd > killer.movement.config.grapple_cooldown - 2.0 and not killer.movement.grappling:
		_award(mm, killer_id, "Hooked")

	if info.weapon_id == 7 and info.get("pierce_count") != null and int(info.get("pierce_count")) >= 2:
		_award(mm, killer_id, "Skewer")

	# Comeback
	if _is_comeback(mm, killer_id):
		_award(mm, killer_id, "Comeback")

	var victim := mm.get_fighter(victim_id)
	if victim and (victim.health.overcharge_t > 0.0 or victim.health.haste_t > 0.0):
		_award(mm, killer_id, "Denied")

	# Reset victim life counters
	_life_kills[victim_id] = 0
	_life_headshots[victim_id] = 0

func _count_since(times: Array, now: float, window: float) -> int:
	var c := 0
	for t in times:
		if now - float(t) <= window:
			c += 1
	return c

func _is_comeback(mm: MatchManager, killer_id: int) -> bool:
	var best := -999999
	var leader_id := -1
	var worst := 999999
	for id in mm.scores:
		var s: int = int(mm.scores[id])
		if s > best:
			best = s
			leader_id = int(id)
		if s < worst:
			worst = s
	var my: int = int(mm.scores.get(killer_id, 0))
	return leader_id != killer_id and my <= worst + 1

func _award(mm: MatchManager, id: int, name: String) -> void:
	var f := mm.get_fighter(id)
	if f:
		f.medals += 1
	Events.medal_awarded.emit(id, name)
	Audio.play_sfx("medal_1")
