class_name ViewmodelMeshes
extends RefCounted
## Builds first-person weapon silhouettes from 4–10 primitives (GDD §7).
## Viewmodel owns materials / no_depth_test; this only places readable geometry.

const PRIORITY_BASE: int = 20

var part_index: int = 0


func build(root: Node3D, def: WeaponDef) -> float:
	part_index = 0
	var body: Color = def.model_color
	var dark: Color = body.darkened(0.4)
	var mid: Color = body.lightened(0.12)
	var metal: Color = Color(0.55, 0.58, 0.62)
	var glow: Color = def.tracer_color
	match def.id:
		WeaponLibrary.SLOT_BLADE:
			return _blade(root, body, dark, mid, glow)
		WeaponLibrary.SLOT_PISTOL:
			return _pistol(root, body, dark, metal, glow)
		WeaponLibrary.SLOT_SMG:
			return _smg(root, body, dark, metal, glow)
		WeaponLibrary.SLOT_SHOTGUN:
			return _shotgun(root, body, dark, metal, glow)
		WeaponLibrary.SLOT_PLASMA:
			return _plasma(root, body, dark, metal, glow)
		WeaponLibrary.SLOT_ROCKET:
			return _rocket(root, body, dark, metal, glow)
		WeaponLibrary.SLOT_RAIL:
			return _rail(root, body, dark, metal, glow)
		WeaponLibrary.SLOT_PORTAL:
			return _portal(root, body, dark, metal, glow)
	return _fallback(root, body, dark, glow)


func _blade(root: Node3D, body: Color, dark: Color, mid: Color, glow: Color) -> float:
	## Vertical energy katana: pommel → grip → guard → blade tip along +Y.
	## Return value is tip height (viewmodel places muzzle on Y for melee).
	box(root, Vector3(0.034, 0.03, 0.034), Vector3(0.0, -0.08, 0.0), body) ## pommel
	box(root, Vector3(0.028, 0.16, 0.028), Vector3(0.0, 0.02, 0.0), dark) ## grip
	box(root, Vector3(0.14, 0.022, 0.028), Vector3(0.0, 0.12, 0.0), mid.lightened(0.2)) ## guard
	box(root, Vector3(0.022, 0.42, 0.075), Vector3(0.0, 0.35, 0.01), mid) ## blade
	box(root, Vector3(0.016, 0.10, 0.055), Vector3(0.0, 0.58, 0.01), mid) ## tip
	box(root, Vector3(0.004, 0.48, 0.004), Vector3(0.0, 0.36, 0.05), glow, true) ## edge glow
	return 0.64


func _pistol(root: Node3D, body: Color, dark: Color, metal: Color, glow: Color) -> float:
	## Compact sidearm: slide, frame, grip, barrel, trigger guard, optic rail.
	box(root, Vector3(0.048, 0.045, 0.22), Vector3(0.0, 0.045, -0.10), metal) ## slide
	box(root, Vector3(0.046, 0.04, 0.18), Vector3(0.0, 0.012, -0.06), body) ## frame
	box(root, Vector3(0.042, 0.13, 0.055), Vector3(0.0, -0.07, 0.04), dark) ## grip
	cyl(root, 0.012, 0.12, Vector3(0.0, 0.04, -0.26), dark) ## barrel
	box(root, Vector3(0.03, 0.025, 0.04), Vector3(0.0, -0.02, -0.05), dark) ## trigger guard
	box(root, Vector3(0.05, 0.006, 0.16), Vector3(0.0, 0.07, -0.10), glow, true) ## rail
	return -0.34


func _smg(root: Node3D, body: Color, dark: Color, metal: Color, glow: Color) -> float:
	## PDW: receiver, handguard, folding stock stub, mag, vertical grip, barrel, optic.
	box(root, Vector3(0.055, 0.07, 0.28), Vector3(0.0, 0.02, -0.08), body)
	box(root, Vector3(0.05, 0.055, 0.16), Vector3(0.0, 0.0, -0.28), dark) ## handguard
	box(root, Vector3(0.04, 0.05, 0.12), Vector3(0.0, 0.01, 0.16), dark) ## stock
	box(root, Vector3(0.035, 0.14, 0.05), Vector3(0.0, -0.10, -0.02), dark) ## mag
	box(root, Vector3(0.03, 0.08, 0.035), Vector3(0.0, -0.08, -0.18), metal) ## foregrip
	cyl(root, 0.012, 0.16, Vector3(0.0, 0.015, -0.42), metal)
	box(root, Vector3(0.058, 0.012, 0.2), Vector3(0.0, 0.06, -0.08), glow, true)
	return -0.52


func _shotgun(root: Node3D, body: Color, dark: Color, metal: Color, glow: Color) -> float:
	## Pump shotgun: receiver, pump, dual tubes, stock, heat shield.
	box(root, Vector3(0.06, 0.075, 0.22), Vector3(0.0, 0.02, -0.02), body)
	box(root, Vector3(0.055, 0.05, 0.14), Vector3(0.0, -0.01, -0.22), dark) ## pump
	cyl(root, 0.02, 0.5, Vector3(0.0, 0.04, -0.36), metal) ## barrel
	cyl(root, 0.014, 0.36, Vector3(0.0, -0.015, -0.30), dark) ## tube mag
	box(root, Vector3(0.05, 0.07, 0.22), Vector3(0.0, -0.01, 0.22), dark) ## stock
	box(root, Vector3(0.062, 0.01, 0.18), Vector3(0.0, 0.065, -0.02), glow, true)
	return -0.62


func _plasma(root: Node3D, body: Color, dark: Color, metal: Color, glow: Color) -> float:
	## Sci-fi rifle: core chamber, coil rings, emitter, grip, stock.
	box(root, Vector3(0.07, 0.08, 0.24), Vector3(0.0, 0.02, -0.02), body)
	cyl(root, 0.045, 0.1, Vector3(0.0, 0.03, -0.2), glow, true) ## chamber
	cyl(root, 0.038, 0.04, Vector3(0.0, 0.03, -0.32), metal) ## coil
	cyl(root, 0.038, 0.04, Vector3(0.0, 0.03, -0.40), metal)
	cyl(root, 0.02, 0.18, Vector3(0.0, 0.03, -0.52), glow, true) ## emitter
	box(root, Vector3(0.045, 0.11, 0.05), Vector3(0.0, -0.08, 0.05), dark)
	box(root, Vector3(0.05, 0.06, 0.14), Vector3(0.0, 0.0, 0.2), dark)
	return -0.62


func _rocket(root: Node3D, body: Color, dark: Color, metal: Color, glow: Color) -> float:
	## Tube launcher: main tube, muzzle ring, breech, grip, shoulder rest, optic rail.
	cyl(root, 0.055, 0.62, Vector3(0.0, 0.04, -0.18), body)
	cyl(root, 0.068, 0.04, Vector3(0.0, 0.04, -0.52), glow, true) ## muzzle
	cyl(root, 0.07, 0.08, Vector3(0.0, 0.04, 0.18), dark) ## breech
	box(root, Vector3(0.045, 0.1, 0.05), Vector3(0.0, -0.07, -0.02), dark)
	box(root, Vector3(0.08, 0.04, 0.12), Vector3(0.0, 0.0, 0.28), dark) ## pad
	box(root, Vector3(0.02, 0.04, 0.28), Vector3(0.0, 0.11, -0.15), glow, true)
	return -0.56


func _rail(root: Node3D, body: Color, dark: Color, metal: Color, glow: Color) -> float:
	## Precision rail: long barrel, side rails, receiver, stock, power cell.
	box(root, Vector3(0.05, 0.06, 0.28), Vector3(0.0, 0.02, -0.02), body)
	cyl(root, 0.014, 0.55, Vector3(0.0, 0.03, -0.4), metal)
	box(root, Vector3(0.012, 0.02, 0.5), Vector3(0.035, 0.03, -0.35), glow, true)
	box(root, Vector3(0.012, 0.02, 0.5), Vector3(-0.035, 0.03, -0.35), glow, true)
	box(root, Vector3(0.055, 0.08, 0.12), Vector3(0.0, -0.02, 0.18), dark) ## stock
	box(root, Vector3(0.04, 0.07, 0.08), Vector3(0.0, -0.06, -0.08), glow.darkened(0.2), true) ## cell
	box(root, Vector3(0.045, 0.09, 0.045), Vector3(0.0, -0.08, 0.02), dark) ## grip
	return -0.68


func _portal(root: Node3D, body: Color, dark: Color, metal: Color, glow: Color) -> float:
	## Dual-nozzle gadget: body, grip, dish, orange spout, blue spout.
	box(root, Vector3(0.08, 0.07, 0.22), Vector3(0.0, 0.02, -0.04), body)
	box(root, Vector3(0.045, 0.12, 0.05), Vector3(0.0, -0.08, 0.06), dark)
	cyl(root, 0.06, 0.03, Vector3(0.0, 0.05, -0.2), metal) ## dish
	cyl(root, 0.022, 0.12, Vector3(0.03, 0.03, -0.30), Color(1.0, 0.45, 0.1), true)
	cyl(root, 0.022, 0.12, Vector3(-0.03, 0.03, -0.30), glow, true)
	box(root, Vector3(0.07, 0.01, 0.14), Vector3(0.0, 0.07, -0.04), glow, true)
	return -0.38


func _fallback(root: Node3D, body: Color, dark: Color, glow: Color) -> float:
	box(root, Vector3(0.05, 0.06, 0.3), Vector3(0.0, 0.02, -0.05), body)
	cyl(root, 0.015, 0.25, Vector3(0.0, 0.02, -0.3), dark)
	box(root, Vector3(0.04, 0.1, 0.05), Vector3(0.0, -0.07, 0.05), dark)
	box(root, Vector3(0.052, 0.008, 0.2), Vector3(0.0, 0.055, -0.05), glow, true)
	return -0.45


func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(parent, mesh, pos, Vector3.ZERO, color, glow)


func cyl(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, glow: bool = false) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 14
	_add(parent, mesh, pos, Vector3(deg_to_rad(90.0), 0.0, 0.0), color, glow)


func wedge(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: bool = false) -> void:
	var mesh := PrismMesh.new()
	mesh.size = size
	_add(parent, mesh, pos, Vector3(0.0, 0.0, deg_to_rad(90.0)), color, glow)


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, color: Color, glow: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.material_override = _mat(color, glow, PRIORITY_BASE + part_index)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part_index += 1
	parent.add_child(instance)


func _mat(color: Color, glow: bool, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.no_depth_test = true
	mat.render_priority = clampi(priority, -128, 127)
	mat.roughness = 0.45 if glow else 0.65
	mat.metallic = 0.35 if not glow else 0.1
	if glow:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = 2.8
	return mat
