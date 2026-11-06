extends Node
## Thin wrapper around the GDSync autoload for private lobby codes (no port forwarding).

signal status_changed(text: String)
signal roster_changed()
signal connected_ok()
signal connection_error(message: String)
signal lobby_ready(code: String)
signal lobby_failed(message: String)
signal match_start_requested(cfg: Dictionary)

const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const LOBBY_LIMIT := 12

var is_online: bool = false
var lobby_code: String = ""
var peer_ids: Array[int] = []
var _connecting: bool = false
var _pending_host: bool = false
var _pending_join_code: String = ""
var _gds: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_gdsync()

func _bind_gdsync() -> void:
	_gds = get_node_or_null("/root/GDSync")
	if _gds == null:
		return
	if not _gds.connected.is_connected(_on_connected):
		_gds.connected.connect(_on_connected)
		_gds.connection_failed.connect(_on_connection_failed)
		_gds.disconnected.connect(_on_disconnected)
		_gds.lobby_created.connect(_on_lobby_created)
		_gds.lobby_creation_failed.connect(_on_lobby_creation_failed)
		_gds.lobby_joined.connect(_on_lobby_joined)
		_gds.lobby_join_failed.connect(_on_lobby_join_failed)
		_gds.client_joined.connect(_on_client_joined)
		_gds.client_left.connect(_on_client_left)

func has_backend() -> bool:
	return _gds != null

func is_host() -> bool:
	return _gds != null and bool(_gds.call("is_host"))

func local_client_id() -> int:
	if _gds == null:
		return -1
	return int(_gds.call("get_client_id"))

func host_client_id() -> int:
	if _gds == null:
		return -1
	return int(_gds.call("get_host"))

func connect_cloud() -> void:
	_bind_gdsync()
	if _gds == null:
		connection_error.emit("GDSync plugin not loaded")
		status_changed.emit("GDSync missing")
		return
	if is_online:
		connected_ok.emit()
		return
	if _connecting:
		return
	_connecting = true
	status_changed.emit("Connecting…")
	_gds.call("start_multiplayer")

func host_lobby() -> void:
	_pending_host = true
	_pending_join_code = ""
	if not is_online:
		connect_cloud()
		return
	_create_lobby_now()

func join_lobby(code: String) -> void:
	var cleaned := code.strip_edges().to_upper().replace(" ", "")
	if cleaned.is_empty():
		lobby_failed.emit("Enter a lobby code")
		return
	_pending_host = false
	_pending_join_code = cleaned
	if not is_online:
		connect_cloud()
		return
	_join_lobby_now(cleaned)

func leave() -> void:
	if _gds != null and is_online:
		_gds.call("lobby_leave")
	lobby_code = ""
	peer_ids.clear()
	_pending_host = false
	_pending_join_code = ""
	_connecting = false
	roster_changed.emit()
	status_changed.emit("Left lobby")

func set_lobby_match_data(data: Dictionary) -> void:
	if _gds == null or not is_host():
		return
	_gds.call("lobby_set_data", "match", data)

func get_lobby_match_data() -> Dictionary:
	if _gds == null:
		return {}
	var v: Variant = _gds.call("lobby_get_data", "match", {})
	return v as Dictionary if v is Dictionary else {}

func request_start_match(cfg: Dictionary) -> void:
	if _gds == null or not is_host():
		return
	set_lobby_match_data(cfg)
	# Broadcast via lobby data change + local emit; peers listen for host start RPC from menu.
	match_start_requested.emit(cfg)

func generate_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for i in 6:
		out += CODE_CHARS[rng.randi_range(0, CODE_CHARS.length() - 1)]
	return out

func _on_connected() -> void:
	_connecting = false
	is_online = true
	status_changed.emit("Connected")
	_expose_rpcs()
	connected_ok.emit()
	if _pending_host:
		_create_lobby_now()
	elif not _pending_join_code.is_empty():
		_join_lobby_now(_pending_join_code)

func _expose_rpcs() -> void:
	if _gds == null:
		return
	_gds.call("expose_func", Callable(self, "rpc_start_match"))

## Host calls this to start the match on every peer (including self via call_func_all).
func broadcast_start_match(cfg: Dictionary) -> void:
	if _gds == null or not is_host():
		return
	_gds.call("call_func_all", Callable(self, "rpc_start_match"), cfg)

func rpc_start_match(cfg: Dictionary) -> void:
	match_start_requested.emit(cfg)

func _on_connection_failed(error: int) -> void:
	_connecting = false
	is_online = false
	var msg := "Connection failed (%d)" % error
	status_changed.emit(msg)
	connection_error.emit(msg)

func _on_disconnected() -> void:
	is_online = false
	lobby_code = ""
	peer_ids.clear()
	status_changed.emit("Disconnected")
	roster_changed.emit()

func _create_lobby_now() -> void:
	_pending_host = false
	lobby_code = generate_code()
	status_changed.emit("Creating lobby %s…" % lobby_code)
	_gds.call(
		"lobby_create",
		lobby_code,
		"",
		false,
		LOBBY_LIMIT,
		{"game": "apex"},
		{}
	)

func _join_lobby_now(code: String) -> void:
	_pending_join_code = ""
	lobby_code = code
	status_changed.emit("Joining %s…" % code)
	_gds.call("lobby_join", code, "")

func _on_lobby_created(name: String) -> void:
	lobby_code = name
	status_changed.emit("Lobby created — joining…")
	_gds.call("lobby_join", name, "")

func _on_lobby_creation_failed(_name: String, error: int) -> void:
	lobby_code = ""
	var msg := "Lobby create failed (%d)" % error
	status_changed.emit(msg)
	lobby_failed.emit(msg)

func _on_lobby_joined(name: String) -> void:
	lobby_code = name
	_refresh_roster()
	status_changed.emit("In lobby %s" % name)
	lobby_ready.emit(name)

func _on_lobby_join_failed(_name: String, error: int) -> void:
	lobby_code = ""
	peer_ids.clear()
	var msg := "Join failed (%d)" % error
	status_changed.emit(msg)
	lobby_failed.emit(msg)
	roster_changed.emit()

func _on_client_joined(_client_id: int) -> void:
	_refresh_roster()

func _on_client_left(_client_id: int) -> void:
	_refresh_roster()

func _refresh_roster() -> void:
	peer_ids.clear()
	if _gds == null:
		roster_changed.emit()
		return
	var all: Array = _gds.call("lobby_get_all_clients") as Array
	for id in all:
		peer_ids.append(int(id))
	peer_ids.sort()
	roster_changed.emit()
