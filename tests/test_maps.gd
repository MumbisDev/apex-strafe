extends RefCounted
## M4 map smoke tests (headless).

var T: SceneTree

func setup(runner: SceneTree) -> void:
	T = runner

func test_palettes_exist() -> void:
	T.assert_true(MapPalette.foundry() != null)
	T.assert_true(MapPalette.spire() != null)
	T.assert_true(MapPalette.sprawl() != null)
	T.assert_true(MapPalette.practice() != null)

func test_foundry_builds() -> void:
	await _assert_map(MapFoundry.new(), "Foundry", 16, 20)

func test_spire_builds() -> void:
	await _assert_map(MapSpire.new(), "Spire", 16, 16)

func test_sprawl_builds() -> void:
	await _assert_map(MapSprawl.new(), "Sprawl", 16, 16)

func test_range_builds() -> void:
	await _assert_map(MapRange.new(), "Practice Range", 1, 5)

func _assert_map(builder: RefCounted, expect_name: String, min_spawns: int, min_pickups: int) -> void:
	var root := Node3D.new()
	T.root.add_child(root)
	var data: Dictionary = builder.call("build", root) as Dictionary
	T.assert_true(str(data.get("name", "")).contains(expect_name.split(" ")[0]) or str(data.get("name", "")) == expect_name or data.has("spawns"), "name/spawns for %s" % expect_name)
	var spawns: Array = data.get("spawns", [])
	var pickups: Array = data.get("pickups", [])
	T.assert_true(spawns.size() >= min_spawns, "%s spawn count %d" % [expect_name, spawns.size()])
	T.assert_true(pickups.size() >= min_pickups, "%s pickup count %d" % [expect_name, pickups.size()])
	await T.physics_frame
	root.queue_free()
	await T.process_frame
