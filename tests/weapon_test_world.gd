class_name WeaponTestWorld
extends Node3D
## Shared fixture for test_weapons.gd and test_damage.gd (not a test file: no test_ prefix).
## Provides a shooter at the origin, a WeaponInventory aimed along -Z, optional damage capture,
## and helpers to add dummies and walls. Await settle() after adding physics objects.

class Shooter extends CharacterBody3D:
	var id: int = 1

const TICK: float = 1.0 / 120.0

var shooter: Shooter
var inventory: WeaponInventory
var infos: Array[DamageInfo] = []
var dummies: Array[TargetDummy] = []
var aim_pos: Vector3 = Vector3(0.0, 0.9, 0.0) ## Chest height: hits bodies. Use y=1.62 for heads.
var aim_dir: Vector3 = Vector3.FORWARD


static func create(tree: SceneTree) -> WeaponTestWorld:
	var world := WeaponTestWorld.new()
	tree.root.add_child(world)
	world.shooter = Shooter.new()
	world.add_child(world.shooter)
	world.inventory = WeaponInventory.new()
	world.shooter.add_child(world.inventory)
	world.inventory.owner_id = world.shooter.id
	world.inventory.shooter = world.shooter
	world.inventory.aim_provider = world.get_aim
	world.inventory.rng.seed = 7
	return world


func get_aim() -> Transform3D:
	return Transform3D(Basis.looking_at(aim_dir, Vector3.UP), aim_pos)


func capture() -> void:
	inventory.damage_sink = _record


func _record(_victim_id: int, info: DamageInfo) -> void:
	infos.append(info)


func add_dummy(pos: Vector3) -> TargetDummy:
	var dummy := TargetDummy.new()
	dummy.position = pos
	add_child(dummy)
	dummies.append(dummy)
	return dummy


func add_wall(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child(body)
	return body


## Waits until newly added physics objects are visible to ray and shape queries.
func settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


## Fires one weapon slot immediately (cooldown cleared) at the current aim.
func fire(slot: int) -> bool:
	var weapon: WeaponBase = inventory.weapons[slot - 1]
	weapon.cooldown = 0.0
	var aim: Transform3D = get_aim()
	return weapon.try_fire(aim, inventory.get_muzzle_position(aim))


func total_damage() -> float:
	var sum: float = 0.0
	for info in infos:
		sum += info.amount
	return sum


func dispose() -> void:
	queue_free()
