extends RefCounted
## Bot AI tests. Pure logic (profiles, perception, aim, navigation, utilities) runs with mocks;
## one integration test drives a real Fighter through BotInput.

var T: SceneTree
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(runner: SceneTree) -> void:
	T = runner

func before_each() -> void:
	_rng.seed = 1234
	BotNavigator.reset_budget()

# ---------------------------------------------------------------- profile and names

func test_profile_table() -> void:
	var r := BotProfile.rookie()
	var n := BotProfile.nightmare()
	T.assert_near(r.reaction_time, 0.55, 0.0001, "rookie reaction")
	T.assert_near(BotProfile.veteran().aim_error_deg, 3.5, 0.0001, "veteran aim error")
	T.assert_near(BotProfile.elite().view_range, 70.0, 0.0001, "elite range")
	T.assert_near(n.aim_tracking_deg_s, 600.0, 0.0001, "nightmare tracking")
	T.assert_near(n.flee_health, 20.0, 0.0001, "nightmare flee")
	T.assert_near(r.bhop_skill, 0.0, 0.0001, "rookie no bhop")
	T.assert_true(BotProfile.elite().hunts_leader() and not r.hunts_leader(), "leader hunting")

func test_profile_variation_bounds_and_purity() -> void:
	var base := BotProfile.veteran()
	for i in 50:
		var v := base.varied(_rng)
		T.assert_true(v.reaction_time >= base.reaction_time * 0.9 - 0.0001 and v.reaction_time <= base.reaction_time * 1.1 + 0.0001, "reaction within 10%")
		T.assert_true(v.aim_error_deg >= base.aim_error_deg * 0.9 - 0.0001 and v.aim_error_deg <= base.aim_error_deg * 1.1 + 0.0001, "aim error within 10%")
		T.assert_true(v.bhop_skill <= 1.0 and v.lead_accuracy <= 1.0, "unit params clamped")
	T.assert_near(base.reaction_time, 0.35, 0.0001, "base untouched")
	T.assert_near(BotProfile.rookie().varied(_rng).bhop_skill, 0.0, 0.0001, "zero stays zero")

func test_profile_variation_is_seeded() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 7
	b.seed = 7
	T.assert_near(BotProfile.elite().varied(a).reaction_time, BotProfile.elite().varied(b).reaction_time, 0.00001, "same seed same profile")

func test_profile_mixed_picks_neighbor() -> void:
	for i in 30:
		var m := BotProfile.mixed(_rng, BotProfile.Difficulty.VETERAN)
		T.assert_true(m.difficulty != BotProfile.Difficulty.NIGHTMARE, "veteran mixed never nightmare")

func test_names() -> void:
	T.assert_eq(BotNames.count(), 12, "12 names")
	T.assert_eq(BotNames.name_at(0), "Vex", "first")
	T.assert_eq(BotNames.name_at(11), "Blitz", "last")
	T.assert_eq(BotNames.count(), UITheme.BOT_COLORS.size(), "color per name")
	var order := BotNames.shuffled_indices(_rng)
	order.sort()
	T.assert_eq(order, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], "shuffle is a permutation")

# ---------------------------------------------------------------- perception

func _view(id: int, pos: Vector3) -> BotPerception.EnemyView:
	var v := BotPerception.EnemyView.new()
	v.id = id
	v.pos = pos
	return v

func _perception(p: BotProfile = null) -> BotPerception:
	var per := BotPerception.new(p if p != null else BotProfile.veteran(), 1)
	per.los_blocked = func(_a: Vector3, _b: Vector3) -> bool: return false
	return per

func test_perception_sees_in_cone_and_range() -> void:
	var per := _perception()
	var enemies: Array[BotPerception.EnemyView] = [_view(2, Vector3(0, 0, -20))]
	per.update(0.0, Vector3(0, 1.6, 0), Vector3.FORWARD, enemies)
	T.assert_true(per.sighting_of(2) != null and per.sighting_of(2).visible, "enemy ahead is seen")

func test_perception_respects_fov_and_range() -> void:
	var per := _perception()
	var behind: Array[BotPerception.EnemyView] = [_view(2, Vector3(0, 0, 10))]
	per.update(0.0, Vector3(0, 1.6, 0), Vector3.FORWARD, behind)
	T.assert_true(per.sighting_of(2) == null, "behind the bot is not seen")
	var far: Array[BotPerception.EnemyView] = [_view(3, Vector3(0, 0, -80))]
	per.update(0.1, Vector3(0, 1.6, 0), Vector3.FORWARD, far)
	T.assert_true(per.sighting_of(3) == null, "beyond view range is not seen")

func test_perception_no_wallhack() -> void:
	var per := _perception()
	per.los_blocked = func(_a: Vector3, _b: Vector3) -> bool: return true
	var enemies: Array[BotPerception.EnemyView] = [_view(2, Vector3(0, 0, -10))]
	per.update(0.0, Vector3(0, 1.6, 0), Vector3.FORWARD, enemies)
	T.assert_true(per.sighting_of(2) == null, "blocked enemy is not seen")
	T.assert_true(per.rays_used <= BotPerception.MAX_RAYS, "ray budget")

func test_perception_ray_budget() -> void:
	var per := _perception()
	per.los_blocked = func(_a: Vector3, _b: Vector3) -> bool: return true
	var enemies: Array[BotPerception.EnemyView] = []
	for i in 6:
		enemies.append(_view(10 + i, Vector3(float(i) - 3.0, 0, -15)))
	per.update(0.0, Vector3(0, 1.6, 0), Vector3.FORWARD, enemies)
	T.assert_eq(per.rays_used, BotPerception.MAX_RAYS, "never more than 4 rays per update")

func test_perception_reaction_delay() -> void:
	var p := BotProfile.veteran() ## reaction 0.35
	var per := _perception(p)
	var enemies: Array[BotPerception.EnemyView] = [_view(2, Vector3(0, 0, -15))]
	per.update(1.0, Vector3(0, 1.6, 0), Vector3.FORWARD, enemies)
	T.assert_true(not per.is_engageable(2, 1.0), "not engageable immediately")
	T.assert_true(not per.is_engageable(2, 1.2), "not engageable before reaction time")
	per.update(1.3, Vector3(0, 1.6, 0), Vector3.FORWARD, enemies)
	T.assert_true(not per.is_engageable(2, 1.3), "still inside reaction window")
	per.update(1.4, Vector3(0, 1.6, 0), Vector3.FORWARD, enemies)
	T.assert_true(per.is_engageable(2, 1.4), "engageable after reaction time")

func test_perception_memory_expires() -> void:
	var per := _perception(BotProfile.rookie()) ## memory 2 s
	var enemies: Array[BotPerception.EnemyView] = [_view(2, Vector3(0, 0, -15))]
	per.update(0.0, Vector3(0, 1.6, 0), Vector3.FORWARD, enemies)
	per.update(1.0, Vector3(0, 1.6, 0), Vector3.FORWARD, enemies)
	var none: Array[BotPerception.EnemyView] = []
	per.update(2.0, Vector3(0, 1.6, 0), Vector3.FORWARD, none)
	T.assert_true(per.sighting_of(2) != null and not per.sighting_of(2).visible, "remembered after losing sight")
	T.assert_true(per.is_engageable(2, 2.0), "memory still engageable")
	per.update(3.5, Vector3(0, 1.6, 0), Vector3.FORWARD, none)
	T.assert_true(per.sighting_of(2) == null, "forgotten after memory_time")

func test_perception_hearing_ranges() -> void:
	var per := _perception()
	per.tick(0.0, 0.0, Vector3.ZERO)
	T.assert_true(per.hear(BotPerception.Stimulus.SHOT, Vector3(30, 0, 0), 2), "shot at 30 m heard")
	T.assert_true(not per.hear(BotPerception.Stimulus.SHOT, Vector3(40, 0, 0), 2), "shot at 40 m not heard")
	T.assert_true(per.hear(BotPerception.Stimulus.EXPLOSION, Vector3(45, 0, 0), 2), "explosion at 45 m heard")
	T.assert_true(not per.hear(BotPerception.Stimulus.GRAPPLE, Vector3(30, 0, 0), 2), "grapple at 30 m not heard")
	T.assert_true(not per.hear(BotPerception.Stimulus.SHOT, Vector3(5, 0, 0), 1), "own sounds ignored")
	T.assert_true(per.hear(BotPerception.Stimulus.DAMAGE, Vector3(100, 0, 0), 2), "damage always reveals attacker")
	T.assert_near(per.latest_stimulus().pos.x, 100.0, 0.001, "latest stimulus is the damage source")

func test_perception_stagger() -> void:
	var a := BotPerception.new(BotProfile.veteran(), 0)
	var b := BotPerception.new(BotProfile.veteran(), 3)
	var first_a: int = -1
	var first_b: int = -1
	for i in 20:
		if first_a < 0 and a.tick(0.01, 0.0, Vector3.ZERO):
			first_a = i
		if first_b < 0 and b.tick(0.01, 0.0, Vector3.ZERO):
			first_b = i
	T.assert_true(first_a >= 0 and first_b >= 0 and first_a != first_b, "bots update on different ticks")

# ---------------------------------------------------------------- aim

func test_aim_tracking_speed_limit() -> void:
	var aim := BotAim.new(BotProfile.rookie(), 1) ## 120 deg/s
	var d := aim.step(0.1, 0.0, 0.0, Vector3.RIGHT, false)
	T.assert_near(d.length(), deg_to_rad(12.0), 0.001, "rookie turns at most 12 degrees in 0.1 s")
	T.assert_true(d.x > 0.0, "look_delta.x positive turns right (yaw decreases)")

func test_aim_converges_without_error() -> void:
	var aim := BotAim.new(BotProfile.nightmare(), 1)
	var yaw: float = 0.0
	var pitch: float = 0.0
	var dir := Vector3(-3, 1, -5).normalized()
	for i in 120:
		var d := aim.step(1.0 / 120.0, yaw, pitch, dir, false)
		yaw -= d.x
		pitch -= d.y
	T.assert_near(BotAim.dir_from_angles(yaw, pitch).angle_to(dir), 0.0, 0.001, "aim reaches the direction")

func test_aim_error_magnitude() -> void:
	var p := BotProfile.rookie() ## 6 degrees
	var aim := BotAim.new(p, 5)
	for i in 40:
		aim.step(0.31, 0.0, 0.0, Vector3.FORWARD, true)
		T.assert_true(aim.error_offset.length() <= deg_to_rad(p.aim_error_deg) + 0.0001, "error bounded by aim_error")

func test_aim_projectile_lead() -> void:
	var p := BotProfile.nightmare() ## lead accuracy 1.0
	var aim := BotAim.new(p, 1)
	var eye := Vector3(0, 1.6, 0)
	var feet := Vector3(0, 0, -30)
	var vel := Vector3(10, 0, 0)
	var lead := aim.aim_point(eye, feet, vel, BotAim.PLASMA_SLOT, false)
	var torso := feet + Vector3.UP * BotAim.TORSO_HEIGHT
	var expected_t: float = eye.distance_to(torso) / BotAim.PLASMA_SPEED
	T.assert_near(lead.x, vel.x * expected_t, 0.001, "plasma leads by travel time")
	var hitscan := aim.aim_point(eye, feet, vel, BotWeapons.SMG, false)
	T.assert_near(hitscan.x, 0.0, 0.001, "hitscan does not lead")

func test_aim_rocket_feet() -> void:
	var aim := BotAim.new(BotProfile.nightmare(), 1)
	var eye := Vector3(0, 1.6, 0)
	var near := aim.aim_point(eye, Vector3(0, 0, -15), Vector3.ZERO, BotAim.ROCKET_SLOT, true)
	T.assert_true(near.y < 0.5, "rocket aims at feet when target grounded within 20 m")
	var far := aim.aim_point(eye, Vector3(0, 0, -30), Vector3.ZERO, BotAim.ROCKET_SLOT, true)
	T.assert_true(far.y > 0.5, "rocket aims at torso beyond 20 m")

# ---------------------------------------------------------------- weapons and items

func test_weapon_choice_by_distance() -> void:
	var all: Array[int] = [1, 2, 3, 4, 5, 6, 7]
	T.assert_eq(BotWeapons.choose(8.0, false, all), BotWeapons.SHOTGUN, "close: shotgun")
	T.assert_eq(BotWeapons.choose(25.0, false, all), BotWeapons.RAIL, "mid-far: railgun")
	var no_rail: Array[int] = [1, 2, 3, 4, 5, 6]
	T.assert_eq(BotWeapons.choose(25.0, false, no_rail), BotWeapons.ROCKET, "no rail: rocket 8-35")
	var starters: Array[int] = [1, 2]
	T.assert_eq(BotWeapons.choose(20.0, false, starters), BotWeapons.PISTOL, "pistol fallback")
	var blade_only: Array[int] = [1]
	T.assert_eq(BotWeapons.choose(2.0, false, blade_only), BotWeapons.BLADE, "blade when nothing else")

func test_rocket_never_point_blank_unless_winning() -> void:
	var pistol_rocket: Array[int] = [1, 2, 6]
	T.assert_eq(BotWeapons.choose(2.0, false, pistol_rocket), BotWeapons.PISTOL, "pistol preferred at point blank")
	var blade_rocket: Array[int] = [1, 6]
	T.assert_eq(BotWeapons.choose(2.0, false, blade_rocket), BotWeapons.BLADE, "no rocket under 3 m when not winning")
	T.assert_eq(BotWeapons.choose(2.0, true, blade_rocket), BotWeapons.ROCKET, "rocket allowed under 3 m when winning")

func test_item_utility() -> void:
	var hurt := BotItems.utility("medkit", 30.0, 0.0, false, 10.0, 0.0)
	var healthy := BotItems.utility("medkit", 100.0, 0.0, false, 10.0, 0.0)
	T.assert_true(hurt > 0.0 and healthy == 0.0, "no need when at full health")
	T.assert_true(BotItems.utility("medkit", 30.0, 0.0, false, 10.0, 0.0) > BotItems.utility("medkit", 30.0, 0.0, false, 40.0, 0.0), "closer is better")
	T.assert_true(BotItems.utility("powerup_overcharge", 100.0, 0.0, false, 30.0, 0.0) > hurt, "powerups rate very high")
	T.assert_true(BotItems.utility("weapon", 100.0, 0.0, false, 10.0, 0.0) > BotItems.utility("weapon", 100.0, 0.0, true, 10.0, 0.0), "unowned weapon preferred")
	T.assert_true(BotItems.utility("mega_health", 50.0, 0.0, false, 10.0, 3.0) > 0.0, "soon-to-spawn pickup still wanted")
	T.assert_eq(BotItems.utility("mega_health", 50.0, 0.0, false, 10.0, 60.0), 0.0, "far-future respawn ignored")

# ---------------------------------------------------------------- brain utilities

func _brain() -> BotBrain:
	return BotBrain.new(BotProfile.veteran(), 1, 99)

func test_brain_engage_vs_retreat() -> void:
	var b := _brain()
	var s := BotBrain.Situation.new()
	s.has_target = true
	s.threat_near = true
	T.assert_eq(b.choose(s), BotBrain.Goal.ENGAGE, "healthy with target engages")
	s.health = 10.0
	b.mark_goal_done()
	T.assert_eq(b.choose(s), BotBrain.Goal.RETREAT, "low health with threats retreats")

func test_brain_roams_when_idle() -> void:
	var b := _brain()
	T.assert_eq(b.choose(BotBrain.Situation.new()), BotBrain.Goal.ROAM, "nothing to do roams")

func test_brain_investigate_without_target() -> void:
	var b := _brain()
	var s := BotBrain.Situation.new()
	s.has_stimulus = true
	T.assert_eq(b.choose(s), BotBrain.Goal.INVESTIGATE, "sound investigates")

func test_brain_grabs_valuable_item() -> void:
	var b := _brain()
	var s := BotBrain.Situation.new()
	s.item_utility = 0.6
	T.assert_eq(b.choose(s), BotBrain.Goal.GRAB_ITEM, "valuable item beats roaming")

func test_brain_hysteresis() -> void:
	var b := _brain()
	var s := BotBrain.Situation.new()
	s.item_utility = 0.5
	b.choose(s)
	T.assert_eq(b.goal, BotBrain.Goal.GRAB_ITEM, "starts on item")
	b._goal_done = false ## the brain clears this once it has planned the goal
	s.has_stimulus = true ## Investigate 0.45 is not 20% above 0.5
	T.assert_true(BotBrain.utilities(s)[BotBrain.Goal.INVESTIGATE] > 0.0, "investigate scored")
	b.choose(s)
	T.assert_eq(b.goal, BotBrain.Goal.GRAB_ITEM, "no switch below the 20% margin")
	s.item_utility = 0.3
	b.choose(s)
	T.assert_eq(b.goal, BotBrain.Goal.INVESTIGATE, "switch when new utility clearly wins")

func test_brain_reposition_when_outaimed() -> void:
	var b := _brain()
	var s := BotBrain.Situation.new()
	s.has_target = true
	s.damage_taken = 60.0
	s.damage_dealt = 5.0
	T.assert_eq(b.choose(s), BotBrain.Goal.REPOSITION, "losing the exchange repositions")

# ---------------------------------------------------------------- navigation

func _grid_graph() -> AStar3D:
	var g := AStar3D.new()
	for i in 6:
		g.add_point(i, Vector3(float(i) * 3.0, 0.0, 0.0))
	for i in 5:
		g.connect_points(i, i + 1)
	g.add_point(10, Vector3(6.0, 1.0, 3.0)) ## raised branch off point 2
	g.connect_points(2, 10)
	return g

func test_navigator_follows_path() -> void:
	var nav := BotNavigator.new(_grid_graph(), BotProfile.veteran(), 1)
	nav.set_destination(Vector3(15, 0, 0))
	var pos := Vector3.ZERO
	var frame: int = 0
	for i in 400:
		nav.update(1.0 / 120.0, float(i) / 120.0, pos, Vector3.ZERO, frame)
		frame += 1
		if nav.arrived:
			break
		T.assert_true(nav.move_dir.x > 0.0, "heads toward +x")
		pos += nav.move_dir * 0.06
	T.assert_true(nav.arrived, "arrives at the destination")

func test_navigator_jump_on_step_up() -> void:
	var nav := BotNavigator.new(_grid_graph(), BotProfile.veteran(), 1)
	nav.set_destination(Vector3(6, 1, 3))
	var jumped := false
	var pos := Vector3.ZERO
	var frame: int = 0
	for i in 600:
		nav.update(1.0 / 120.0, float(i) / 120.0, pos, Vector3.ZERO, frame)
		frame += 1
		jumped = jumped or nav.jump_now
		if nav.arrived:
			break
		pos += nav.move_dir * 0.06
		pos.y = 1.0 if pos.z > 1.5 else 0.0
	T.assert_true(jumped, "jump flag raised before the step up")

func test_navigator_path_budget() -> void:
	var ok := 0
	for i in 5:
		if BotNavigator.try_consume_budget(77):
			ok += 1
	T.assert_eq(ok, BotNavigator.PATH_BUDGET_PER_TICK, "2 path queries per physics tick")
	T.assert_true(BotNavigator.try_consume_budget(78), "budget refreshes next tick")
	T.assert_true(BotNavigator.denied_requests > 0, "denied requests counted")

func test_navigator_budget_defers_requests() -> void:
	var a := BotNavigator.new(_grid_graph(), BotProfile.veteran(), 1)
	var b := BotNavigator.new(_grid_graph(), BotProfile.veteran(), 2)
	var c := BotNavigator.new(_grid_graph(), BotProfile.veteran(), 3)
	for n in [a, b, c]:
		(n as BotNavigator).set_destination(Vector3(15, 0, 0))
		(n as BotNavigator).update(0.01, 0.0, Vector3.ZERO, Vector3.ZERO, 500)
	T.assert_true(a.move_dir != Vector3.ZERO and b.move_dir != Vector3.ZERO, "first two get paths")
	T.assert_eq(c.move_dir, Vector3.ZERO, "third waits for next tick")
	c.update(0.01, 0.01, Vector3.ZERO, Vector3.ZERO, 501)
	T.assert_true(c.move_dir != Vector3.ZERO, "third served next tick")

func test_navigator_without_graph_steers_directly() -> void:
	var nav := BotNavigator.new(null, BotProfile.veteran(), 1)
	nav.set_destination(Vector3(0, 0, -20))
	nav.update(0.01, 0.0, Vector3.ZERO, Vector3.ZERO, 900)
	T.assert_near(nav.move_dir.z, -1.0, 0.01, "straight toward destination")

func test_navigator_graph_from_dictionary() -> void:
	var g := _grid_graph()
	T.assert_true(BotNavigator.graph_from({"waypoints": {"astar": g}}) == g, "resolves nested dictionary")
	T.assert_true(BotNavigator.graph_from(null) == null, "null source")

func test_stuck_escalation() -> void:
	var st := BotStuck.new()
	var pos := Vector3(5, 0, 5)
	var jumped := false
	var strafed := false
	var repathed := false
	var teleported := false
	for i in 700:
		st.update(0.01, pos, true, _rng)
		jumped = jumped or st.jump_now
		strafed = strafed or st.strafe_dir != 0.0
		repathed = repathed or st.want_repath
		teleported = teleported or st.want_teleport
	T.assert_true(jumped and strafed and repathed and teleported, "jump, strafe, repath, teleport in order")
	T.assert_eq(st.teleports, 1, "teleport counted")

func test_stuck_resets_when_moving() -> void:
	var st := BotStuck.new()
	for i in 600:
		st.update(0.01, Vector3(float(i) * 0.05, 0, 0), true, _rng)
		T.assert_true(not st.want_teleport and not st.jump_now, "no stuck handling while moving")

# ---------------------------------------------------------------- integration

func test_bot_input_drives_a_fighter() -> void:
	var root := Node3D.new()
	T.root.add_child(root)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	var bot := Fighter.new()
	bot.id = 5
	root.add_child(bot)
	var input := BotInput.new()
	input.setup(bot.id, BotProfile.veteran(), 42)
	bot.setup_bot(input)
	bot.global_position = Vector3(0, 0.1, 0)
	var frame: InputFrame = input.sample(1.0 / 120.0, bot)
	T.assert_true(frame != null, "sample returns a frame")
	for i in 120:
		frame = input.sample(1.0 / 120.0, bot)
	T.assert_true(frame.move.length() <= 1.001, "move input is normalized")
	T.assert_true(input.brain.navigator.has_destination, "roam picked a destination")
	input.shutdown()
	root.queue_free()
