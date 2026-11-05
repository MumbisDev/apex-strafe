class_name BotWeapons
extends RefCounted
## Weapon slot constants, loadout queries, and distance-based weapon choice (GDD 10 "Combat").
## Reads the fighter's WeaponInventory; without one only the starter weapons count as owned.

const BLADE := 1
const PISTOL := 2
const SMG := 3
const SHOTGUN := 4
const PLASMA := 5
const ROCKET := 6
const RAIL := 7
const SLOTS: Array[int] = [1, 2, 3, 4, 5, 6, 7]

const ROCKET_MIN := 8.0
const ROCKET_MAX := 35.0
const ROCKET_HARD_MIN := 3.0

static func owns(f: Fighter, slot: int) -> bool:
	var inv := f.inventory as WeaponInventory
	if inv != null:
		return inv.has_weapon(slot)
	return slot == BLADE or slot == PISTOL

static func has_ammo(f: Fighter, slot: int) -> bool:
	var inv := f.inventory as WeaponInventory
	if inv != null:
		return inv.has_weapon(slot) and inv.weapons[slot - 1].has_ammo()
	return slot == BLADE or slot == PISTOL

static func current_slot(f: Fighter) -> int:
	var inv := f.inventory as WeaponInventory
	if inv != null:
		return inv.current_slot
	return PISTOL

static func available_slots(f: Fighter) -> Array[int]:
	var out: Array[int] = []
	for s in SLOTS:
		if has_ammo(f, s):
			out.append(s)
	return out

static func owned_count(f: Fighter) -> int:
	var n: int = 0
	for s in SLOTS:
		if owns(f, s):
			n += 1
	return n

## Preferred engagement distance per weapon.
static func preferred_distance(slot: int) -> float:
	match slot:
		BLADE: return 1.5
		SHOTGUN: return 7.0
		SMG: return 14.0
		PLASMA: return 18.0
		ROCKET: return 16.0
		RAIL: return 30.0
	return 14.0

## Maximum angular error (degrees) at which the bot is allowed to pull the trigger.
static func fire_threshold_deg(slot: int) -> float:
	match slot:
		RAIL: return 2.0
		SHOTGUN: return 12.0
	return 8.0

## Best slot for `dist` meters among `available` slots (those with ammo).
static func choose(dist: float, winning: bool, available: Array[int]) -> int:
	var order: Array[int] = _order_for(dist)
	for s in order:
		if available.has(s) and _in_range(s, dist, winning, true):
			return s
	for s in order:
		if available.has(s) and _in_range(s, dist, winning, false):
			return s
	for s in [SMG, PLASMA, SHOTGUN, PISTOL]:
		if available.has(s):
			return s
	if dist < 3.0 and available.has(BLADE):
		return BLADE
	return PISTOL

static func _order_for(dist: float) -> Array[int]:
	if dist < 14.0:
		return [SHOTGUN, SMG, ROCKET, PLASMA, PISTOL]
	if dist <= 30.0:
		return [RAIL, ROCKET, PLASMA, SMG, PISTOL]
	return [RAIL, PLASMA, ROCKET, PISTOL]

static func _in_range(slot: int, dist: float, winning: bool, strict: bool) -> bool:
	match slot:
		ROCKET:
			if dist < ROCKET_HARD_MIN and not winning:
				return false
			return dist >= ROCKET_MIN and dist <= ROCKET_MAX if strict else true
		RAIL:
			return dist > 15.0 if strict else true
		SHOTGUN:
			return dist < 14.0 if strict else true
		SMG:
			return dist >= 5.0 and dist <= 30.0 if strict else true
		PLASMA:
			return dist >= 8.0 and dist <= 40.0 if strict else true
	return true
