class_name Debris
extends Node3D
## Cosmetic cube debris burst (12-16 RigidBody3D bits on physics layer 6, world-only collision).
## Bits live in a static pool parked under a persistent holder node, so steady state never allocates.

const LIFETIME: float = 4.0
const MIN_BITS: int = 12
const MAX_BITS: int = 16
const BIT_SIZE: float = 0.2

static var _pool: Array[RigidBody3D] = []
static var _holder: Node
static var _rng: RandomNumberGenerator = _make_rng()

var _bits: Array[RigidBody3D] = []
var _t: float = 0.0

static func _make_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 90210
	return r

static func _parking() -> Node:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "DebrisPool"
		_pool.clear()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_holder)
	return _holder

static func _take_bit() -> RigidBody3D:
	_parking()
	while not _pool.is_empty():
		var b: RigidBody3D = _pool.pop_back() as RigidBody3D
		if is_instance_valid(b):
			if b.get_parent() != null:
				b.get_parent().remove_child(b)
			return b
	var body := RigidBody3D.new()
	body.collision_layer = FxKit.LAYER_DEBRIS
	body.collision_mask = FxKit.LAYER_WORLD
	body.mass = 0.3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * BIT_SIZE
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * BIT_SIZE
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	return body

## Bursts debris at `pos` in `color`; `impulse` biases the throw (e.g. away from the killer).
func burst(pos: Vector3, color: Color, impulse: Vector3 = Vector3.ZERO) -> void:
	global_position = pos
	var count := _rng.randi_range(MIN_BITS, MAX_BITS)
	for i in count:
		var bit := _take_bit()
		var mat := (bit.get_child(1) as MeshInstance3D).material_override as StandardMaterial3D
		mat.albedo_color = color
		mat.emission = color * 0.6
		add_child(bit)
		bit.visible = true
		bit.global_position = pos + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.2, 1.6), _rng.randf_range(-0.3, 0.3))
		bit.freeze = false
		bit.linear_velocity = Vector3(_rng.randf_range(-4, 4), _rng.randf_range(2, 7), _rng.randf_range(-4, 4)) + impulse
		bit.angular_velocity = Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
		_bits.append(bit)
	_t = 0.0
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		_release()

func _release() -> void:
	set_process(false)
	for bit in _bits:
		if is_instance_valid(bit):
			bit.freeze = true
			bit.visible = false
			remove_child(bit)
			_parking().add_child(bit)
			_pool.append(bit)
	_bits.clear()
	queue_free()

func _exit_tree() -> void:
	## If the scene is torn down mid-burst our children die with us; forget them.
	_bits.clear()
