class_name WeaponInventory
extends Node
## Owns the seven WeaponBase slots of one fighter: ownership, ammo, switching and trigger logic.
## Call step(frame, dt) once per physics tick from the fighter (no self-processing, so replays
## and tests stay deterministic).

signal weapon_changed(slot: int)
signal ammo_changed(slot: int, ammo: int)
signal weapon_fired(slot: int)
signal dry_fired(slot: int)
signal tracer(from: Vector3, to: Vector3, color: Color, lifetime: float)
signal impact(pos: Vector3, normal: Vector3, on_fighter: bool)

const FIRE_BUFFER_TIME: float = 0.12
const AMMO_BOX_FRACTION: float = 0.4
const EYE_HEIGHT: float = 1.62
const MUZZLE_OFFSET: Vector3 = Vector3(0.25, -0.2, -0.6)
const STARTER_SLOTS: Array[int] = [WeaponLibrary.SLOT_BLADE, WeaponLibrary.SLOT_PISTOL]

var shooter: Node3D:
	set(value):
		shooter = value
		_push_context()
		refresh_excludes()
var owner_id: int = -1:
	set(value):
		owner_id = value
		_push_context()
var camera: Camera3D
## Optional Callable() -> Transform3D overriding the aim origin/direction (bots, tests).
var aim_provider: Callable = Callable()
## Optional Callable() -> Vector3 giving the visual muzzle position (viewmodel).
var muzzle_provider: Callable = Callable()
## Callable(victim_id: int, info: DamageInfo); assign MatchManager.auth_apply_damage when it exists.
var damage_sink: Callable = Callable():
	set(value):
		damage_sink = value
		_push_context()
var rng: RandomNumberGenerator = RandomNumberGenerator.new():
	set(value):
		rng = value
		_push_context()
var fire_rate_mult: float = 1.0:
	set(value):
		fire_rate_mult = value
		_push_context()
var infinite_ammo: bool = false:
	set(value):
		infinite_ammo = value
		_push_context()
var knockback_mult: float = 1.0:
	set(value):
		knockback_mult = value
		_push_context()

var weapons: Array[WeaponBase] = []
var owned: Array[bool] = []
var current_slot: int = WeaponLibrary.SLOT_PISTOL
var last_slot: int = WeaponLibrary.SLOT_BLADE
var switch_timer: float = 0.0
var zoomed: bool = false
var pending_kick_deg: float = 0.0

var _fire_buffer: float = 0.0


func _init() -> void:
	rng.seed = 1
	for def in WeaponLibrary.all():
		var weapon := WeaponBase.new(def)
		weapon.fired.connect(_on_weapon_fired)
		weapon.tracer.connect(_on_tracer)
		weapon.impact.connect(_on_impact)
		weapons.append(weapon)
		owned.append(false)
	reset_loadout()


func _ready() -> void:
	var manager := WeaponUtils.find_match_manager(get_tree())
	if manager != null and manager.get("rng") is RandomNumberGenerator:
		rng = manager.get("rng") as RandomNumberGenerator
	_push_context()


## Fighters spawn with Blade and Sidearm only, holding the Sidearm.
func reset_loadout() -> void:
	for i in weapons.size():
		owned[i] = false
		weapons[i].ammo = weapons[i].def.ammo_start
		weapons[i].cooldown = 0.0
		weapons[i].spread_deg = weapons[i].def.spread_min_deg
	for slot in STARTER_SLOTS:
		owned[slot - 1] = true
	current_slot = WeaponLibrary.SLOT_PISTOL
	last_slot = WeaponLibrary.SLOT_BLADE
	switch_timer = 0.0
	zoomed = false
	pending_kick_deg = 0.0
	_fire_buffer = 0.0


func _push_context() -> void:
	var parent: Node = shooter.get_parent() if shooter != null else null
	for w in weapons:
		w.shooter = shooter
		w.owner_id = owner_id
		w.damage_sink = damage_sink
		w.rng = rng
		w.fire_rate_mult = fire_rate_mult
		w.unlimited_ammo = infinite_ammo
		w.knockback_mult = knockback_mult
		w.projectile_parent = parent


## Rebuilds the cached list of the shooter's own hitboxes (call after the fighter builds them).
func refresh_excludes() -> void:
	for w in weapons:
		w.refresh_excludes()


# ---------------------------------------------------------------- queries

func current_weapon() -> WeaponBase:
	return weapons[current_slot - 1]


func current_def() -> WeaponDef:
	return weapons[current_slot - 1].def


func has_weapon(slot: int) -> bool:
	return slot >= 1 and slot <= weapons.size() and owned[slot - 1]


func get_ammo(slot: int) -> int:
	return weapons[slot - 1].ammo


func can_select(slot: int) -> bool:
	return has_weapon(slot) and slot != current_slot and weapons[slot - 1].has_ammo()


func is_raising() -> bool:
	return switch_timer > 0.0


## 0..1 progress of the raise animation (1 when ready).
func raise_progress() -> float:
	var total: float = current_def().switch_time
	return 1.0 if total <= 0.0 else 1.0 - clampf(switch_timer / total, 0.0, 1.0)


## Zoom FOV while the alt-fire zoom is active, else 0.
func get_zoom_fov() -> float:
	return current_def().zoom_fov if zoomed else 0.0


## Mouse sensitivity multiplier while zoomed (FOV ratio), 1.0 otherwise.
func get_zoom_sensitivity_scale(base_fov: float) -> float:
	return get_zoom_fov() / base_fov if zoomed and base_fov > 0.0 else 1.0


func get_aim_transform() -> Transform3D:
	if aim_provider.is_valid():
		return aim_provider.call() as Transform3D
	if camera != null and is_instance_valid(camera):
		return camera.global_transform
	var body: Transform3D = shooter.global_transform
	return Transform3D(body.basis, body.origin + Vector3.UP * EYE_HEIGHT)


func get_muzzle_position(aim: Transform3D) -> Vector3:
	if muzzle_provider.is_valid():
		return muzzle_provider.call() as Vector3
	return aim.origin + aim.basis * MUZZLE_OFFSET


## Returns and clears the camera pitch kick (degrees) accumulated since the last call.
func consume_kick() -> float:
	var kick: float = pending_kick_deg
	pending_kick_deg = 0.0
	return kick


# ---------------------------------------------------------------- ammo / ownership

## Adds ammo to an owned weapon; returns the amount actually added.
func add_ammo(slot: int, amount: int) -> int:
	var weapon: WeaponBase = weapons[slot - 1]
	if weapon.def.infinite_ammo or not owned[slot - 1]:
		return 0
	var added: int = mini(amount, weapon.def.ammo_max - weapon.ammo)
	if added > 0:
		weapon.ammo += added
		ammo_changed.emit(slot, weapon.ammo)
	return maxi(added, 0)


## Grants a weapon (or its starting ammo if already owned). Returns false when nothing was given.
func give_weapon(slot: int, allow_auto_switch: bool = true) -> bool:
	var weapon: WeaponBase = weapons[slot - 1]
	var newly_owned: bool = not owned[slot - 1]
	if newly_owned:
		owned[slot - 1] = true
		weapon.ammo = 0
	var added: int = mini(weapon.def.ammo_start, weapon.def.ammo_max - weapon.ammo)
	if added <= 0 and not newly_owned:
		return false
	weapon.ammo += maxi(added, 0)
	ammo_changed.emit(slot, weapon.ammo)
	if newly_owned and allow_auto_switch and _should_auto_switch():
		select_slot(slot)
	return true


## Ammo box: ~40% of max ammo for every owned ammo weapon. Returns false if nothing was added.
func give_ammo_box() -> bool:
	var gave: bool = false
	for i in weapons.size():
		if not owned[i] or weapons[i].def.infinite_ammo:
			continue
		var amount: int = int(round(weapons[i].def.ammo_max * AMMO_BOX_FRACTION))
		if add_ammo(i + 1, amount) > 0:
			gave = true
	return gave


func _should_auto_switch() -> bool:
	if current_slot != WeaponLibrary.SLOT_BLADE and current_slot != WeaponLibrary.SLOT_PISTOL:
		return false
	var settings := WeaponUtils.get_autoload(&"Settings")
	return settings == null or bool(settings.get("auto_switch_on_pickup"))


# ---------------------------------------------------------------- switching

## Switches to an owned weapon with ammo; the new weapon cannot fire until raised.
func select_slot(slot: int) -> bool:
	if not can_select(slot):
		return false
	last_slot = current_slot
	current_slot = slot
	switch_timer = current_def().switch_time
	zoomed = false
	_fire_buffer = 0.0
	weapon_changed.emit(slot)
	WeaponUtils.emit_event(&"weapon_switched", [owner_id, slot])
	return true


## Cycles through owned weapons that have ammo. direction: +1 next, -1 previous.
func cycle(direction: int) -> bool:
	var count: int = weapons.size()
	for offset in range(1, count):
		var slot: int = posmod(current_slot - 1 + offset * direction, count) + 1
		if select_slot(slot):
			return true
	return false


func switch_last() -> bool:
	return select_slot(last_slot)


## Highest-slot owned weapon with ammo (Blade only if nothing else qualifies).
func best_slot_with_ammo(exclude_slot: int = -1) -> int:
	for slot in range(weapons.size(), 0, -1):
		if slot != exclude_slot and slot != WeaponLibrary.SLOT_BLADE and has_weapon(slot) and weapons[slot - 1].has_ammo():
			return slot
	return WeaponLibrary.SLOT_BLADE if exclude_slot != WeaponLibrary.SLOT_BLADE else -1


# ---------------------------------------------------------------- per-tick

func step(frame: InputFrame, dt: float) -> void:
	if switch_timer > 0.0:
		switch_timer = maxf(0.0, switch_timer - dt)
	for w in weapons:
		w.tick(dt)
	_handle_selection(frame)
	var weapon: WeaponBase = current_weapon()
	zoomed = weapon.def.zoom_fov > 0.0 and frame.alt_held and switch_timer <= 0.0
	if frame.fire_pressed and not weapon.def.auto_fire:
		_fire_buffer = FIRE_BUFFER_TIME
	elif _fire_buffer > 0.0:
		_fire_buffer = maxf(0.0, _fire_buffer - dt)
	if switch_timer > 0.0 or not (frame.fire_held or frame.fire_pressed or _fire_buffer > 0.0):
		return
	if not weapon.has_ammo():
		dry_fired.emit(current_slot)
		select_slot(best_slot_with_ammo(current_slot))
		return
	if weapon.cooldown > 0.0:
		return
	var aim: Transform3D = get_aim_transform()
	if weapon.try_fire(aim, get_muzzle_position(aim)):
		_fire_buffer = 0.0
		if not weapon.has_ammo():
			select_slot(best_slot_with_ammo(current_slot))


func _handle_selection(frame: InputFrame) -> void:
	if frame.weapon_select >= 1 and frame.weapon_select <= weapons.size():
		select_slot(frame.weapon_select)
	elif frame.weapon_next:
		cycle(1)
	elif frame.weapon_prev:
		cycle(-1)
	elif frame.weapon_last:
		switch_last()


func _on_weapon_fired(weapon_id: int, origin: Vector3, dir: Vector3) -> void:
	pending_kick_deg += weapons[weapon_id - 1].def.kick_pitch_deg
	weapon_fired.emit(weapon_id)
	ammo_changed.emit(weapon_id, weapons[weapon_id - 1].ammo)
	WeaponUtils.emit_event(&"weapon_fired", [owner_id, weapon_id, origin, dir])


func _on_tracer(from: Vector3, to: Vector3, color: Color, lifetime: float) -> void:
	tracer.emit(from, to, color, lifetime)


func _on_impact(pos: Vector3, normal: Vector3, on_fighter: bool) -> void:
	impact.emit(pos, normal, on_fighter)
