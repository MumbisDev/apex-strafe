class_name Hud
extends Control
## In-match HUD, built in code. Reactive parts listen to Events; local vitals are polled from the
## bound MatchManager (bind). Widgets live in their own scripts; this file wires them together.

signal respawn_requested

const RESPAWN_TIME: float = 2.0
const EARLY_RESPAWN_AT: float = 1.0
const MESSAGE_TIME: float = 2.2
const MEDAL_TIME: float = 2.0
const CENTER_TIME: float = 0.9
const NUMBER_POOL: int = 12
const NUMBER_TIME: float = 0.8
const INFO_INTERVAL: float = 0.1
const SHOTGUN_SLOT: int = 4
const SHOTGUN_SPREAD_PX: float = 18.0
const PICKUP_TEXT: Dictionary = {
	"STIM": "+25 HEALTH", "MEDKIT": "+50 HEALTH", "MEGA_HEALTH": "MEGA HEALTH +100",
	"ARMOR_SHARD": "+25 ARMOR", "ARMOR_PLATE": "+50 ARMOR", "AMMO_BOX": "AMMO",
	"WEAPON": "WEAPON", "BACKPACK": "BACKPACK",
}
const BLOOM_PER_SHOT: Dictionary = {2: 1.5, 3: 2.5}
const DEFAULT_BLOOM: float = 4.0
const POWERUP_TINTS: Dictionary = {"OVERCHARGE": Color("#B84DFF"), "HASTE": Color("#19E3FF")}

var local_id: int = -1
var crosshair: Crosshair
var kill_feed: KillFeed
var scoreboard: Scoreboard
var fx: FxOverlay
var vitals: HudVitals
var speedometer: Speedometer
var weapon_strip: WeaponStrip
var timer_label: Label
var rank_label: Label
var weapon_label: Label
var ammo_label: Label
var message_label: Label
var medal_label: Label
var center_label: Label
var death_box: VBoxContainer
var death_label: Label
var death_hint: Label
var camera: Camera3D

var _mm: MatchManager
var _shake: ScreenShake
var _weapon_id: int = 0
var _attacker_origin: Dictionary = {} ## fighter id -> Vector3 of their last shot
var _weapon_kills: Dictionary = {} ## weapon id -> local kills (handed to the results screen)
var _streak: int = 0
var _was_leader: bool = false
var _dead: bool = false
var _death_t: float = 0.0
var _msg_t: float = 0.0
var _medal_t: float = 0.0
var _center_t: float = 0.0
var _info_t: float = 0.0
var _numbers: Array[Label] = []
var _number_state: Array[Vector4] = [] ## xyz = world pos, w = age (negative = free)
var _number_layer: Control
var _practice_label: Label
var _fps_label: Label

static func ordinal(n: int) -> String:
	if n % 100 >= 11 and n % 100 <= 13:
		return "%dth" % n
	match n % 10:
		1: return "%dst" % n
		2: return "%dnd" % n
		3: return "%drd" % n
	return "%dth" % n

func _ready() -> void:
	theme = UITheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_connect_events()

## Hooks the HUD to a running match: roster, local camera, shake, world FX.
func bind(mm: MatchManager) -> void:
	_mm = mm
	local_id = mm.local_player_id
	scoreboard.local_id = local_id
	for id: int in mm.fighters:
		_register_from_mm(id)
	var f := mm.get_fighter(local_id)
	if f != null and f.camera_rig != null:
		camera = f.camera_rig.camera
		_shake.bind(f.camera_rig, local_id)
	var scene := mm.get_parent()
	if scene != null and get_tree().get_first_node_in_group(FxLibrary.GROUP) == null:
		scene.add_child(FxLibrary.new())
	_refresh_info()

func register_fighter(id: int, display_name: String, color: Color, is_bot: bool) -> void:
	var tag := ""
	if is_bot:
		tag = str(MatchConfig.Difficulty.keys()[int(Game.match_config.difficulty)]).capitalize()
	scoreboard.register(id, display_name, color, is_bot, tag)

func set_practice_info(lap: float, best: float, gates: String, infinite_ammo: bool) -> void:
	_practice_label.visible = true
	_practice_label.text = "LAP %.2f   BEST %s\nGATES %s%s" % [
		lap, ("%.2f" % best) if best > 0.0 else "--", gates, "\nINFINITE AMMO" if infinite_ammo else ""]

func set_time_left(seconds: float, overtime: bool = false) -> void:
	if overtime:
		timer_label.text = "OVERTIME"
		return
	var s := maxi(0, ceili(seconds))
	timer_label.text = "%d:%02d" % [floori(s / 60.0), s % 60]

func show_message(text: String, color: Color = UITheme.TEXT) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	_msg_t = MESSAGE_TIME

func show_medal(text: String) -> void:
	medal_label.text = text
	_medal_t = MEDAL_TIME

func is_dead() -> bool:
	return _dead

# -- build -------------------------------------------------------------------

func _build() -> void:
	fx = FxOverlay.new()
	add_child(fx)
	crosshair = Crosshair.new()
	add_child(crosshair)
	_number_layer = Control.new()
	_number_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_number_layer)
	for i in NUMBER_POOL:
		var l := _label(22)
		l.visible = false
		_number_layer.add_child(l)
		_numbers.append(l)
		_number_state.append(Vector4(0, 0, 0, -1))
	_build_top()
	_build_bottom()
	_build_center()
	scoreboard = Scoreboard.new()
	scoreboard.visible = false
	_place(scoreboard, 0.5, 0.5, 0, 0)
	add_child(scoreboard)
	_shake = ScreenShake.new()
	add_child(_shake)

func _build_top() -> void:
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label = _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	rank_label = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	rank_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	top.add_child(timer_label)
	top.add_child(rank_label)
	_place(top, 0.5, 0.0, 0, 14)
	add_child(top)
	kill_feed = KillFeed.new()
	_place(kill_feed, 1.0, 0.0, -24, 24)
	add_child(kill_feed)
	_fps_label = _label(14)
	_fps_label.visible = false
	_place(_fps_label, 0.0, 0.0, 16, 12)
	add_child(_fps_label)
	_practice_label = _label(18)
	_practice_label.visible = false
	_practice_label.add_theme_color_override("font_color", UITheme.ACCENT)
	_place(_practice_label, 0.0, 0.0, 16, 40)
	add_child(_practice_label)

func _build_bottom() -> void:
	vitals = HudVitals.new()
	_place(vitals, 0.0, 1.0, 32, -28)
	add_child(vitals)
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_label = _label(20, HORIZONTAL_ALIGNMENT_RIGHT)
	weapon_label.add_theme_color_override("font_color", UITheme.ACCENT)
	ammo_label = _label(54, HORIZONTAL_ALIGNMENT_RIGHT)
	weapon_strip = WeaponStrip.new()
	for c: Control in [weapon_label, ammo_label, weapon_strip]:
		right.add_child(c)
	_place(right, 1.0, 1.0, -32, -28)
	add_child(right)
	speedometer = Speedometer.new()
	_place(speedometer, 0.5, 1.0, 0, -16)
	add_child(speedometer)

func _build_center() -> void:
	message_label = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_place(message_label, 0.5, 0.72, 0, 0)
	add_child(message_label)
	medal_label = _label(52, HORIZONTAL_ALIGNMENT_CENTER)
	medal_label.add_theme_color_override("font_color", UITheme.ACCENT2)
	_place(medal_label, 0.35, 0.2, 0, 0)
	add_child(medal_label)
	center_label = _label(96, HORIZONTAL_ALIGNMENT_CENTER)
	center_label.add_theme_color_override("font_color", UITheme.ACCENT)
	_place(center_label, 0.5, 0.35, 0, 0)
	add_child(center_label)
	death_box = VBoxContainer.new()
	death_box.visible = false
	death_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_label = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	death_hint = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	death_hint.text = "Click to respawn"
	death_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	death_box.add_child(death_label)
	death_box.add_child(death_hint)
	_place(death_box, 0.5, 0.55, 0, 0)
	add_child(death_box)

func _label(font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l

## Anchors a control at (ax, ay) with a pixel offset; it grows away from that screen edge.
func _place(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = Control.GROW_DIRECTION_END if ax < 0.4 else (
		Control.GROW_DIRECTION_BEGIN if ax > 0.6 else Control.GROW_DIRECTION_BOTH)
	c.grow_vertical = Control.GROW_DIRECTION_END if ay < 0.4 else (
		Control.GROW_DIRECTION_BEGIN if ay > 0.9 else Control.GROW_DIRECTION_BOTH)

# -- events ------------------------------------------------------------------

func _connect_events() -> void:
	Events.fighter_spawned.connect(_on_fighter_spawned)
	Events.fighter_damaged.connect(_on_fighter_damaged)
	Events.fighter_killed.connect(_on_fighter_killed)
	Events.fighter_respawned.connect(_on_fighter_respawned)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.weapon_switched.connect(_on_weapon_switched)
	Events.pickup_collected.connect(_on_pickup_collected)
	Events.score_changed.connect(_on_score_changed)
	Events.medal_awarded.connect(_on_medal_awarded)
	Events.hit_confirmed.connect(_on_hit_confirmed)
	Events.powerup_announced.connect(_on_powerup_announced)
	Events.message.connect(_on_message)
	Events.match_countdown.connect(_on_match_countdown)
	Events.match_started.connect(_on_match_started)
	Events.match_ended.connect(_on_match_ended)

func _on_fighter_spawned(id: int) -> void:
	_register_from_mm(id)

func _on_fighter_damaged(victim_id: int, attacker_id: int, amount: float, hit_pos: Vector3, is_head: bool) -> void:
	if victim_id == local_id:
		fx.flash_damage(amount)
		if attacker_id != local_id and _attacker_origin.has(attacker_id):
			crosshair.add_damage_indicator(_angle_to(_attacker_origin[attacker_id] as Vector3))
	elif attacker_id == local_id and Settings.damage_numbers:
		_spawn_number(amount, hit_pos, is_head)

func _on_fighter_killed(victim_id: int, killer_id: int, weapon_id: int, is_head: bool) -> void:
	var vi := scoreboard.get_info(victim_id)
	var ki := scoreboard.get_info(killer_id)
	kill_feed.add_entry(str(ki["name"]), ki["color"] as Color, weapon_id, str(vi["name"]),
		vi["color"] as Color, is_head, victim_id == local_id or killer_id == local_id)
	scoreboard.record_kill(killer_id, victim_id)
	if killer_id == local_id and killer_id != victim_id:
		_weapon_kills[weapon_id] = int(_weapon_kills.get(weapon_id, 0)) + 1
		_streak += 1
		if _streak == 3 or _streak == 7:
			show_medal("%d KILL STREAK" % _streak)
	if victim_id == local_id:
		_streak = 0
		_begin_death()

func _on_fighter_respawned(id: int) -> void:
	if id == local_id:
		_end_death()

func _on_weapon_fired(id: int, weapon_id: int, origin: Vector3, _dir: Vector3) -> void:
	_attacker_origin[id] = origin
	if id == local_id:
		crosshair.kick(float(BLOOM_PER_SHOT.get(weapon_id, DEFAULT_BLOOM)))

func _on_weapon_switched(id: int, weapon_id: int) -> void:
	if id == local_id:
		_set_weapon(weapon_id)

func _on_pickup_collected(id: int, pickup_type: String, _pos: Vector3) -> void:
	if id == local_id:
		show_message(str(PICKUP_TEXT.get(pickup_type.to_upper(), pickup_type.replace("_", " ").to_upper())))

func _on_score_changed(id: int, score: int) -> void:
	scoreboard.set_score(id, score)
	if scoreboard.visible:
		scoreboard.refresh()
	_refresh_info()
	var leader := scoreboard.is_sole_leader(local_id)
	var live := _mm == null or _mm.phase == MatchManager.Phase.LIVE or _mm.phase == MatchManager.Phase.OVERTIME
	if live:
		if leader and not _was_leader and scoreboard.get_score(local_id) > 0:
			show_message("YOU TOOK THE LEAD", UITheme.ACCENT)
		elif not leader and _was_leader:
			show_message("LEAD LOST", UITheme.WARN)
	_was_leader = leader

func _on_medal_awarded(id: int, medal_name: String) -> void:
	if id == local_id:
		show_medal(medal_name.to_upper())

func _on_hit_confirmed(attacker_id: int, is_kill: bool, is_head: bool) -> void:
	if attacker_id != local_id:
		return
	crosshair.show_hit(is_kill, is_head)
	Audio.play_sfx("kill_confirm" if is_kill else ("hit_head" if is_head else "hitmarker"))

func _on_powerup_announced(text: String) -> void:
	show_message(text, UITheme.ACCENT2)

func _on_message(text: String) -> void:
	show_message(text)

func _on_match_countdown(seconds_left: int) -> void:
	center_label.text = str(seconds_left)
	_center_t = CENTER_TIME

func _on_match_started() -> void:
	center_label.text = "GO!"
	_center_t = CENTER_TIME

func _on_match_ended(_results: Dictionary) -> void:
	Game.set_meta("weapon_kills", _weapon_kills.duplicate())

# -- per-frame ---------------------------------------------------------------

func _process(delta: float) -> void:
	_poll_local()
	_tick_text(delta)
	_tick_death(delta)
	_tick_numbers(delta)
	speedometer.visible = Settings.speedometer
	_fps_label.visible = Settings.show_fps
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	var show_board := Input.is_action_pressed("scoreboard")
	if show_board and not scoreboard.visible:
		scoreboard.refresh()
	scoreboard.visible = show_board
	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = INFO_INTERVAL
		_refresh_info()

func _unhandled_input(event: InputEvent) -> void:
	if _dead and _death_t >= EARLY_RESPAWN_AT and event.is_action_pressed("fire"):
		respawn_requested.emit()
		if _mm != null:
			_mm.auth_request_respawn(local_id)

func _poll_local() -> void:
	if _mm == null:
		return
	var f := _mm.get_fighter(local_id)
	if f == null or f.health == null:
		return
	var hc := f.health
	vitals.set_health(hc.health, hc.armor, hc.max_health)
	var active: Dictionary = {"OVERCHARGE": hc.overcharge_t, "HASTE": hc.haste_t, "SHIELD": hc.spawn_protect_t}
	vitals.set_powerups(active)
	fx.set_health(hc.health)
	fx.set_tint(Color.WHITE, 0.0)
	for key: String in POWERUP_TINTS:
		if float(active[key]) > 0.0:
			fx.set_tint(POWERUP_TINTS[key] as Color, 0.6)
	if f.movement != null:
		var ups := f.movement.horizontal_speed(f)
		speedometer.set_speed(ups)
		fx.set_speed(ups, f.movement.state == MovementController.State.SLIDE)
		var cd_total := maxf(0.01, f.movement.config.grapple_cooldown)
		crosshair.grapple_ready = 1.0 - clampf(f.movement.grapple_cd / cd_total, 0.0, 1.0)
	_apply_inventory(f.inventory)

## Reads WeaponInventory: owned Array[bool], current_slot, get_ammo(slot).
func _apply_inventory(inv: Node) -> void:
	if inv == null:
		return
	var current := int(inv.get("current_slot"))
	if current <= 0:
		return
	if current != _weapon_id:
		_set_weapon(current)
	var states := PackedInt32Array()
	states.resize(WeaponStrip.SLOTS)
	var owned_v: Variant = inv.get("owned")
	var global_inf := bool(inv.get("infinite_ammo"))
	for slot in range(1, WeaponStrip.SLOTS + 1):
		var has := false
		if owned_v is Array:
			has = slot - 1 < (owned_v as Array).size() and bool((owned_v as Array)[slot - 1])
		if not has:
			states[slot - 1] = WeaponStrip.SlotState.EMPTY
			continue
		var def := WeaponLibrary.get_def(slot)
		var is_inf := global_inf or (def != null and def.infinite_ammo)
		var ammo_i := int(inv.call("get_ammo", slot)) if inv.has_method("get_ammo") else 0
		if is_inf or ammo_i > 0:
			states[slot - 1] = WeaponStrip.SlotState.OWNED
		else:
			states[slot - 1] = WeaponStrip.SlotState.NO_AMMO
	weapon_strip.set_states(states, current)
	var cur_def := WeaponLibrary.get_def(current)
	var cur_inf := global_inf or (cur_def != null and cur_def.infinite_ammo)
	var ammo := int(inv.call("get_ammo", current)) if inv.has_method("get_ammo") else 0
	ammo_label.text = "\u221E" if cur_inf else str(ammo)

func _set_weapon(weapon_id: int) -> void:
	_weapon_id = weapon_id
	weapon_label.text = KillFeed.weapon_name(weapon_id).to_upper()
	crosshair.base_spread = SHOTGUN_SPREAD_PX if weapon_id == SHOTGUN_SLOT else 0.0

func _refresh_info() -> void:
	if _mm != null:
		var unlimited := _mm.config != null and _mm.config.time_limit_sec == 0
		if unlimited and _mm.phase != MatchManager.Phase.OVERTIME:
			timer_label.text = "--:--"
		else:
			set_time_left(_mm.time_left, _mm.phase == MatchManager.Phase.OVERTIME)
	var rank := scoreboard.get_rank(local_id)
	if rank == 0:
		return
	var text := "%s  %d / %d" % [ordinal(rank), scoreboard.get_score(local_id), Game.match_config.kill_limit]
	if rank > 1:
		text += "  (Leader %d)" % scoreboard.get_leader_score()
	rank_label.text = text

func _register_from_mm(id: int) -> void:
	var f := _mm.get_fighter(id) if _mm != null else null
	if f != null:
		register_fighter(id, f.display_name, f.color, f.is_bot)

func _tick_text(delta: float) -> void:
	_msg_t = maxf(0.0, _msg_t - delta)
	message_label.modulate.a = clampf(_msg_t / 0.5, 0.0, 1.0)
	_medal_t = maxf(0.0, _medal_t - delta)
	var elapsed := MEDAL_TIME - _medal_t
	medal_label.pivot_offset = medal_label.size * 0.5
	medal_label.scale = Vector2.ONE * (1.0 + 0.5 * maxf(0.0, 1.0 - elapsed / 0.2))
	medal_label.modulate.a = clampf(_medal_t / 0.4, 0.0, 1.0) if _medal_t > 0.0 else 0.0
	_center_t = maxf(0.0, _center_t - delta)
	center_label.modulate.a = clampf(_center_t / 0.3, 0.0, 1.0)

func _begin_death() -> void:
	_dead = true
	_death_t = 0.0
	death_box.visible = true
	crosshair.visible = false
	fx.set_dead(true)

func _end_death() -> void:
	_dead = false
	death_box.visible = false
	crosshair.visible = true
	fx.set_dead(false)

func _tick_death(delta: float) -> void:
	if not _dead:
		return
	_death_t += delta
	death_label.text = "RESPAWN IN %d" % ceili(maxf(0.0, RESPAWN_TIME - _death_t))
	death_hint.visible = _death_t >= EARLY_RESPAWN_AT

# -- world-space helpers ------------------------------------------------------

## Angle of a world point relative to the camera view: 0 = ahead, positive = right.
func _angle_to(world_pos: Vector3) -> float:
	if camera == null:
		return 0.0
	var local := camera.global_transform.affine_inverse() * world_pos
	return atan2(local.x, -local.z)

func _spawn_number(amount: float, world_pos: Vector3, is_head: bool) -> void:
	var slot := 0
	var oldest := -1.0
	for i in NUMBER_POOL:
		if _number_state[i].w < 0.0:
			slot = i
			break
		if _number_state[i].w > oldest:
			oldest = _number_state[i].w
			slot = i
	_number_state[slot] = Vector4(world_pos.x, world_pos.y, world_pos.z, 0.0)
	var l := _numbers[slot]
	l.text = str(roundi(amount))
	l.add_theme_color_override("font_color", Color("#FFD24D") if is_head else Color.WHITE)
	l.visible = true

func _tick_numbers(delta: float) -> void:
	for i in NUMBER_POOL:
		var st := _number_state[i]
		if st.w < 0.0:
			continue
		st.w += delta
		var l := _numbers[i]
		var world := Vector3(st.x, st.y, st.z) + Vector3.UP * st.w * 1.2
		if st.w >= NUMBER_TIME or camera == null or camera.is_position_behind(world):
			st.w = -1.0
			l.visible = false
		else:
			l.position = camera.unproject_position(world) - l.size * 0.5
			l.modulate.a = 1.0 - st.w / NUMBER_TIME
		_number_state[i] = st
