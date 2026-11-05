class_name PortalSystem
extends Node
## Owns per-fighter portal pairs. Place via portal gun primary (A) / alt (B).

const GROUP: StringName = &"portal_system"
const GATE_SCRIPT: String = "res://scripts/weapons/portal_gate.gd"

var _pairs: Dictionary = {} ## owner_id -> Array[Node] size 2


func _ready() -> void:
	add_to_group(GROUP)


func clear_owner(owner_id: int) -> void:
	if not _pairs.has(owner_id):
		return
	var arr: Array = _pairs[owner_id] as Array
	for g in arr:
		if g != null and is_instance_valid(g):
			(g as Node).queue_free()
	_pairs.erase(owner_id)


func place(owner_id: int, index: int, pos: Vector3, normal: Vector3) -> void:
	index = clampi(index, 0, 1)
	if not _pairs.has(owner_id):
		_pairs[owner_id] = [null, null]
	var arr: Array = _pairs[owner_id] as Array
	var old: Variant = arr[index]
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	var script: GDScript = load(GATE_SCRIPT) as GDScript
	var gate: Node = script.new() as Node
	get_parent().add_child(gate)
	gate.call("configure", owner_id, index, pos, normal)
	arr[index] = gate
	var other: Variant = arr[1 - index]
	if other != null and is_instance_valid(other):
		gate.set("link", other)
		(other as Node).set("link", gate)
	else:
		gate.set("link", null)
