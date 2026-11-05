extends RefCounted
## Movement acceptance tests (GDD M1). Uses a lightweight fake body when possible.

var T: SceneTree
var cfg: MovementConfig

func setup(runner: SceneTree) -> void:
	T = runner
	cfg = MovementConfig.make_default()

func test_accelerate_helper() -> void:
	var mc := MovementController.new(cfg)
	var v := Vector3.ZERO
	v = mc.accelerate(v, Vector3.FORWARD, 9.0, 12.0, 1.0 / 120.0)
	T.assert_true(v.length() > 0.0, "accel should add speed")
	T.assert_true(v.length() <= 9.0 + 0.01, "should not exceed wish in one tick much")

func test_config_defaults() -> void:
	T.assert_near(cfg.gravity, 24.0, 0.001)
	T.assert_near(cfg.ground_speed, 9.0, 0.001)
	T.assert_near(cfg.jump_velocity, 8.6, 0.001)
	T.assert_near(cfg.max_speed_hard_cap, 35.0, 0.001)
	T.assert_near(cfg.air_wish_cap, 1.0, 0.001)

func test_jump_height_formula() -> void:
	# v^2 / 2g
	var h := (cfg.jump_velocity * cfg.jump_velocity) / (2.0 * cfg.gravity)
	T.assert_near(h, 1.54, 0.15, "approx jump height")

func test_slide_boost_math() -> void:
	var spd := 9.0
	var boosted := minf(spd * cfg.slide_boost, cfg.slide_boost_cap)
	T.assert_near(boosted, 10.35, 0.01)

func test_input_frame_reuse() -> void:
	var f := InputFrame.new()
	f.move = Vector2(1, 0)
	f.clear()
	T.assert_eq(f.move, Vector2.ZERO)
	var f2 := InputFrame.new()
	f2.jump_held = true
	f.copy_from(f2)
	T.assert_true(f.jump_held)

func test_replay_input_plays_frames() -> void:
	var r := ReplayInput.new()
	var a := InputFrame.new()
	a.move = Vector2(0, 1)
	var b := InputFrame.new()
	b.jump_pressed = true
	r.frames = [a, b]
	var f1 := r.sample(1.0 / 120.0, null)
	T.assert_eq(f1.move, Vector2(0, 1))
	var f2 := r.sample(1.0 / 120.0, null)
	T.assert_true(f2.jump_pressed)
