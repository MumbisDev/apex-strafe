extends Node
## GD-Sync relay for online matches. Host owns combat; everyone sends pose/input.

var mm: MatchManager
var _gds: Node = null
var _send_accum: float = 0.0
const SEND_HZ := 30.0

func setup(match_manager: MatchManager) -> void:
	mm = match_manager
	name = "NetBridge"
	_gds = get_node_or_null("/root/GDSync")
	if _gds == null:
		return
	_gds.call("expose_func", Callable(self, "recv_pose"))
	_gds.call("expose_func", Callable(self, "req_damage"))
	_gds.call("expose_func", Callable(self, "rpc_apply_damage"))
	_gds.call("expose_func", Callable(self, "rpc_apply_kill"))
	_gds.call("expose_func", Callable(self, "rpc_respawn"))
	_gds.call("expose_func", Callable(self, "rpc_end_match"))
	_gds.call("expose_func", Callable(self, "rpc_set_scores"))
	if not NetSession.roster_changed.is_connected(_on_roster):
		NetSession.roster_changed.connect(_on_roster)

func _exit_tree() -> void:
	if NetSession.roster_changed.is_connected(_on_roster):
		NetSession.roster_changed.disconnect(_on_roster)

func _physics_process(dt: float) -> void:
	if mm == null or Game.match_config == null or not Game.match_config.online:
		return
	if _gds == null:
		return
	_send_accum += dt
	if _send_accum < 1.0 / SEND_HZ:
		return
	_send_accum = 0.0
	_send_local_pose()
	_snap_remotes()

func _send_local_pose() -> void:
	var local_id := mm.local_player_id
	var f: Fighter = mm.get_fighter(local_id)
	if f == null or f.input_source == null:
		return
	# Sample already consumed this tick; rebuild a light snapshot from PlayerInput if present.
	var frame := InputFrame.new()
	if f.input_source is PlayerInput:
		# Re-read held state coarsely for remotes (look delta zeroed — pose carries aim).
		frame.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		frame.jump_held = Input.is_action_pressed("jump")
		frame.crouch_held = Input.is_action_pressed("crouch")
		frame.fire_held = Input.is_action_pressed("fire")
		frame.alt_held = Input.is_action_pressed("alt_fire")
		frame.grapple_held = Input.is_action_pressed("grapple")
	var payload: Array = [
		local_id,
		frame.to_array(),
		f.global_position.x, f.global_position.y, f.global_position.z,
		f.movement.yaw, f.movement.pitch,
		f.velocity.x, f.velocity.y, f.velocity.z,
	]
	_gds.call("call_func_all_unreliable", Callable(self, "recv_pose"), payload)

func recv_pose(payload: Array) -> void:
	if payload.size() < 10 or mm == null:
		return
	var client_id := int(payload[0])
	if client_id == NetSession.local_client_id():
		return
	var f: Fighter = mm.get_fighter(client_id)
	if f == null:
		return
	var frame := InputFrame.from_array(payload[1] as Array)
	var pos := Vector3(float(payload[2]), float(payload[3]), float(payload[4]))
	var yaw := float(payload[5])
	var pitch := float(payload[6])
	var vel := Vector3(float(payload[7]), float(payload[8]), float(payload[9]))
	if f.input_source is RemoteInput:
		var ri := f.input_source as RemoteInput
		ri.apply_network_frame(frame)
		ri.apply_pose(pos, yaw, pitch, vel)

func _snap_remotes() -> void:
	for id in mm.fighters:
		var f: Fighter = mm.fighters[id]
		if f.is_bot or id == mm.local_player_id:
			continue
		if f.input_source is RemoteInput:
			(f.input_source as RemoteInput).snap_fighter(f)

## Clients (and host local weapons) route damage through here when online.
func route_damage(victim_id: int, info: DamageInfo) -> void:
	if not Game.match_config.online:
		mm.auth_apply_damage(victim_id, info)
		return
	var packed := _pack_damage(victim_id, info)
	if NetSession.is_host():
		_host_apply_damage(packed)
	else:
		var host_id := NetSession.host_client_id()
		_gds.call("call_func_on", host_id, Callable(self, "req_damage"), packed)

func req_damage(packed: Array) -> void:
	if not NetSession.is_host():
		return
	_host_apply_damage(packed)

func _host_apply_damage(packed: Array) -> void:
	var victim_id := int(packed[0])
	var info := _unpack_damage(packed)
	mm.auth_apply_damage(victim_id, info)
	# Broadcast resulting health/armor for visual sync
	var victim: Fighter = mm.get_fighter(victim_id)
	if victim == null:
		return
	var state: Array = [
		victim_id,
		victim.health.health,
		victim.health.armor,
		info.attacker_id,
		info.amount,
		info.hit_pos.x, info.hit_pos.y, info.hit_pos.z,
		info.is_head,
		info.weapon_id,
	]
	_gds.call("call_func_all", Callable(self, "rpc_apply_damage"), state)
	if not victim.health.alive:
		_broadcast_kill(victim_id, info)

func rpc_apply_damage(state: Array) -> void:
	if state.size() < 10 or mm == null:
		return
	if NetSession.is_host():
		return ## host already applied via auth
	var victim_id := int(state[0])
	var victim: Fighter = mm.get_fighter(victim_id)
	if victim == null:
		return
	victim.health.health = float(state[1])
	victim.health.armor = float(state[2])
	var attacker_id := int(state[3])
	var dealt := float(state[4])
	var hit_pos := Vector3(float(state[5]), float(state[6]), float(state[7]))
	var is_head := bool(state[8])
	Events.fighter_damaged.emit(victim_id, attacker_id, dealt, hit_pos, is_head)
	if dealt > 0.0:
		Events.hit_confirmed.emit(attacker_id, false, is_head)

func _broadcast_kill(victim_id: int, info: DamageInfo) -> void:
	var killer := info.attacker_id
	if info.is_self:
		killer = victim_id
	var scores_snap: Dictionary = {}
	for id in mm.scores:
		scores_snap[id] = int(mm.scores[id])
	var payload: Array = [victim_id, killer, info.weapon_id, info.is_head, scores_snap]
	_gds.call("call_func_all", Callable(self, "rpc_apply_kill"), payload)

func rpc_apply_kill(payload: Array) -> void:
	if payload.size() < 5 or mm == null:
		return
	if NetSession.is_host():
		return
	var victim_id := int(payload[0])
	var killer_id := int(payload[1])
	var weapon_id := int(payload[2])
	var is_head := bool(payload[3])
	var scores_snap: Dictionary = payload[4] as Dictionary
	for id in scores_snap:
		mm.scores[int(id)] = int(scores_snap[id])
	var victim: Fighter = mm.get_fighter(victim_id)
	if victim:
		victim.health.alive = false
		victim.health.health = 0.0
		victim.deaths += 1
		victim.visible = false
	var killer: Fighter = mm.get_fighter(killer_id)
	if killer and killer_id != victim_id:
		killer.kills += 1
	Events.fighter_killed.emit(victim_id, killer_id, weapon_id, is_head)
	Events.score_changed.emit(killer_id, int(mm.scores.get(killer_id, 0)))

func rpc_respawn(payload: Array) -> void:
	if payload.size() < 5 or mm == null:
		return
	var id := int(payload[0])
	var pos := Vector3(float(payload[1]), float(payload[2]), float(payload[3]))
	var yaw := float(payload[4])
	var f: Fighter = mm.get_fighter(id)
	if f == null:
		return
	f.global_position = pos
	f.movement.yaw = yaw
	f.velocity = Vector3.ZERO
	f.health.reset()
	f.health.begin_spawn_protect(2.0)
	f.visible = true
	Events.fighter_respawned.emit(id)

func broadcast_respawn(id: int, pos: Vector3, yaw: float) -> void:
	if not NetSession.is_host() or _gds == null:
		return
	_gds.call("call_func_all", Callable(self, "rpc_respawn"), [id, pos.x, pos.y, pos.z, yaw])

func broadcast_end(results: Dictionary) -> void:
	if not NetSession.is_host() or _gds == null:
		return
	_gds.call("call_func_all", Callable(self, "rpc_end_match"), results)

func rpc_end_match(results: Dictionary) -> void:
	# Host already transitions in MatchManager; call_func_all may still invoke here.
	if NetSession.is_host():
		return
	Engine.time_scale = 1.0
	Events.match_ended.emit(results)
	Game.go_results(results)

func _on_roster() -> void:
	if not NetSession.is_host() or mm == null:
		return
	# Drop fighters for peers who left
	var alive_peers: Dictionary = {}
	for id in NetSession.peer_ids:
		alive_peers[id] = true
	var to_remove: Array[int] = []
	for id in mm.fighters:
		var f: Fighter = mm.fighters[id]
		if f.is_bot:
			continue
		if not alive_peers.has(id):
			to_remove.append(id)
	for id2 in to_remove:
		var gone: Fighter = mm.fighters[id2]
		if gone and gone.health.alive:
			mm.auth_void_death(id2)

func _pack_damage(victim_id: int, info: DamageInfo) -> Array:
	return [
		victim_id,
		info.amount,
		info.attacker_id,
		info.weapon_id,
		info.hit_pos.x, info.hit_pos.y, info.hit_pos.z,
		info.impulse.x, info.impulse.y, info.impulse.z,
		info.is_head,
		info.is_self,
		info.is_splash,
	]

func _unpack_damage(packed: Array) -> DamageInfo:
	var info := DamageInfo.new()
	if packed.size() < 13:
		return info
	info.victim_id = int(packed[0])
	info.amount = float(packed[1])
	info.attacker_id = int(packed[2])
	info.weapon_id = int(packed[3])
	info.hit_pos = Vector3(float(packed[4]), float(packed[5]), float(packed[6]))
	info.impulse = Vector3(float(packed[7]), float(packed[8]), float(packed[9]))
	info.is_head = bool(packed[10])
	info.is_self = bool(packed[11])
	info.is_splash = bool(packed[12])
	return info
