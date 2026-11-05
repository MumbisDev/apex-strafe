extends RefCounted
## M2 damage tests: DamageInfo, TargetDummy, damage routing, projectiles, rocket splash.

class FakeMatchManager extends Node:
	var calls: Array[DamageInfo] = []

	func auth_apply_damage(_victim_id: int, info: DamageInfo) -> void:
		calls.append(info)

var T: SceneTree


func setup(runner: SceneTree) -> void:
	T = runner


func _world() -> WeaponTestWorld:
	return WeaponTestWorld.create(T)


## Steps a projectile by hand until it detonates (or 400 ticks pass). Returns true if it detonated.
func _run_projectile(bolt: ProjectileRocket) -> bool:
	bolt.set_physics_process(false)
	for i in 400:
		bolt.advance(WeaponTestWorld.TICK)
		if bolt.detonated:
			return true
	return false


# ---------------------------------------------------------------- DamageInfo

func test_damage_info_defaults_and_create() -> void:
	var blank := DamageInfo.new()
	T.assert_near(blank.amount, 0.0, 0.0001, "amount default")
	T.assert_eq(blank.attacker_id, -1, "attacker default")
	T.assert_true(not blank.is_head and not blank.is_self and not blank.is_splash, "flags default false")
	T.assert_true(blank.impulse == Vector3.ZERO, "impulse default")
	var info := DamageInfo.create(20.0, 3, 5, 2, Vector3(1, 2, 3), true)
	T.assert_near(info.amount, 20.0, 0.0001, "amount")
	T.assert_eq(info.victim_id, 5, "victim")
	T.assert_eq(info.weapon_id, 2, "weapon")
	T.assert_true(info.is_head and not info.is_self, "head flag, not self")
	T.assert_true(DamageInfo.create(10.0, 4, 4, 6).is_self, "same ids flag self damage")


func test_damage_info_copy_and_scale() -> void:
	var info := DamageInfo.create(40.0, 1, 2, 6)
	info.impulse = Vector3(0, 16, 0)
	info.is_splash = true
	var copy := info.duplicate_info()
	copy.amount = 5.0
	T.assert_near(info.amount, 40.0, 0.0001, "copy is independent")
	var scaled := info.scaled(0.35)
	T.assert_near(scaled.amount, 14.0, 0.0001, "scaled amount")
	T.assert_true(scaled.is_splash and scaled.impulse == info.impulse, "scaled keeps flags and impulse")
	T.assert_near(info.amount, 40.0, 0.0001, "scaled does not mutate")


# ---------------------------------------------------------------- TargetDummy

func test_dummy_health_death_and_respawn() -> void:
	var w := _world()
	var dummy := w.add_dummy(Vector3(0.0, 0.0, -10.0))
	dummy.respawn_time = 0.05
	await w.settle()
	T.assert_near(dummy.health, 100.0, 0.0001, "starts at 100")
	T.assert_true(dummy.is_in_group("target_dummy"), "in dummy group")
	T.assert_true(not dummy.take_damage(DamageInfo.create(60.0, 1, dummy.id, 3)), "survives 60")
	T.assert_near(dummy.health, 40.0, 0.0001, "health after hit")
	T.assert_true(dummy.take_damage(DamageInfo.create(50.0, 1, dummy.id, 3)), "killed by second hit")
	T.assert_true(not dummy.alive, "dead")
	T.assert_eq(dummy.body_area.collision_layer, 0, "hitbox disabled while dead")
	T.assert_true(not dummy.take_damage(DamageInfo.create(50.0, 1, dummy.id, 3)), "dead dummy ignores damage")
	for i in 12:
		await T.physics_frame
	T.assert_true(dummy.alive, "respawned")
	T.assert_near(dummy.health, 100.0, 0.0001, "full health after respawn")
	T.assert_eq(dummy.body_area.collision_layer, 16, "hitbox on layer 5 again")
	var fresh := TargetDummy.new()
	T.assert_near(fresh.respawn_time, 2.0, 0.0001, "default respawn 2 s")
	fresh.free()
	w.dispose()


func test_dummy_hitboxes_follow_contract() -> void:
	var dummy := TargetDummy.new()
	T.root.add_child(dummy)
	T.assert_eq(dummy.body_area.collision_layer, 16, "body on hitbox layer")
	T.assert_eq(dummy.head_area.collision_layer, 16, "head on hitbox layer")
	T.assert_eq(String(dummy.head_area.get_meta("part")), "head", "head part meta")
	T.assert_eq(String(dummy.body_area.get_meta("part")), "body", "body part meta")
	T.assert_true(dummy.head_area.get_meta("fighter") == dummy, "owner meta")
	T.assert_true(dummy.id < 0, "dummy ids are negative")
	T.assert_near(dummy.get_center_position().y, 0.9, 0.0001, "center height")
	T.root.remove_child(dummy)
	dummy.free()


func test_dummy_unique_ids() -> void:
	var a := TargetDummy.new()
	var b := TargetDummy.new()
	T.assert_true(a.id != b.id, "unique ids")
	a.free()
	b.free()


# ---------------------------------------------------------------- damage routing

func test_deliver_damage_routing() -> void:
	var w := _world()
	var dummy := w.add_dummy(Vector3(0.0, 0.0, -10.0))
	await w.settle()
	var info := DamageInfo.create(25.0, 1, -1, 2)
	WeaponUtils.deliver_damage(T, dummy, info, Callable())
	T.assert_near(dummy.total_damage_taken, 25.0, 0.0001, "no manager: direct take_damage")
	T.assert_eq(info.victim_id, dummy.id, "victim id filled in")
	var seen: Array[int] = []
	var sink := func(victim_id: int, _i: DamageInfo) -> void: seen.append(victim_id)
	WeaponUtils.deliver_damage(T, dummy, DamageInfo.create(25.0, 1, -1, 2), sink)
	T.assert_eq(seen.size(), 1, "sink called")
	T.assert_near(dummy.total_damage_taken, 25.0, 0.0001, "sink replaces direct damage")
	var manager := FakeMatchManager.new()
	manager.add_to_group("match_manager")
	w.add_child(manager)
	WeaponUtils.deliver_damage(T, dummy, DamageInfo.create(10.0, 1, -1, 2), Callable())
	T.assert_eq(manager.calls.size(), 0, "dummies bypass MatchManager")
	T.assert_near(dummy.total_damage_taken, 35.0, 0.0001, "dummy still damaged directly")
	var fighter := WeaponTestWorld.Shooter.new()
	fighter.id = 9
	w.add_child(fighter)
	WeaponUtils.deliver_damage(T, fighter, DamageInfo.create(10.0, 1, -1, 2), Callable())
	T.assert_eq(manager.calls.size(), 1, "fighters route through MatchManager.auth_apply_damage")
	T.assert_eq(manager.calls[0].victim_id, 9, "fighter id")
	w.dispose()


# ---------------------------------------------------------------- splash

func test_rocket_splash_linear_falloff() -> void:
	var w := _world()
	w.capture()
	var dummy := w.add_dummy(Vector3(0.0, 0.0, -10.0))
	await w.settle()
	var def: WeaponDef = WeaponLibrary.get_def(WeaponLibrary.SLOT_ROCKET)
	var center: Vector3 = dummy.get_center_position()
	for dist: float in [0.0, 2.0, 4.4]:
		w.infos.clear()
		ProjectileRocket.explode(w, center + Vector3(dist, 0.0, 0.0), def, 1, null, w.inventory.damage_sink)
		T.assert_eq(w.infos.size(), 1, "one damage event per victim at %.1f m" % dist)
		var expected: float = 80.0 * lerpf(1.0, 0.15, dist / 4.5)
		T.assert_near(w.infos[0].amount, expected, 0.01, "splash at %.1f m" % dist)
		T.assert_true(w.infos[0].is_splash, "flagged splash")
	w.infos.clear()
	ProjectileRocket.explode(w, center + Vector3(4.6, 0.0, 0.0), def, 1, null, w.inventory.damage_sink)
	T.assert_eq(w.infos.size(), 0, "outside radius takes nothing")
	w.dispose()


func test_rocket_impulse_and_self_damage() -> void:
	var w := _world()
	w.capture()
	var dummy := w.add_dummy(Vector3(0.0, 0.0, -10.0))
	await w.settle()
	var def: WeaponDef = WeaponLibrary.get_def(WeaponLibrary.SLOT_ROCKET)
	var center: Vector3 = dummy.get_center_position()
	ProjectileRocket.explode(w, center, def, 1, null, w.inventory.damage_sink)
	T.assert_near(w.infos[0].impulse.length(), 16.0, 0.01, "16 m/s at the center")
	w.infos.clear()
	ProjectileRocket.explode(w, center + Vector3(0.0, -1.0, 0.0), def, 1, null, w.inventory.damage_sink)
	var info: DamageInfo = w.infos[0]
	T.assert_true(info.impulse.y > 0.0, "blast below pushes the victim up")
	T.assert_near(info.impulse.length(), 16.0 * lerpf(1.0, 0.15, 1.0 / 4.5), 0.01, "impulse scales with falloff")
	T.assert_near(info.impulse.normalized().dot(Vector3.UP), 1.0, 0.001, "impulse points away from the blast")
	w.infos.clear()
	ProjectileRocket.explode(w, center, def, dummy.id, null, w.inventory.damage_sink)
	T.assert_true(w.infos[0].is_self, "attacker == victim is self damage")
	T.assert_near(w.infos[0].amount, 80.0 * 0.35, 0.01, "self damage is 35 percent")
	w.dispose()


func test_splash_blocked_by_world_geometry() -> void:
	var w := _world()
	w.capture()
	var dummy := w.add_dummy(Vector3(0.0, 0.0, -10.0))
	w.add_wall(Vector3(0.0, 1.0, -9.0), Vector3(6.0, 4.0, 0.2))
	await w.settle()
	var def: WeaponDef = WeaponLibrary.get_def(WeaponLibrary.SLOT_ROCKET)
	var blast: Vector3 = dummy.get_center_position() + Vector3(0.0, 0.0, 2.0)
	ProjectileRocket.explode(w, blast, def, 1, null, w.inventory.damage_sink)
	T.assert_eq(w.infos.size(), 0, "wall blocks splash line of sight")
	w.dispose()


# ---------------------------------------------------------------- projectiles

func test_rocket_direct_hit_deals_85_once() -> void:
	var w := _world()
	w.capture()
	w.add_dummy(Vector3(0.0, 0.0, -10.0))
	await w.settle()
	var def: WeaponDef = WeaponLibrary.get_def(WeaponLibrary.SLOT_ROCKET)
	var bolt := ProjectileRocket.launch(w, def, w.shooter, 1, Vector3(0.0, 0.9, -1.0), Vector3.FORWARD, w.inventory.damage_sink, [] as Array[RID])
	T.assert_true(_run_projectile(bolt), "detonated")
	T.assert_eq(w.infos.size(), 1, "single event for the dummy")
	T.assert_near(w.infos[0].amount, 85.0, 0.01, "direct damage")
	T.assert_true(not w.infos[0].is_splash, "direct hit is not splash")
	T.assert_true(w.infos[0].impulse.length() > 10.0, "direct hit still knocks back")
	w.dispose()


func test_plasma_bolt_direct_damage_only() -> void:
	var w := _world()
	w.capture()
	w.add_dummy(Vector3(0.0, 0.0, -10.0))
	await w.settle()
	var def: WeaponDef = WeaponLibrary.get_def(WeaponLibrary.SLOT_PLASMA)
	var bolt := ProjectileRocket.launch(w, def, w.shooter, 1, Vector3(0.0, 0.9, -1.0), Vector3.FORWARD, w.inventory.damage_sink, [] as Array[RID])
	T.assert_near(bolt.velocity.length(), 55.0, 0.001, "plasma speed")
	T.assert_true(_run_projectile(bolt), "detonated")
	T.assert_eq(w.infos.size(), 1, "one hit")
	T.assert_near(w.infos[0].amount, 14.0, 0.001, "plasma damage")
	w.dispose()


func test_fast_projectile_does_not_tunnel_thin_wall() -> void:
	var w := _world()
	w.add_wall(Vector3(0.0, 2.0, -20.0), Vector3(20.0, 10.0, 0.2))
	await w.settle()
	var fast: WeaponDef = WeaponLibrary.get_def(WeaponLibrary.SLOT_ROCKET).duplicate() as WeaponDef
	fast.projectile_speed = 400.0 # 3.3 m per tick, far more than the 0.2 m wall
	var bolt := ProjectileRocket.launch(w, fast, w.shooter, 1, Vector3(0.0, 0.9, -1.0), Vector3.FORWARD, Callable(), [] as Array[RID])
	T.assert_true(_run_projectile(bolt), "detonated on the wall")
	T.assert_true(bolt.global_position.z > -19.95, "stopped on the near face (z=%.2f)" % bolt.global_position.z)
	w.dispose()


func test_projectile_expires_after_lifetime() -> void:
	var w := _world()
	await w.settle()
	var short: WeaponDef = WeaponLibrary.get_def(WeaponLibrary.SLOT_PLASMA).duplicate() as WeaponDef
	short.projectile_lifetime = 0.5
	var bolt := ProjectileRocket.launch(w, short, w.shooter, 1, Vector3(0.0, 0.9, -1.0), Vector3.FORWARD, Callable(), [] as Array[RID])
	T.assert_true(_run_projectile(bolt), "expired")
	T.assert_true(bolt.age >= 0.5 and bolt.age < 0.52, "expires at its lifetime")
	w.dispose()


func test_projectile_fires_from_weapon_and_aim_corrects() -> void:
	var w := _world()
	w.capture()
	w.add_dummy(Vector3(0.0, 0.0, -20.0))
	await w.settle()
	T.assert_true(w.fire(WeaponLibrary.SLOT_ROCKET), "rocket launches")
	var bolt: ProjectileRocket = null
	for child in w.get_children():
		if child is ProjectileRocket:
			bolt = child as ProjectileRocket
	T.assert_true(bolt != null, "projectile spawned in the world")
	T.assert_true(bolt.velocity.normalized().dot(Vector3.FORWARD) > 0.97, "heads toward the crosshair target")
	T.assert_true(_run_projectile(bolt), "detonated")
	T.assert_true(w.infos.size() >= 1 and absf(w.infos[0].amount - 85.0) < 0.01, "hits the dummy for 85")
	w.dispose()
