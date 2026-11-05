class_name BotItems
extends RefCounted
## Pickup desirability for the GrabItem goal: `need * value / (distance + 10)`.
## Reads live `GamePickup` nodes, or Dictionaries with keys
##   type (String), pos (Vector3), weapon_id (int), available (bool), respawn_in (float).

const WALK_SPEED := 8.0
const MAX_WAIT := 6.0 ## ignore pickups respawning later than this after we would arrive
const WAIT_PENALTY := 4.0 ## meters of virtual distance per second of waiting
const NORMALIZE := 4.0 ## raw score that maps to utility 1.0

## Snapshot of one pickup.
class Item extends RefCounted:
	var type: String = ""
	var pos: Vector3 = Vector3.ZERO
	var slot: int = 0 ## weapon slot for weapon pickups and backpacks
	var available: bool = true
	var respawn_in: float = 0.0

static func read(p: Variant) -> Item:
	var it := Item.new()
	if p is GamePickup:
		var g := p as GamePickup
		it.type = str(GamePickup.Kind.keys()[g.kind]).to_lower()
		it.pos = g.global_position
		it.slot = g.backpack_weapon if g.kind == GamePickup.Kind.BACKPACK else g.weapon_id
		it.available = g.available
		it.respawn_in = 0.0 if g.available else g.respawn_left
	elif p is Dictionary:
		var d := p as Dictionary
		it.type = str(d.get("type", "")).to_lower()
		it.pos = d.get("pos", Vector3.ZERO) as Vector3
		it.slot = int(d.get("weapon_id", 0))
		it.available = bool(d.get("available", true))
		it.respawn_in = float(d.get("respawn_in", 0.0))
	return it

static func is_health(type: String) -> bool:
	return type.contains("stim") or type.contains("medkit") or type.contains("mega")

## Returns Vector2(need 0..1, value) for a pickup type given the bot's state.
static func need_value(type: String, health: float, armor: float, weapon_owned: bool) -> Vector2:
	var missing_hp: float = maxf(0.0, 100.0 - health)
	var missing_armor: float = maxf(0.0, 100.0 - armor)
	if type.contains("overcharge"):
		return Vector2(1.0, 150.0)
	if type.contains("haste"):
		return Vector2(1.0, 120.0)
	if type.contains("mega"):
		return Vector2(0.4 + 0.6 * missing_hp / 100.0, 100.0)
	if type.contains("medkit"):
		return Vector2(clampf(missing_hp / 50.0, 0.0, 1.0), 55.0)
	if type.contains("stim"):
		return Vector2(clampf(missing_hp / 25.0, 0.0, 1.0), 30.0)
	if type.contains("plate") or type == "armor":
		return Vector2(clampf(missing_armor / 50.0, 0.0, 1.0), 45.0)
	if type.contains("shard"):
		return Vector2(clampf(missing_armor / 25.0, 0.0, 1.0), 25.0)
	if type.contains("ammo"):
		return Vector2(0.4, 30.0)
	if type.contains("weapon") or type.contains("backpack"):
		return Vector2(0.3 if weapon_owned else 1.0, 60.0)
	return Vector2.ZERO

## Utility roughly 0..1 (powerups can exceed Engage). Zero when not worth the trip.
static func utility(type: String, health: float, armor: float, weapon_owned: bool, dist: float, respawn_in: float) -> float:
	var nv: Vector2 = need_value(type, health, armor, weapon_owned)
	if nv.x <= 0.0:
		return 0.0
	var wait: float = maxf(0.0, respawn_in - dist / WALK_SPEED)
	if wait > MAX_WAIT:
		return 0.0
	return nv.x * nv.y / (dist + wait * WAIT_PENALTY + 10.0) / NORMALIZE
