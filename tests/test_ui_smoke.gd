extends RefCounted

var T: SceneTree

func setup(runner: SceneTree) -> void:
	T = runner

func test_theme_builds() -> void:
	var theme := UITheme.build()
	T.assert_true(theme != null, "theme null")
	T.assert_true(theme.get_stylebox("normal", "Button") != null, "button style")

func test_match_config_presets() -> void:
	var q := MatchConfig.preset_quick()
	T.assert_eq(q.bot_count, 7, "quick bots")
	var mf := MatchConfig.preset_movement_frenzy()
	T.assert_eq(mf.map_id, "sprawl", "frenzy map")
	var ig := MatchConfig.preset_instagib()
	T.assert_true(ig.has_mutator(MatchConfig.Mutator.INSTAGIB), "instagib mutator")
