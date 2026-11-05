class_name PickupSpawner
extends Node

var _next_id: int = 1
var pickups: Array[GamePickup] = []

func spawn_from_markers(parent: Node, markers: Array) -> void:
	for m in markers:
		var kind_str := str(m.get("type", "stim")).to_lower()
		var kind := _parse_kind(kind_str)
		var p := GamePickup.new()
		parent.add_child(p)
		var wid := int(m.get("weapon_id", 0))
		p.configure(kind, _next_id, m["pos"] as Vector3, wid)
		_next_id += 1
		pickups.append(p)
		Events.pickup_spawned.emit(p._kind_name(), p.global_position)

func spawn_backpack(parent: Node, pos: Vector3, weapon_id: int, ammo: int) -> void:
	var p := GamePickup.new()
	parent.add_child(p)
	p.configure(GamePickup.Kind.BACKPACK, _next_id, pos, weapon_id)
	p.backpack_weapon = weapon_id
	p.backpack_ammo = ammo
	_next_id += 1
	pickups.append(p)

func _parse_kind(s: String) -> GamePickup.Kind:
	match s:
		"stim": return GamePickup.Kind.STIM
		"medkit": return GamePickup.Kind.MEDKIT
		"mega_health", "mega": return GamePickup.Kind.MEGA_HEALTH
		"armor_shard", "shard": return GamePickup.Kind.ARMOR_SHARD
		"armor_plate", "armor": return GamePickup.Kind.ARMOR_PLATE
		"ammo", "ammo_box": return GamePickup.Kind.AMMO_BOX
		"weapon": return GamePickup.Kind.WEAPON
		"overcharge": return GamePickup.Kind.POWERUP_OVERCHARGE
		"haste": return GamePickup.Kind.POWERUP_HASTE
	return GamePickup.Kind.STIM
