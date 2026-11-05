class_name SpawnSystem
extends RefCounted

var spawns: Array = [] ## {pos: Vector3, yaw: float}

func set_spawns(list: Array) -> void:
	spawns = list

func pick_spawn(mm: MatchManager, fighter: Fighter) -> Dictionary:
	if spawns.is_empty():
		return {"pos": Vector3(0, 2, 0), "yaw": 0.0}
	var best_i := 0
	var best_score := -INF
	for i in spawns.size():
		if i == fighter.last_spawn_idx and spawns.size() > 1:
			continue
		var s: Dictionary = spawns[i]
		var pos: Vector3 = s["pos"]
		var min_enemy := INF
		var los_penalty := 0.0
		for e in mm.living_enemies(fighter.id):
			var d := pos.distance_to(e.global_position)
			min_enemy = minf(min_enemy, d)
			if d < 40.0 and _has_los(mm, pos, e.global_position + Vector3.UP):
				los_penalty += 20.0
		var noise := mm.rng.randf_range(0.0, 5.0)
		var score := min_enemy - los_penalty + noise
		if score > best_score:
			best_score = score
			best_i = i
	fighter.last_spawn_idx = best_i
	return spawns[best_i]

func _has_los(mm: MatchManager, from: Vector3, to: Vector3) -> bool:
	if mm.map_root == null:
		return false
	var space := mm.map_root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP, to)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	return hit.is_empty()
