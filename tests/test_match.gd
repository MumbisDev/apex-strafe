extends RefCounted
## M3/M6 match core smoke tests.

var T: SceneTree

func setup(runner: SceneTree) -> void:
	T = runner

func test_armor_absorption_examples() -> void:
	var h := HealthComponent.new()
	h.armor = 50.0
	h.health = 100.0
	var info := DamageInfo.create(100.0, 1, 2, 2)
	var dealt := h.apply_damage(info)
	T.assert_near(h.armor, 0.0, 0.01, "50 armor depleted")
	T.assert_near(h.health, 50.0, 0.01, "50 health remains after 100 dmg with 50 armor")
	T.assert_near(dealt, 50.0, 0.01, "health damage 50")
	h.reset()
	h.armor = 100.0
	h.health = 100.0
	info = DamageInfo.create(100.0, 1, 2, 2)
	dealt = h.apply_damage(info)
	T.assert_near(h.armor, 34.0, 0.01, "100*0.66=66 absorbed → armor 34")
	T.assert_near(h.health, 66.0, 0.01, "34 health damage → 66 left")

func test_scoring_kill_and_suicide() -> void:
	var mm := MatchManager.new()
	T.root.add_child(mm)
	mm.config = MatchConfig.new()
	mm.scores[1] = 0
	mm.scores[2] = 0
	var f1 := Fighter.new()
	f1.id = 1
	f1.display_name = "A"
	var f2 := Fighter.new()
	f2.id = 2
	f2.display_name = "B"
	# Skip full tree; scoring only needs dict + optional fighters
	mm.fighters[1] = f1
	mm.fighters[2] = f2
	mm.scoring.apply_kill(mm, 1, 2)
	T.assert_eq(int(mm.scores[1]), 1, "kill +1")
	mm.scoring.apply_suicide(mm, 1)
	T.assert_eq(int(mm.scores[1]), 0, "suicide -1")
	mm.queue_free()
	await T.process_frame

func test_match_config_mutator_exclusion() -> void:
	var c := MatchConfig.preset_instagib()
	T.assert_true(c.has_mutator(MatchConfig.Mutator.INSTAGIB))
	T.assert_true(not c.has_mutator(MatchConfig.Mutator.ROCKETS_ONLY))

func test_event_log_hash_deterministic() -> void:
	var mm := MatchManager.new()
	mm._log("a")
	mm._log("b")
	var h1 := mm.event_log_hash()
	var mm2 := MatchManager.new()
	mm2._log("a")
	mm2._log("b")
	T.assert_eq(h1, mm2.event_log_hash(), "same logs same hash")
