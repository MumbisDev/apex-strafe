extends SceneTree
## Minimal headless test runner. Discovers test_*.gd, runs test_* methods.

const TEST_DIR := "res://tests"

var _passed: int = 0
var _failed: int = 0
var _current_name: String = ""
var _current_ok: bool = true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== APEX STRAFE TEST RUNNER ===")
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		push_error("Cannot open %s" % TEST_DIR)
		quit(1)
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("test_") and fname.ends_with(".gd") and fname != "test_runner.gd":
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for f in files:
		await _run_file(TEST_DIR.path_join(f))
	print("=== RESULTS: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _run_file(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null:
		print("FAIL %s — failed to load" % path)
		_failed += 1
		return
	var inst: Object = script.new()
	if inst == null:
		print("FAIL %s — failed to instantiate" % path)
		_failed += 1
		return
	if inst.has_method("setup"):
		await inst.call("setup", self)
	var method_names: Array[String] = []
	for m in inst.get_method_list():
		var name := str(m["name"])
		if name.begins_with("test_"):
			method_names.append(name)
	method_names.sort()
	for name in method_names:
		_current_name = "%s::%s" % [path.get_file(), name]
		_current_ok = true
		if inst.has_method("before_each"):
			inst.call("before_each")
		await inst.call(name)
		if _current_ok:
			print("PASS %s" % _current_name)
			_passed += 1
		else:
			_failed += 1
		if inst.has_method("after_each"):
			inst.call("after_each")
	if inst.has_method("teardown"):
		inst.call("teardown")
	if inst is Node:
		(inst as Node).queue_free()
		await process_frame

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		_fail(msg if msg != "" else "assert_true failed")

func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		_fail("%s (got %s expected %s)" % [msg, str(a), str(b)])

func assert_near(a: float, b: float, eps: float, msg: String = "") -> void:
	if absf(a - b) > eps:
		_fail("%s (got %s expected %s ±%s)" % [msg, str(a), str(b), str(eps)])

func _fail(msg: String) -> void:
	if not _current_ok:
		return
	_current_ok = false
	print("FAIL %s — %s" % [_current_name, msg])

func wait_physics(frames: int = 1) -> void:
	for i in frames:
		await physics_frame
