class_name MapSprawl
extends RefCounted

func build(parent: Node3D) -> Dictionary:
	var pal := MapPalette.sprawl()
	var b := MapBuilder.new(parent, pal)
	b.apply_environment()
	b.platform(Vector3(0, -0.5, 0), Vector3(120, 1, 60), pal.floor_mat())
	# Boulevards
	b.platform(Vector3(0, 0.05, -12), Vector3(110, 0.1, 8), pal.accent_mat())
	b.platform(Vector3(0, 0.05, 12), Vector3(110, 0.1, 8), pal.accent_mat())
	# Plaza
	b.platform(Vector3(0, 0.1, 0), Vector3(24, 0.2, 24))
	# Slide tunnels (downhill)
	for z in [-20.0, 0.0, 20.0]:
		b.box(Vector3(30, 1.1, z), Vector3(18, 2.2, 3), pal.wall_mat())
		# floor slope approx
		b.ramp(Vector3(30, 0.5, z), Vector3(18, 0.4, 3), Vector3(1, 0, 0))
	# Skywalks
	b.platform(Vector3(0, 8, 0), Vector3(80, 0.4, 3))
	b.platform(Vector3(0, 14, 8), Vector3(60, 0.4, 3))
	# Wall-run buildings
	b.box(Vector3(-40, 8, 0), Vector3(2, 16, 25), pal.wall_mat())
	b.box(Vector3(40, 8, 0), Vector3(2, 16, 25), pal.wall_mat())
	b.trim(Vector3(-40, 6, -12), Vector3(-40, 6, 12), 0.15, pal.trim)
	b.trim(Vector3(40, 6, -12), Vector3(40, 6, 12), 0.15, pal.trim)
	# Mantle crates alleys
	for i in 5:
		b.box(Vector3(-20 + i * 3.0, 0.5, -25), Vector3(1.2, 1.0 + i * 0.2, 1.2))
	# Rooftops
	b.platform(Vector3(-50, 10, -20), Vector3(12, 0.5, 10))
	b.platform(Vector3(50, 10, 20), Vector3(12, 0.5, 10))
	b.grapple_anchor(Vector3(-50, 14, -20))
	b.grapple_anchor(Vector3(50, 14, 20))
	b.jump_pad(Vector3(-45, 0.3, 0), Vector3(8, 16, 0))
	b.jump_pad(Vector3(45, 0.3, 0), Vector3(-8, 16, 0))
	b.label_sign(Vector3(0, 6, 0), "SPRAWL", pal.trim)
	for i in 16:
		var x := -50.0 + float(i) * 6.5
		b.spawn(Vector3(x, 1.0, 20.0 if i % 2 == 0 else -20.0), PI if i % 2 == 0 else 0.0)
	# 20+ pickups
	var types: Array[String] = ["stim", "medkit", "mega_health", "armor_shard", "armor", "ammo", "haste", "overcharge"]
	var weapons: Array[int] = [3, 4, 5, 6, 7]
	var idx := 0
	for x in range(-50, 51, 20):
		for z in [-22, 0, 22]:
			if idx < types.size():
				b.pickup(types[idx], Vector3(float(x), 1.5, float(z)))
			idx += 1
	for i in weapons.size():
		b.pickup("weapon", Vector3(-40.0 + float(i) * 20.0, 8.5, 0), weapons[i])
	b.pickup("stim", Vector3(10, 1.5, 10))
	b.pickup("stim", Vector3(-10, 1.5, -10))
	b.pickup("ammo", Vector3(25, 1.5, -15))
	b.pickup("ammo", Vector3(-25, 1.5, 15))
	b.pickup("armor_shard", Vector3(0, 14.5, 8))
	b.kill_volume(AABB(Vector3(-80, -25, -50), Vector3(160, 10, 100)))
	var data := b.result()
	data["name"] = "Sprawl"
	data["description"] = "Neon speed course with long straights and slide tunnels."
	# Surf skipped (FALLBACK)
	return data
