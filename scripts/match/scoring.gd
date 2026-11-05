class_name Scoring
extends RefCounted

func apply_kill(mm: MatchManager, killer_id: int, victim_id: int) -> void:
	mm.scores[killer_id] = int(mm.scores.get(killer_id, 0)) + 1
	var killer := mm.get_fighter(killer_id)
	if killer:
		killer.kills += 1
		killer.current_streak += 1
		killer.best_streak = maxi(killer.best_streak, killer.current_streak)
		killer.score = int(mm.scores[killer_id])
	Events.score_changed.emit(killer_id, int(mm.scores[killer_id]))

func apply_suicide(mm: MatchManager, id: int) -> void:
	mm.scores[id] = int(mm.scores.get(id, 0)) - 1
	var f := mm.get_fighter(id)
	if f:
		f.score = int(mm.scores[id])
	Events.score_changed.emit(id, int(mm.scores[id]))

func build_results(mm: MatchManager) -> Dictionary:
	var rows: Array = []
	for id in mm.fighters:
		var f: Fighter = mm.fighters[id]
		var kd := float(f.kills) / maxf(1.0, float(f.deaths))
		var acc := 0.0
		if f.accuracy_shots > 0:
			acc = 100.0 * float(f.accuracy_hits) / float(f.accuracy_shots)
		rows.append({
			"id": id,
			"name": f.display_name,
			"color": f.color,
			"score": int(mm.scores.get(id, 0)),
			"kills": f.kills,
			"deaths": f.deaths,
			"kd": kd,
			"accuracy": acc,
			"best_streak": f.best_streak,
			"medals": f.medals,
			"damage": f.damage_dealt,
			"top_speed": f.top_speed,
			"is_bot": f.is_bot,
			"last_kill_time": 0,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["deaths"] != b["deaths"]:
			return a["deaths"] < b["deaths"]
		return a["kills"] > b["kills"]
	)
	return {"rows": rows, "local_id": mm.local_player_id, "map": mm.config.map_id}
