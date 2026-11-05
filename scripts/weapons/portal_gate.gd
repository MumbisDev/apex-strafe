class_name PortalGate
extends Area3D
## One portal mouth. Linked pair teleports fighters with velocity remapped to the exit normal.

const COOLDOWN: float = 0.45
const EXIT_PUSH: float = 1.4
const SIZE: Vector3 = Vector3(1.6, 2.4, 0.25)

var owner_id: int = -1
var index: int = 0 ## 0 orange / primary, 1 blue / alt
var link: PortalGate = null
var portal_normal: Vector3 = Vector3.FORWARD

var _cd: Dictionary = {} ## fighter id -> time left
var _mesh: MeshInstance3D


func configure(p_owner: int, p_index: int, pos: Vector3, normal: Vector3) -> void:
	owner_id = p_owner
	index = p_index
	portal_normal = normal.normalized()
	collision_layer = 0
	collision_mask = 2 ## fighters
	monitoring = true
	monitorable = false
	global_position = pos + portal_normal * 0.15
	if absf(portal_normal.dot(Vector3.UP)) > 0.95:
		look_at(global_position + Vector3.FORWARD, portal_normal)
	else:
		look_at(global_position + portal_normal, Vector3.UP)
	body_entered.connect(_on_body)
	_build_visual()


func _physics_process(dt: float) -> void:
	var dead: Array[int] = []
	for id: int in _cd:
		_cd[id] = float(_cd[id]) - dt
		if float(_cd[id]) <= 0.0:
			dead.append(id)
	for id in dead:
		_cd.erase(id)


func _on_body(body: Node) -> void:
	if link == null or not is_instance_valid(link):
		return
	if body is not CharacterBody3D:
		return
	var f := body as CharacterBody3D
	var fid := int(f.get("id")) if f.get("id") != null else -1
	if fid >= 0 and float(_cd.get(fid, 0.0)) > 0.0:
		return
	var exit_n := link.portal_normal
	var exit_pos := link.global_position + exit_n * EXIT_PUSH
	var speed := f.velocity.length()
	f.global_position = exit_pos
	f.velocity = exit_n * maxf(speed, 6.0)
	if fid >= 0:
		_cd[fid] = COOLDOWN
		link._cd[fid] = COOLDOWN
	Audio.play_sfx("pickup_respawn", exit_pos)


func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	col.shape = box
	add_child(col)
	_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	var c := Color(1.0, 0.45, 0.1) if index == 0 else Color(0.2, 0.55, 1.0)
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.75
	_mesh.material_override = mat
	add_child(_mesh)
