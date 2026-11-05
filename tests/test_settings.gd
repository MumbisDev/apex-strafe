extends RefCounted

var T: SceneTree

func setup(runner: SceneTree) -> void:
	T = runner

func test_settings_defaults_sane() -> void:
	T.assert_true(Settings.mouse_sensitivity > 0.0, "sensitivity")
	T.assert_true(Settings.fov >= 80.0 and Settings.fov <= 130.0, "fov range")
	T.assert_true(Settings.auto_bhop, "auto_bhop default on")

func test_settings_roundtrip() -> void:
	var old := Settings.mouse_sensitivity
	Settings.mouse_sensitivity = 2.5
	Settings.save_settings()
	Settings.mouse_sensitivity = 1.0
	Settings.load_settings()
	T.assert_near(Settings.mouse_sensitivity, 2.5, 0.001, "roundtrip sensitivity")
	Settings.mouse_sensitivity = old
	Settings.save_settings()

func test_input_actions_exist() -> void:
	for a in ["move_forward", "jump", "fire", "grapple", "pause", "weapon_1"]:
		T.assert_true(InputMap.has_action(a), "missing action %s" % a)
