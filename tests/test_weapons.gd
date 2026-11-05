extends RefCounted
## M2 weapon tests: library values, handling (ammo, switching, intervals), hit detection.

var T: SceneTree


func setup(runner: SceneTree) -> void:
	T = runner


func _world() -> WeaponTestWorld:
	return WeaponTestWorld.create(T)


func _frame(fire_held: bool = false) -> InputFrame:
	var frame := InputFrame.new()
	frame.fire_held = fire_held
	return frame


# ---------------------------------------------------------------- library / loadout

func test_library_matches_gdd_table() -> void:
	T.assert_eq(WeaponLibrary.all().size(), 8, "eight weapons including portal")
	var table: Array = [
		# slot, damage, interval, ammo_start, ammo_max
		[1, 55.0, 0.55, 0, 0], [2, 20.0, 0.28, 0, 0], [3, 9.0, 0.075, 60, 200],
		[4, 9.0, 0.85, 10, 24], [5, 14.0, 0.11, 50, 200], [6, 85.0, 0.85, 5, 20],
		[7, 85.0, 1.4, 4, 12], [8, 0.0, 0.35, 24, 24],
	]
	for row: Array in table:
		var def: WeaponDef = WeaponLibrary.get_def(row[0] as int)
		T.assert_eq(def.id, row[0] as int, "slot id")
		T.assert_near(def.damage, row[1] as float, 0.001, "%s damage" % def.display_name)
		T.assert_near(def.fire_interval, row[2] as float, 0.0001, "%s interval" % def.display_name)
		T.assert_eq(def.ammo_start, row[3] as int, "%s ammo start" % def.display_name)
		T.assert_eq(def.ammo_max, row[4] as int, "%s ammo max" % def.display_name)
	T.assert_eq(WeaponLibrary.get_def(0), null, "slot 0 invalid")
	T.assert_eq(WeaponLibrary.get_def(9), null, "slot 9 invalid")
	var rocket: WeaponDef = WeaponLibrary.get_def(6)
	T.assert_near(rocket.splash_damage, 80.0, 0.001, "rocket splash")
	T.assert_near(rocket.splash_radius, 4.5, 0.001, "rocket radius")
	T.assert_near(rocket.knockback_speed, 16.0, 0.001, "rocket knockback")
	T.assert_eq(WeaponLibrary.get_def(4).pellets, 10, "shotgun pellets")
	T.assert_eq(WeaponLibrary.get_def(7).pierce_count, 3, "rail pierce")
	T.assert_near(WeaponLibrary.get_def(7).zoom_fov, 40.0, 0.001, "rail zoom")
	T.assert_eq(WeaponLibrary.get_def(8).fire_type, WeaponDef.FireType.PORTAL, "portal type")


func test_spawn_loadout_blade_only() -> void:
	var inv := WeaponInventory.new()
	for slot in range(1, WeaponLibrary.SLOT_COUNT + 1):
		T.assert_eq(inv.has_weapon(slot), slot == WeaponLibrary.SLOT_BLADE, "owned slot %d" % slot)
	T.assert_eq(inv.current_slot, WeaponLibrary.SLOT_BLADE, "starts on blade")
	inv.free()


func test_weapon_marker_types_map_to_slots() -> void:
	var spawner := PickupSpawner.new()
	T.assert_eq(int(spawner.WEAPON_SLOTS["weapon_pistol"]), WeaponLibrary.SLOT_PISTOL, "pistol")
	T.assert_eq(int(spawner.WEAPON_SLOTS["weapon_smg"]), WeaponLibrary.SLOT_SMG, "smg")
	T.assert_eq(int(spawner.WEAPON_SLOTS["weapon_portal"]), WeaponLibrary.SLOT_PORTAL, "portal")
	T.assert_eq(spawner._parse_kind("weapon_rocket"), GamePickup.Kind.WEAPON, "rocket kind")
	T.assert_eq(spawner._default_delivery(GamePickup.Kind.WEAPON, WeaponLibrary.SLOT_SMG),
		GamePickup.Delivery.SKY_DROP, "guns sky-drop")
	T.assert_eq(spawner._default_delivery(GamePickup.Kind.WEAPON, WeaponLibrary.SLOT_PORTAL),
		GamePickup.Delivery.CAGED, "portal caged")
	T.assert_eq(spawner._default_delivery(GamePickup.Kind.MEGA_HEALTH, 0),
		GamePickup.Delivery.CAGED, "mega caged")
	spawner.free()


func test_portal_gun_def_exists() -> void:
	var def: WeaponDef = WeaponLibrary.get_def(WeaponLibrary.SLOT_PORTAL)
	T.assert_true(def != null, "portal def")
	T.assert_eq(def.fire_type, WeaponDef.FireType.PORTAL, "portal type")
	T.assert_eq(WeaponLibrary.SLOT_COUNT, 8, "eight slots")


func test_distance_falloff_shotgun() -> void:
	var def: WeaponDef = WeaponLibrary.get_def(4)
	T.assert_near(def.distance_mult(5.0), 1.0, 0.0001, "5 m")
	T.assert_near(def.distance_mult(15.0), 1.0, 0.0001, "15 m")
	T.assert_near(def.distance_mult(25.0), 0.7, 0.0001, "25 m")
	T.assert_near(def.distance_mult(35.0), 0.4, 0.0001, "35 m")
	T.assert_near(def.distance_mult(80.0), 0.4, 0.0001, "far")
	T.assert_near(10.0 * def.damage * def.distance_mult(5.0), 90.0, 0.01, "5 m total")
	T.assert_near(10.0 * def.damage * def.distance_mult(25.0), 63.0, 0.01, "25 m total")


# ---------------------------------------------------------------- hitscan damage

func test_hitscan_damage_and_headshots_at_10m() -> void:
	for slot in [WeaponLibrary.SLOT_PISTOL, WeaponLibrary.SLOT_SMG, WeaponLibrary.SLOT_RAIL]:
		var def: WeaponDef = WeaponLibrary.get_def(slot as int)
		var w := _world()
		var dummy := w.add_dummy(Vector3(0.0, 0.0, -10.0))
		await w.settle()
		w.aim_pos = Vector3(0.0, 0.9, 0.0)
		T.assert_true(w.fire(slot as int), "%s fires" % def.display_name)
		T.assert_eq(dummy.hits_taken, 1, "%s body hit" % def.display_name)
		T.assert_near(dummy.total_damage_taken, def.damage, 0.01, "%s body damage" % def.display_name)
		T.assert_true(not dummy.last_info.is_head, "%s body not head" % def.display_name)
		dummy.reset()
		w.aim_pos = Vector3(0.0, 1.62, 0.0)
		w.fire(slot as int)
		T.assert_true(dummy.last_info != null and dummy.last_info.is_head, "%s head hit" % def.display_name)
		T.assert_near(dummy.total_damage_taken, def.damage * def.head_mult, 0.01, "%s head damage" % def.display_name)
		w.dispose()


func test_shotgun_pellets_and_falloff_in_world() -> void:
	var w := _world()
	w.capture()
	w.add_dummy(Vector3(0.0, 0.0, -5.0))
	await w.settle()
	T.assert_true(w.fire(WeaponLibrary.SLOT_SHOTGUN), "fires")
	T.assert_eq(w.infos.size(), 10, "all 10 pellets hit at 5 m")
	for info in w.infos:
		T.assert_near(info.amount, 9.0, 0.001, "pellet damage at 5 m")
	T.assert_near(w.total_damage(), 90.0, 0.01, "about 90 at 5 m")
	w.dispose()
	var far := _world()
	far.capture()
	far.add_dummy(Vector3(0.0, 0.0, -25.0))
	await far.settle()
	far.fire(WeaponLibrary.SLOT_SHOTGUN)
	T.assert_true(far.infos.size() <= 10, "no more than 10 pellets")
	for info in far.infos:
		var dist: float = far.aim_pos.distance_to(info.hit_pos)
		var expected: float = 9.0 * WeaponLibrary.get_def(4).distance_mult(dist) * (1.5 if info.is_head else 1.0)
		T.assert_near(info.amount, expected, 0.001, "pellet damage follows falloff")
		T.assert_true(info.amount < 9.0 * (1.5 if info.is_head else 1.0), "falloff reduces damage at 25 m")
		T.assert_true(dist > 23.0 and dist < 26.0, "hit distance near 25 m")
	far.dispose()


func test_spread_identical_for_same_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	var c := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	c.seed = 100
	var basis := Basis.IDENTITY
	var differs: bool = false
	for i in 20:
		var da: Vector3 = WeaponUtils.spread_dir(basis, 4.5, a)
		var db: Vector3 = WeaponUtils.spread_dir(basis, 4.5, b)
		var dc: Vector3 = WeaponUtils.spread_dir(basis, 4.5, c)
		T.assert_true(da.is_equal_approx(db), "same seed same dir")
		T.assert_true(rad_to_deg(da.angle_to(Vector3.FORWARD)) <= 4.5 + 0.001, "inside the cone")
		differs = differs or not da.is_equal_approx(dc)
	T.assert_true(differs, "different seed differs")
	var w := _world()
	w.capture()
	w.add_dummy(Vector3(0.0, 0.0, -5.0))
	await w.settle()
	w.inventory.rng.seed = 42
	w.fire(WeaponLibrary.SLOT_SHOTGUN)
	var first: Array[Vector3] = []
	for info in w.infos:
		first.append(info.hit_pos)
	w.infos.clear()
	w.inventory.rng.seed = 42
	w.fire(WeaponLibrary.SLOT_SHOTGUN)
	T.assert_eq(w.infos.size(), first.size(), "same pellet count")
	for i in mini(first.size(), w.infos.size()):
		T.assert_true(w.infos[i].hit_pos.is_equal_approx(first[i]), "pellet %d identical" % i)
	w.dispose()


func test_smg_spread_blooms_and_recovers() -> void:
	var w := _world()
	var weapon: WeaponBase = w.inventory.weapons[WeaponLibrary.SLOT_SMG - 1]
	T.assert_near(weapon.spread_deg, 0.3, 0.0001, "starts tight")
	for i in 20:
		w.fire(WeaponLibrary.SLOT_SMG)
	T.assert_near(weapon.spread_deg, 3.5, 0.0001, "bloom clamps at max")
	for i in 30:
		weapon.tick(WeaponTestWorld.TICK) # 0.25 s
	T.assert_near(weapon.spread_deg, 0.3, 0.001, "recovers over 0.25 s")
	w.dispose()


func test_railgun_pierces_exactly_three() -> void:
	var w := _world()
	var line: Array[TargetDummy] = []
	for i in 4:
		line.append(w.add_dummy(Vector3(0.0, 0.0, -8.0 - 4.0 * i)))
	await w.settle()
	T.assert_true(w.fire(WeaponLibrary.SLOT_RAIL), "rail fires")
	for i in 3:
		T.assert_near(line[i].total_damage_taken, 85.0, 0.01, "dummy %d pierced" % i)
	T.assert_eq(line[3].hits_taken, 0, "fourth dummy untouched")
	w.dispose()


func test_railgun_stops_at_world_geometry() -> void:
	var w := _world()
	var front := w.add_dummy(Vector3(0.0, 0.0, -8.0))
	w.add_wall(Vector3(0.0, 2.0, -12.0), Vector3(10.0, 6.0, 0.5))
	var behind := w.add_dummy(Vector3(0.0, 0.0, -16.0))
	await w.settle()
	w.fire(WeaponLibrary.SLOT_RAIL)
	T.assert_near(front.total_damage_taken, 85.0, 0.01, "front dummy hit")
	T.assert_eq(behind.hits_taken, 0, "dummy behind wall untouched")
	w.dispose()


# ---------------------------------------------------------------- melee

func test_blade_backstab_lunge_and_range() -> void:
	var w := _world()
	var dummy := w.add_dummy(Vector3(0.0, 0.0, -1.5))
	await w.settle()
	T.assert_true(w.fire(WeaponLibrary.SLOT_BLADE), "swing")
	T.assert_near(dummy.total_damage_taken, 110.0, 0.01, "backstab doubles damage")
	T.assert_near(w.shooter.velocity.z, -6.0, 0.001, "lunge toward aim")
	dummy.reset()
	dummy.rotation.y = PI
	await w.settle()
	w.fire(WeaponLibrary.SLOT_BLADE)
	T.assert_near(dummy.total_damage_taken, 55.0, 0.01, "front hit is plain damage")
	dummy.reset()
	dummy.position = Vector3(0.0, 0.0, -5.0)
	await w.settle()
	w.fire(WeaponLibrary.SLOT_BLADE)
	T.assert_eq(dummy.hits_taken, 0, "out of range")
	dummy.position = Vector3(2.0, 0.0, -0.5)
	await w.settle()
	w.fire(WeaponLibrary.SLOT_BLADE)
	T.assert_eq(dummy.hits_taken, 0, "outside the 60 degree cone")
	w.dispose()


# ---------------------------------------------------------------- viewmodel

func test_viewmodel_models_use_fallback_materials() -> void:
	var view := Viewmodel.new()
	T.root.add_child(view)
	for slot in range(1, WeaponLibrary.SLOT_COUNT + 1):
		var model: Node3D = view.get_model(slot)
		T.assert_true(model != null, "model for slot %d" % slot)
		var parts: int = 0
		var last_priority: int = -129
		for child in model.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null:
				continue
			parts += 1
			var mat := mesh.material_override as StandardMaterial3D
			T.assert_true(mat != null and mat.no_depth_test, "slot %d part uses no_depth_test" % slot)
			T.assert_true(mat.render_priority > last_priority, "slot %d render_priority ascends" % slot)
			last_priority = mat.render_priority
		T.assert_true(parts >= 4 and parts <= 10, "slot %d has 4-10 primitives (got %d)" % [slot, parts])
	T.assert_true(view.get_model(0) == null, "invalid slot gives null")
	view.set_mode(Viewmodel.Mode.HIDDEN)
	T.assert_true(not view.visible, "hidden mode hides the viewmodel")
	T.root.remove_child(view)
	view.free()


func test_viewmodel_follows_inventory_and_animates() -> void:
	var w := _world()
	var camera := Camera3D.new()
	w.add_child(camera)
	var view := Viewmodel.new()
	view.attach(camera, w.inventory)
	T.assert_true(view.get_parent() == camera, "attached to the camera")
	T.assert_true(view.get_model(WeaponLibrary.SLOT_BLADE).visible, "starts on the blade model")
	w.inventory.give_weapon(WeaponLibrary.SLOT_RAIL, false)
	w.inventory.select_slot(WeaponLibrary.SLOT_RAIL)
	T.assert_true(view.get_model(WeaponLibrary.SLOT_RAIL).visible, "switches model with the inventory")
	T.assert_true(not view.get_model(WeaponLibrary.SLOT_BLADE).visible, "previous model hidden")
	view.set_motion(Vector2(0.01, 0.0), Vector3(3.0, 0.0, -9.0), true)
	view.kick(1.0)
	view._process(0.016)
	var kicked: float = view.get_node("Pivot").position.z
	for i in 60:
		view._process(0.016)
	T.assert_true(absf(view.get_node("Pivot").position.z - kicked) > 0.0, "pose changes over time")
	w.inventory.select_slot(WeaponLibrary.SLOT_BLADE)
	var blade: Node3D = view.get_model(WeaponLibrary.SLOT_BLADE)
	view._process(0.016)
	var idle_z: float = blade.position.z
	view._on_weapon_fired(WeaponLibrary.SLOT_BLADE)
	for i in 8:
		view._process(0.025)
	T.assert_true(blade.position.z < idle_z - 0.2, "blade reaches away from camera on swing")
	for i in 40:
		view._process(0.016)
	T.assert_true(is_equal_approx(blade.position.z, Viewmodel.BLADE_REST_POS.z), "blade returns to rest")
	w.dispose()


# ---------------------------------------------------------------- handling

func test_fire_interval_matches_spec_within_one_tick() -> void:
	var w := _world()
	w.inventory.give_weapon(WeaponLibrary.SLOT_SMG, false)
	w.inventory.select_slot(WeaponLibrary.SLOT_SMG)
	var times: Array[float] = []
	var tick: Array[int] = [0]
	w.inventory.weapon_fired.connect(func(_slot: int) -> void: times.append(tick[0] * WeaponTestWorld.TICK))
	var frame := _frame(true)
	for i in 120:
		tick[0] = i
		w.inventory.step(frame, WeaponTestWorld.TICK)
	T.assert_true(times.size() >= 2, "fired repeatedly")
	T.assert_near(times[0], 0.25, WeaponTestWorld.TICK + 0.0001, "first shot after raise")
	for i in range(1, times.size()):
		T.assert_near(times[i] - times[i - 1], 0.075, WeaponTestWorld.TICK + 0.0001, "gap %d" % i)
	var expected_shots: int = int(floor((1.0 - times[0]) / 0.075)) + 1
	T.assert_near(float(times.size()), float(expected_shots), 1.0, "shot count over 1 s")
	w.dispose()


func test_ammo_decrements_and_infinite_weapons_do_not() -> void:
	var w := _world()
	T.assert_eq(w.inventory.get_ammo(WeaponLibrary.SLOT_RAIL), 4, "rail starts with 4")
	w.fire(WeaponLibrary.SLOT_RAIL)
	T.assert_eq(w.inventory.get_ammo(WeaponLibrary.SLOT_RAIL), 3, "rail ammo drops")
	w.fire(WeaponLibrary.SLOT_PISTOL)
	w.fire(WeaponLibrary.SLOT_PISTOL)
	T.assert_eq(w.inventory.get_ammo(WeaponLibrary.SLOT_PISTOL), 0, "pistol ammo stays 0 (infinite)")
	T.assert_true(w.inventory.weapons[WeaponLibrary.SLOT_PISTOL - 1].has_ammo(), "pistol never empty")
	w.inventory.infinite_ammo = true
	w.fire(WeaponLibrary.SLOT_RAIL)
	T.assert_eq(w.inventory.get_ammo(WeaponLibrary.SLOT_RAIL), 3, "infinite toggle keeps ammo")
	w.dispose()


func test_cannot_fire_while_cooling_down() -> void:
	var w := _world()
	var weapon: WeaponBase = w.inventory.weapons[WeaponLibrary.SLOT_PISTOL - 1]
	var aim: Transform3D = w.get_aim()
	T.assert_true(weapon.try_fire(aim, aim.origin), "first shot")
	T.assert_true(not weapon.try_fire(aim, aim.origin), "second shot blocked by cooldown")
	for i in 40:
		weapon.tick(WeaponTestWorld.TICK)
	T.assert_true(weapon.try_fire(aim, aim.origin), "ready after interval")
	w.dispose()


func test_switch_time_blocks_firing() -> void:
	var w := _world()
	w.inventory.give_weapon(WeaponLibrary.SLOT_SHOTGUN, false)
	T.assert_true(w.inventory.select_slot(WeaponLibrary.SLOT_SHOTGUN), "switch")
	var shots: Array[int] = [0]
	w.inventory.weapon_fired.connect(func(_slot: int) -> void: shots[0] += 1)
	var frame := _frame(true)
	for i in 29: # 0.2417 s, still raising
		w.inventory.step(frame, WeaponTestWorld.TICK)
	T.assert_eq(shots[0], 0, "no shot while raising")
	T.assert_true(w.inventory.is_raising(), "still raising")
	for i in 3:
		w.inventory.step(frame, WeaponTestWorld.TICK)
	T.assert_eq(shots[0], 1, "fires once the 0.25 s switch completes")
	w.dispose()


func test_auto_switch_when_ammo_runs_out() -> void:
	var w := _world()
	w.inventory.give_weapon(WeaponLibrary.SLOT_RAIL, false)
	w.inventory.select_slot(WeaponLibrary.SLOT_RAIL)
	w.inventory.switch_timer = 0.0
	w.inventory.weapons[WeaponLibrary.SLOT_RAIL - 1].ammo = 1
	w.inventory.step(_frame(true), WeaponTestWorld.TICK)
	T.assert_eq(w.inventory.get_ammo(WeaponLibrary.SLOT_RAIL), 0, "last round fired")
	T.assert_eq(w.inventory.current_slot, WeaponLibrary.SLOT_BLADE, "falls back to blade when no guns")
	w.inventory.give_weapon(WeaponLibrary.SLOT_SMG, false)
	w.inventory.give_weapon(WeaponLibrary.SLOT_PISTOL, false)
	w.inventory.select_slot(WeaponLibrary.SLOT_SMG)
	w.inventory.weapons[WeaponLibrary.SLOT_SMG - 1].ammo = 0
	w.inventory.switch_timer = 0.0
	w.inventory.step(_frame(true), WeaponTestWorld.TICK)
	T.assert_eq(w.inventory.current_slot, WeaponLibrary.SLOT_PISTOL, "dry fire switches to next best gun")
	w.dispose()


func test_pickup_auto_switch_rules() -> void:
	var inv := WeaponInventory.new()
	T.assert_true(inv.give_weapon(WeaponLibrary.SLOT_ROCKET), "gives rocket")
	T.assert_eq(inv.current_slot, WeaponLibrary.SLOT_ROCKET, "auto-switch from blade")
	T.assert_eq(inv.get_ammo(WeaponLibrary.SLOT_ROCKET), 5, "starting ammo")
	inv.give_weapon(WeaponLibrary.SLOT_RAIL)
	T.assert_eq(inv.current_slot, WeaponLibrary.SLOT_ROCKET, "no auto-switch from a real weapon")
	T.assert_true(inv.give_weapon(WeaponLibrary.SLOT_ROCKET), "adds ammo when owned")
	T.assert_eq(inv.get_ammo(WeaponLibrary.SLOT_ROCKET), 10, "ammo added")
	inv.add_ammo(WeaponLibrary.SLOT_ROCKET, 100)
	T.assert_eq(inv.get_ammo(WeaponLibrary.SLOT_ROCKET), 20, "ammo capped at max")
	T.assert_true(not inv.give_weapon(WeaponLibrary.SLOT_ROCKET), "full weapon refuses pickup")
	inv.free()


func test_ammo_box_and_cycling() -> void:
	var inv := WeaponInventory.new()
	T.assert_true(not inv.give_ammo_box(), "nothing to fill without ammo weapons")
	inv.give_weapon(WeaponLibrary.SLOT_SMG, false)
	inv.give_weapon(WeaponLibrary.SLOT_SHOTGUN, false)
	inv.give_ammo_box()
	T.assert_eq(inv.get_ammo(WeaponLibrary.SLOT_SMG), 60 + 80, "SMG gets 40% of 200")
	T.assert_eq(inv.get_ammo(WeaponLibrary.SLOT_SHOTGUN), 10 + 10, "shotgun gets ~40% of 24")
	T.assert_eq(inv.current_slot, WeaponLibrary.SLOT_BLADE, "still on blade before cycle")
	T.assert_true(inv.cycle(1), "cycle next")
	T.assert_eq(inv.current_slot, WeaponLibrary.SLOT_SMG, "next owned weapon after blade")
	T.assert_true(inv.switch_last(), "swap to last")
	T.assert_eq(inv.current_slot, WeaponLibrary.SLOT_BLADE, "back to previous")
	T.assert_true(inv.cycle(-1), "cycle previous")
	T.assert_eq(inv.current_slot, WeaponLibrary.SLOT_SHOTGUN, "wraps to highest owned")
	inv.free()


func test_railgun_zoom_on_alt_fire() -> void:
	var w := _world()
	w.inventory.give_weapon(WeaponLibrary.SLOT_RAIL, false)
	w.inventory.select_slot(WeaponLibrary.SLOT_RAIL)
	var frame := InputFrame.new()
	frame.alt_held = true
	w.inventory.step(frame, WeaponTestWorld.TICK)
	T.assert_near(w.inventory.get_zoom_fov(), 0.0, 0.001, "no zoom while raising")
	for i in 40:
		w.inventory.step(frame, WeaponTestWorld.TICK)
	T.assert_near(w.inventory.get_zoom_fov(), 40.0, 0.001, "zoomed to 40")
	T.assert_near(w.inventory.get_zoom_sensitivity_scale(100.0), 0.4, 0.001, "scaled sensitivity")
	w.inventory.step(InputFrame.new(), WeaponTestWorld.TICK)
	T.assert_near(w.inventory.get_zoom_fov(), 0.0, 0.001, "zoom ends on release")
	w.dispose()
