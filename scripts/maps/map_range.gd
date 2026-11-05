class_name MapRange
extends RefCounted

func build(parent: Node3D) -> Dictionary:
	var pal := MapPalette.practice()
	var b := MapBuilder.new(parent, pal)
	b.apply_environment()
	b.platform(Vector3(0, -0.5, 0), Vector3(80, 1, 50))
	# Gallery west
	b.box(Vector3(-25, 3, 0), Vector3(1, 6, 40), pal.wall_mat())
	for dist in [10.0, 20.0, 40.0]:
		_dummy(parent, Vector3(-25 + dist * 0.1, 1.0, -8), dist)
		_dummy(parent, Vector3(-25 + dist * 0.1, 1.0, 0), dist)
		_dummy(parent, Vector3(-25 + dist * 0.1, 1.0, 8), dist)
	# Bhop straightaway east
	b.platform(Vector3(20, 0.05, 0), Vector3(60, 0.1, 6), pal.accent_mat())
	# Speed gates
	for x in [5.0, 20.0, 35.0, 50.0]:
		b.trim(Vector3(x, 0.5, -2), Vector3(x, 2.5, -2), 0.1, pal.trim)
		b.trim(Vector3(x, 0.5, 2), Vector3(x, 2.5, 2), 0.1, pal.trim)
	# Slide tunnel
	b.box(Vector3(25, 1.1, 12), Vector3(18, 2.2, 3), pal.wall_mat())
	# Wall-run corridor
	b.box(Vector3(20, 3, -10), Vector3(30, 6, 0.5), pal.wall_mat())
	b.box(Vector3(20, 3, -14), Vector3(30, 6, 0.5), pal.wall_mat())
	# Mantle steps
	for i in 4:
		b.box(Vector3(-5 + float(i), 0.5 + float(i) * 0.35, 15), Vector3(1.2, 1.0 + float(i) * 0.2, 1.2))
	# Grapple pillars
	b.cylinder(Vector3(10, 4, 18), 0.6, 8.0)
	b.grapple_anchor(Vector3(10, 8, 18))
	b.cylinder(Vector3(25, 4, 18), 0.6, 8.0)
	b.grapple_anchor(Vector3(25, 8, 18))
	b.spawn(Vector3(0, 1, 0), 0.0)
	for i in 15:
		b.spawn(Vector3(-5 + float(i), 1, -5), 0.0)
	# Weapon rack
	for wid in range(1, 8):
		b.pickup("weapon", Vector3(-8 + float(wid), 1.5, 8), wid)
	b.pickup("ammo", Vector3(0, 1.5, 8))
	b.pickup("stim", Vector3(2, 1.5, 8))
	b.pickup("armor", Vector3(4, 1.5, 8))
	b.kill_volume(AABB(Vector3(-50, -20, -40), Vector3(100, 8, 80)))
	b.label_sign(Vector3(0, 5, -20), "PRACTICE RANGE", pal.trim)
	var data := b.result()
	data["name"] = "Practice Range"
	data["description"] = "Movement course and shooting gallery."
	return data

func _dummy(parent: Node3D, pos: Vector3, _dist: float) -> void:
	var script = load("res://scripts/match/target_dummy.gd")
	if script:
		var d = script.new()
		parent.add_child(d)
		d.global_position = pos
		return
	# Simple static capsule target
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.6
	mi.mesh = cap
	mi.position = pos + Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.3, 0.3)
	mi.material_override = mat
	parent.add_child(mi)
