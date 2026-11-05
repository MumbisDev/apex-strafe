class_name PickupSpawner
extends Node
## Spawns GamePickups from map markers. Maps weapon_* types to slot ids and delivery modes.

const WEAPON_SLOTS: Dictionary = {
	"weapon_pistol": WeaponLibrary.SLOT_PISTOL,
	"weapon_smg": WeaponLibrary.SLOT_SMG,
	"weapon_shotgun": WeaponLibrary.SLOT_SHOTGUN,
	"weapon_plasma": WeaponLibrary.SLOT_PLASMA,
	"weapon_rocket": WeaponLibrary.SLOT_ROCKET,
	"weapon_railgun": WeaponLibrary.SLOT_RAIL,
	"weapon_portal": WeaponLibrary.SLOT_PORTAL,
	"weapon": 0,
}

var _next_id: int = 1
var pickups: Array[GamePickup] = []


func spawn_from_markers(parent: Node, markers: Array) -> void:
	for m in markers:
		var kind_str := str(m.get("type", "stim")).to_lower()
		var kind := _parse_kind(kind_str)
		var wid := int(m.get("weapon_id", 0))
		if kind == GamePickup.Kind.WEAPON and wid <= 0:
			wid = int(WEAPON_SLOTS.get(kind_str, 0))
		var delivery := _default_delivery(kind, wid)
		if m.has("delivery"):
			delivery = _parse_delivery(str(m["delivery"]))
		var p := GamePickup.new()
		# Configure before enter-tree so _ready builds the correct mesh/delivery.
		p.configure(kind, _next_id, m["pos"] as Vector3, wid, -1.0, delivery)
		parent.add_child(p)
		_next_id += 1
		pickups.append(p)
		Events.pickup_spawned.emit(p._kind_name(), p.global_position)


func spawn_backpack(parent: Node, pos: Vector3, weapon_id: int, ammo: int) -> void:
	var p := GamePickup.new()
	p.configure(GamePickup.Kind.BACKPACK, _next_id, pos, weapon_id)
	p.backpack_weapon = weapon_id
	p.backpack_ammo = ammo
	parent.add_child(p)
	_next_id += 1
	pickups.append(p)


func _parse_kind(s: String) -> GamePickup.Kind:
	if WEAPON_SLOTS.has(s):
		return GamePickup.Kind.WEAPON
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


func _default_delivery(kind: GamePickup.Kind, weapon_id: int) -> GamePickup.Delivery:
	match kind:
		GamePickup.Kind.WEAPON:
			return GamePickup.Delivery.CAGED if weapon_id == WeaponLibrary.SLOT_PORTAL \
				else GamePickup.Delivery.SKY_DROP
		GamePickup.Kind.MEGA_HEALTH, GamePickup.Kind.POWERUP_OVERCHARGE, GamePickup.Kind.POWERUP_HASTE:
			return GamePickup.Delivery.CAGED
		_:
			return GamePickup.Delivery.GROUND


func _parse_delivery(s: String) -> GamePickup.Delivery:
	match s.to_lower():
		"sky", "sky_drop", "drop": return GamePickup.Delivery.SKY_DROP
		"cage", "caged": return GamePickup.Delivery.CAGED
		_: return GamePickup.Delivery.GROUND
