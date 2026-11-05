class_name FighterVisual
extends Node3D

var _meshes: Array[MeshInstance3D] = []
var _primary: Color = Color.WHITE
var _trail: GPUParticles3D
var _hidden_fp: bool = false

func build(color: Color) -> void:
	_primary = color
	_clear()
	_add_mesh(_capsule(0.35, 0.9), Vector3(0, 1.0, 0), color) ## torso
	_add_mesh(_sphere(0.28), Vector3(0, 1.55, 0), color.lightened(0.1)) ## head
	var visor := _add_mesh(_box(Vector3(0.35, 0.08, 0.12)), Vector3(0, 1.58, -0.22), Color(0.05, 0.05, 0.08))
	_add_mesh(_box(Vector3(0.18, 0.55, 0.18)), Vector3(-0.28, 0.45, 0), color.darkened(0.1))
	_add_mesh(_box(Vector3(0.18, 0.55, 0.18)), Vector3(0.28, 0.45, 0), color.darkened(0.1))
	_add_mesh(_box(Vector3(0.16, 0.5, 0.16)), Vector3(-0.22, 1.15, 0), color)
	_add_mesh(_box(Vector3(0.16, 0.5, 0.16)), Vector3(0.22, 1.15, 0), color)
	_add_mesh(_box(Vector3(0.35, 0.4, 0.2)), Vector3(0, 1.1, 0.28), color.darkened(0.2)) ## backpack
	_trail = GPUParticles3D.new()
	_trail.emitting = false
	_trail.amount = 16
	_trail.lifetime = 0.25
	add_child(_trail)
	var _v := visor

func set_first_person_hidden(hidden: bool) -> void:
	_hidden_fp = hidden
	visible = not hidden

func flash_hit() -> void:
	for m in _meshes:
		var mat := m.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission = Color.WHITE
			mat.emission_energy_multiplier = 2.0
	var tw := get_tree().create_timer(0.06)
	tw.timeout.connect(func() -> void:
		for m2 in _meshes:
			var mat2 := m2.get_active_material(0) as StandardMaterial3D
			if mat2:
				mat2.emission_energy_multiplier = 0.2
				mat2.emission = _primary
	)

func tick(speed: float, crouching: bool, sliding: bool, airborne: bool) -> void:
	scale.y = 0.75 if crouching or sliding else 1.0
	rotation.x = deg_to_rad(-20.0) if sliding else (deg_to_rad(10.0) if airborne else 0.0)
	if _trail:
		_trail.emitting = speed > 18.0 and not _hidden_fp

func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_meshes.clear()

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.15
	mi.material_override = mat
	add_child(mi)
	_meshes.append(mi)
	return mi

func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m

func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m

func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
