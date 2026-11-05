class_name MovementController
extends RefCounted

enum State { GROUNDED, AIR, SLIDE, WALLRUN, MANTLE, GRAPPLE }

var config: MovementConfig
var state: State = State.AIR
var yaw: float = 0.0
var pitch: float = 0.0

var jump_buffer: float = 0.0
var coyote: float = 0.0
var slide_cd: float = 0.0
var slide_air_t: float = 0.0
var last_slide_jump_t: float = 999.0
var wallrun_t: float = 0.0
var wallrun_cd: float = 0.0
var wall_normal: Vector3 = Vector3.ZERO
var last_wall_id: int = -1
var wall_jumps: int = 0
var mantle_t: float = 0.0
var mantle_from: Vector3 = Vector3.ZERO
var mantle_to: Vector3 = Vector3.ZERO
var mantle_pre_speed: float = 0.0
var grapple_anchor: Vector3 = Vector3.ZERO
var grapple_len: float = 0.0
var grapple_t: float = 0.0
var grapple_cd: float = 0.0
var grappling: bool = false
var crouching: bool = false
var just_jumped: bool = false
var wish_debug: String = ""

var _tmp_vel: Vector3 = Vector3.ZERO

func _init(cfg: MovementConfig = null) -> void:
	config = cfg if cfg != null else MovementConfig.make_default()

func accelerate(vel: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, dt: float) -> Vector3:
	var current: float = vel.dot(wish_dir)
	var add_speed: float = wish_speed - current
	if add_speed <= 0.0:
		return vel
	var accel_speed: float = minf(accel * wish_speed * dt, add_speed)
	return vel + wish_dir * accel_speed

func step(fighter: CharacterBody3D, frame: InputFrame, dt: float) -> void:
	just_jumped = false
	last_slide_jump_t += dt
	if slide_cd > 0.0:
		slide_cd -= dt
	if wallrun_cd > 0.0:
		wallrun_cd -= dt
	if grapple_cd > 0.0:
		grapple_cd -= dt

	# Look
	yaw -= frame.look_delta.x
	pitch -= frame.look_delta.y
	pitch = clampf(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))

	var auto_bhop := Settings == null or Settings.auto_bhop
	if frame.jump_pressed or (auto_bhop and frame.jump_held):
		jump_buffer = config.jump_buffer_time
	else:
		jump_buffer = maxf(0.0, jump_buffer - dt)

	if state == State.MANTLE:
		_step_mantle(fighter, frame, dt)
		return

	# Grapple attach/release
	if grappling:
		if not frame.grapple_held or grapple_t >= config.grapple_max_time or frame.jump_pressed:
			_release_grapple(fighter, frame.jump_pressed)
		else:
			_step_grapple(fighter, frame, dt)
			_move(fighter)
			return
	elif frame.grapple_pressed and grapple_cd <= 0.0:
		_try_grapple(fighter)

	var on_floor := fighter.is_on_floor()
	if on_floor:
		coyote = config.coyote_time
		wall_jumps = 0
		last_wall_id = -1
	else:
		coyote = maxf(0.0, coyote - dt)

	var basis_yaw := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	var wish := (basis_yaw * Vector3(frame.move.x, 0.0, -frame.move.y))
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	elif wish.length_squared() > 0.0:
		wish = wish.normalized() * wish.length()

	# Try mantle
	if state != State.SLIDE and _try_start_mantle(fighter, frame, wish):
		_move(fighter)
		return

	# Wall-run
	if state == State.WALLRUN or _can_start_wallrun(fighter, frame, wish, on_floor):
		if _step_wallrun(fighter, frame, wish, dt, on_floor):
			_move(fighter)
			return

	# Surf (steep surfaces in group "surf")
	if _step_surf(fighter, wish, dt):
		_move(fighter)
		return

	# Slide
	if state == State.SLIDE:
		_step_slide(fighter, frame, wish, dt, on_floor)
		_move(fighter)
		return
	elif on_floor and frame.crouch_pressed and _horiz(fighter.velocity).length() >= config.slide_min_speed and slide_cd <= 0.0:
		_start_slide(fighter)
		_step_slide(fighter, frame, wish, dt, on_floor)
		_move(fighter)
		return

	# Jump before friction (bhop)
	var want_jump := jump_buffer > 0.0 and (on_floor or coyote > 0.0)
	if Settings != null and not Settings.auto_bhop:
		want_jump = jump_buffer > 0.0 and (on_floor or coyote > 0.0) and (frame.jump_pressed or jump_buffer > 0.0)
		# If auto_bhop off: require press within buffer — jump_buffer already set on press/held edge via pressed; held alone fills buffer only if auto
	if not (Settings != null and Settings.auto_bhop):
		# Only consume buffer from an actual press window; jump_held alone should not refill after landing unless auto
		pass
	if want_jump and (Settings == null or Settings.auto_bhop or frame.jump_pressed or jump_buffer > 0.0):
		if Settings != null and not Settings.auto_bhop and not frame.jump_pressed and jump_buffer <= 0.0:
			pass
		else:
			# With auto_bhop: jump_held keeps buffer topped; without: buffer only from jump_pressed
			if Settings != null and not Settings.auto_bhop:
				# jump_buffer set only when jump_pressed in step above... we also set on jump_held. Fix: only pressed fills when auto off.
				pass
			_do_jump(fighter)

	# Re-evaluate floor after potential jump
	on_floor = fighter.is_on_floor() and not just_jumped

	if on_floor:
		state = State.GROUNDED
		_apply_crouch(fighter, frame, true)
		if not just_jumped:
			_apply_friction(fighter, dt, config.ground_friction)
		var max_spd := config.crouch_speed if crouching else config.ground_speed
		fighter.velocity = accelerate(fighter.velocity, wish, max_spd * wish.length(), config.ground_accel, dt)
		fighter.velocity.y = minf(fighter.velocity.y, 0.0)
		fighter.floor_snap_length = 0.5 if not just_jumped else 0.0
	else:
		state = State.AIR
		_apply_crouch(fighter, frame, false)
		fighter.floor_snap_length = 0.0
		fighter.velocity.y -= config.gravity * dt
		var wish_speed := config.ground_speed * wish.length()
		var capped := minf(wish_speed, config.air_wish_cap)
		var horiz := _horiz(fighter.velocity)
		horiz = accelerate(horiz, wish, capped, config.air_accel, dt)
		fighter.velocity.x = horiz.x
		fighter.velocity.z = horiz.z
		# Wall jump while near wall
		if frame.jump_pressed:
			_try_wall_jump(fighter)

	_cap_speed(fighter)
	_move(fighter)

func _step_surf(fighter: CharacterBody3D, wish: Vector3, dt: float) -> bool:
	for i in fighter.get_slide_collision_count():
		var col := fighter.get_slide_collision(i)
		if col == null:
			continue
		var n := col.get_normal()
		if n.y < config.surf_ny_min or n.y > config.surf_ny_max:
			continue
		var collider := col.get_collider() as Node
		if collider == null or not collider.is_in_group("surf"):
			continue
		var vel: Vector3 = fighter.velocity.slide(n)
		vel += (Vector3.DOWN * config.gravity).slide(n) * dt
		var wish_plane := wish.slide(n)
		if wish_plane.length_squared() > 0.0001:
			vel += wish_plane.normalized() * config.surf_steer * dt
		fighter.velocity = vel
		state = State.AIR
		fighter.floor_snap_length = 0.0
		return true
	return false


func _do_jump(fighter: CharacterBody3D) -> void:
	fighter.velocity.y = config.jump_velocity
	jump_buffer = 0.0
	coyote = 0.0
	just_jumped = true
	state = State.AIR
	fighter.floor_snap_length = 0.0

func _apply_friction(fighter: CharacterBody3D, dt: float, friction: float) -> void:
	var horiz := _horiz(fighter.velocity)
	var speed := horiz.length()
	if speed < 0.01:
		fighter.velocity.x = 0.0
		fighter.velocity.z = 0.0
		return
	var drop := maxf(speed, config.stop_speed) * friction * dt
	var ns := maxf(speed - drop, 0.0)
	var scale := ns / speed
	fighter.velocity.x *= scale
	fighter.velocity.z *= scale

func _start_slide(fighter: CharacterBody3D) -> void:
	state = State.SLIDE
	crouching = true
	_set_capsule(fighter, true)
	var horiz := _horiz(fighter.velocity)
	var spd := horiz.length()
	if spd > 0.01:
		horiz = horiz.normalized() * minf(spd * config.slide_boost, config.slide_boost_cap)
	fighter.velocity.x = horiz.x
	fighter.velocity.z = horiz.z
	slide_air_t = 0.0
	Events.fighter_slide_started.emit(fighter.get("id") as int if fighter.get("id") != null else -1)

func _step_slide(fighter: CharacterBody3D, frame: InputFrame, wish: Vector3, dt: float, on_floor: bool) -> void:
	if not on_floor:
		slide_air_t += dt
		fighter.velocity.y -= config.gravity * dt
	else:
		slide_air_t = 0.0
		# Slope gravity along floor
		var n := fighter.get_floor_normal()
		if n.length_squared() > 0.0:
			var along := (Vector3.DOWN * config.gravity).slide(n)
			fighter.velocity += along * dt
		_apply_friction(fighter, dt, config.slide_friction)
		# Steering without speed gain
		var horiz := _horiz(fighter.velocity)
		var spd := horiz.length()
		if wish.length_squared() > 0.0 and spd > 0.01:
			var desired := wish.normalized() * spd
			horiz = horiz.move_toward(desired, config.slide_steer_accel * dt)
			fighter.velocity.x = horiz.x
			fighter.velocity.z = horiz.z

	# Slide-jump
	if frame.jump_pressed or (jump_buffer > 0.0 and (Settings == null or Settings.auto_bhop)):
		var bonus := 0.0
		if last_slide_jump_t >= config.slide_jump_chain:
			bonus = config.slide_jump_bonus
			last_slide_jump_t = 0.0
		var horiz2 := _horiz(fighter.velocity)
		horiz2 *= (1.0 + bonus)
		fighter.velocity.x = horiz2.x
		fighter.velocity.z = horiz2.z
		_do_jump(fighter)
		state = State.AIR
		slide_cd = config.slide_cooldown
		_set_capsule(fighter, frame.crouch_held)
		crouching = frame.crouch_held
		return

	var spd_end := _horiz(fighter.velocity).length()
	if spd_end < config.slide_end_speed or not frame.crouch_held or slide_air_t > config.slide_air_max:
		state = State.GROUNDED if on_floor else State.AIR
		slide_cd = config.slide_cooldown
		crouching = frame.crouch_held and on_floor
		_set_capsule(fighter, crouching)

func _can_start_wallrun(fighter: CharacterBody3D, frame: InputFrame, wish: Vector3, on_floor: bool) -> bool:
	if on_floor or state == State.SLIDE:
		return false
	if coyote > config.coyote_time - config.wallrun_min_air and fighter.velocity.y > 0.0:
		# still just left ground
		pass
	# airborne at least wallrun_min_air — approximate via coyote depleted enough
	# Use a dedicated timer would be better; use velocity and not on floor long enough via wallrun only when coyote==0 and air
	if coyote > 0.0:
		return false
	if _horiz(fighter.velocity).length() < config.wallrun_min_speed:
		return false
	if wallrun_cd > 0.0:
		return false
	var hit := _probe_wall(fighter)
	if hit.is_empty():
		return false
	var n: Vector3 = hit["normal"]
	if absf(n.y) >= 0.3:
		return false
	# Must hold movement toward/along wall
	if wish.length_squared() < 0.01:
		return false
	var toward := -n
	if wish.dot(toward) < -0.2 and absf(wish.dot(n.cross(Vector3.UP).normalized())) < 0.2:
		return false
	wall_normal = n
	return true

func _step_wallrun(fighter: CharacterBody3D, frame: InputFrame, wish: Vector3, dt: float, on_floor: bool) -> bool:
	if on_floor:
		state = State.GROUNDED
		wallrun_cd = config.wallrun_cooldown
		return false
	var hit := _probe_wall(fighter)
	if hit.is_empty() or state != State.WALLRUN and not _can_start_wallrun(fighter, frame, wish, on_floor):
		if state == State.WALLRUN:
			state = State.AIR
			wallrun_cd = config.wallrun_cooldown
		return false
	if state != State.WALLRUN:
		state = State.WALLRUN
		wallrun_t = 0.0
		Events.fighter_wallrun_started.emit(fighter.get("id") as int if fighter.get("id") != null else -1)
	wall_normal = hit["normal"]
	wallrun_t += dt
	if wallrun_t >= config.wallrun_max_time or frame.move.length() < 0.1:
		state = State.AIR
		wallrun_cd = config.wallrun_cooldown
		return false
	# Project velocity onto wall plane, reduce gravity
	var vel := fighter.velocity.slide(wall_normal)
	vel.y -= config.gravity * config.wallrun_gravity_scale * dt
	# Accelerate along wall toward target speed
	var along := vel
	along.y = 0.0
	var tangent := wall_normal.cross(Vector3.UP).normalized()
	if along.dot(tangent) < 0.0:
		tangent = -tangent
	# Choose tangent closest to wish/facing
	var forward := Basis.from_euler(Vector3(0, yaw, 0)) * Vector3.FORWARD
	if forward.dot(tangent) < 0.0:
		tangent = -tangent
	var spd := Vector3(vel.x, 0, vel.z).length()
	if spd < config.wallrun_target_speed:
		vel += tangent * (config.wallrun_target_speed - spd) * dt * 4.0
	vel += -wall_normal * config.wallrun_hug * dt
	fighter.velocity = vel
	if frame.jump_pressed:
		_wall_jump(fighter, wall_normal)
		state = State.AIR
		wallrun_cd = config.wallrun_cooldown
	return true

func _try_wall_jump(fighter: CharacterBody3D) -> void:
	if wall_jumps >= config.walljump_max:
		return
	var hit := _probe_wall(fighter, config.walljump_probe)
	if hit.is_empty():
		return
	_wall_jump(fighter, hit["normal"])

func _wall_jump(fighter: CharacterBody3D, n: Vector3) -> void:
	if wall_jumps >= config.walljump_max:
		return
	var horiz := _horiz(fighter.velocity)
	var tangent := horiz - n * horiz.dot(n)
	fighter.velocity = n * config.walljump_normal_speed + Vector3.UP * config.walljump_up + tangent * config.walljump_tangent_keep
	wall_jumps += 1
	jump_buffer = 0.0
	just_jumped = true
	Audio.play_sfx("wall_jump")

func _probe_wall(fighter: CharacterBody3D, dist: float = -1.0) -> Dictionary:
	if dist < 0.0:
		dist = config.wallrun_probe
	var space := fighter.get_world_3d().direct_space_state
	var origin := fighter.global_position + Vector3.UP * 1.0
	var right := Basis.from_euler(Vector3(0, yaw, 0)) * Vector3.RIGHT
	for dir in [right, -right]:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * dist)
		q.collision_mask = 1 ## world
		q.exclude = [fighter.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit
	return {}

func _try_start_mantle(fighter: CharacterBody3D, frame: InputFrame, wish: Vector3) -> bool:
	if frame.move.y <= 0.1 and not (frame.jump_held or frame.jump_pressed):
		return false
	if fighter.velocity.y < -2.0:
		return false
	var space := fighter.get_world_3d().direct_space_state
	var forward := Basis.from_euler(Vector3(0, yaw, 0)) * Vector3.FORWARD
	var feet := fighter.global_position
	var chest := feet + Vector3.UP * 1.0
	var q1 := PhysicsRayQueryParameters3D.create(chest, chest + forward * 1.0)
	q1.collision_mask = 1
	q1.exclude = [fighter.get_rid()]
	var wall := space.intersect_ray(q1)
	if wall.is_empty():
		return false
	var top_start: Vector3 = (wall["position"] as Vector3) + Vector3.UP * 1.2 + forward * 0.2
	var q2 := PhysicsRayQueryParameters3D.create(top_start, top_start + Vector3.DOWN * 2.0)
	q2.collision_mask = 1
	q2.exclude = [fighter.get_rid()]
	var ledge := space.intersect_ray(q2)
	if ledge.is_empty():
		return false
	var n: Vector3 = ledge["normal"]
	if n.y < 0.7:
		return false
	var ledge_y: float = ledge["position"].y
	var h := ledge_y - feet.y
	if h < config.mantle_min_h or h > config.mantle_max_h:
		return false
	mantle_from = fighter.global_position
	mantle_to = Vector3(ledge["position"].x, ledge_y + 0.05, ledge["position"].z) + forward * 0.4
	mantle_pre_speed = _horiz(fighter.velocity).length()
	mantle_t = 0.0
	state = State.MANTLE
	fighter.velocity = Vector3.ZERO
	Audio.play_sfx("mantle")
	return true

func _step_mantle(fighter: CharacterBody3D, frame: InputFrame, dt: float) -> void:
	mantle_t += dt
	var a := clampf(mantle_t / config.mantle_duration, 0.0, 1.0)
	var ease := a * a * (3.0 - 2.0 * a)
	fighter.global_position = mantle_from.lerp(mantle_to, ease)
	fighter.velocity = Vector3.ZERO
	if a >= 1.0:
		state = State.GROUNDED
		var forward := Basis.from_euler(Vector3(0, yaw, 0)) * Vector3.FORWARD
		var spd := mantle_pre_speed * config.mantle_speed_keep
		fighter.velocity = forward * spd
		_move(fighter)

func _try_grapple(fighter: CharacterBody3D) -> void:
	var cam_origin := fighter.global_position + Vector3.UP * (config.crouch_eye if crouching else config.stand_eye)
	var forward := _aim_dir()
	var space := fighter.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam_origin, cam_origin + forward * config.grapple_range)
	q.collision_mask = 1
	q.exclude = [fighter.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	grappling = true
	grapple_anchor = hit["position"]
	grapple_len = cam_origin.distance_to(grapple_anchor)
	grapple_t = 0.0
	state = State.GRAPPLE
	Audio.play_sfx("grapple_attach", grapple_anchor)
	Events.grapple_attached.emit(fighter.get("id") as int if fighter.get("id") != null else -1, grapple_anchor)

func _step_grapple(fighter: CharacterBody3D, _frame: InputFrame, dt: float) -> void:
	grapple_t += dt
	grapple_len = maxf(config.grapple_min_len, grapple_len - config.grapple_reel * dt)
	var to_anchor := grapple_anchor - fighter.global_position
	var dist := to_anchor.length()
	var dir := to_anchor / maxf(dist, 0.001)
	fighter.velocity += dir * config.grapple_accel * dt
	# Cap speed along rope
	var along := fighter.velocity.dot(dir)
	if along > config.grapple_speed_cap:
		fighter.velocity -= dir * (along - config.grapple_speed_cap)
	if dist > grapple_len:
		# Remove outward radial, soft pull
		var rad := fighter.velocity.dot(dir)
		if rad < 0.0:
			fighter.velocity -= dir * rad
		fighter.velocity += dir * (dist - grapple_len) * 10.0 * dt
		fighter.global_position = grapple_anchor - dir * grapple_len
	fighter.velocity.y -= config.gravity * 0.35 * dt
	_cap_speed(fighter)
	state = State.GRAPPLE

func _release_grapple(fighter: CharacterBody3D, jump_release: bool) -> void:
	grappling = false
	grapple_cd = config.grapple_cooldown
	state = State.AIR
	if jump_release:
		fighter.velocity.y += config.grapple_jump_boost
	wall_jumps = 0 ## grapple release resets wall-jump counter per GDD
	Events.grapple_released.emit(fighter.get("id") as int if fighter.get("id") != null else -1)
	Audio.play_sfx("grapple_release")

func _apply_crouch(fighter: CharacterBody3D, frame: InputFrame, on_floor: bool) -> void:
	var want := frame.crouch_held and on_floor
	if crouching and not want:
		if not _can_stand(fighter):
			want = true
	if want != crouching:
		crouching = want
		_set_capsule(fighter, crouching)

func _can_stand(fighter: CharacterBody3D) -> bool:
	var space := fighter.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = config.stand_radius
	shape.height = config.stand_height
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, fighter.global_position + Vector3.UP * (config.stand_height * 0.5))
	params.collision_mask = 1
	params.exclude = [fighter.get_rid()]
	var hits := space.intersect_shape(params, 1)
	return hits.is_empty()

func _set_capsule(fighter: CharacterBody3D, crouch: bool) -> void:
	var col := fighter.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		return
	var cap := col.shape as CapsuleShape3D
	if cap == null:
		cap = CapsuleShape3D.new()
		col.shape = cap
	cap.radius = config.stand_radius
	cap.height = config.crouch_height if crouch else config.stand_height
	col.position = Vector3(0, cap.height * 0.5, 0)

func _cap_speed(fighter: CharacterBody3D) -> void:
	var horiz := _horiz(fighter.velocity)
	var spd := horiz.length()
	if spd > config.max_speed_hard_cap:
		horiz = horiz.normalized() * config.max_speed_hard_cap
		fighter.velocity.x = horiz.x
		fighter.velocity.z = horiz.z

func _move(fighter: CharacterBody3D) -> void:
	fighter.move_and_slide()

func _horiz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _aim_dir() -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD

func eye_height() -> float:
	return config.crouch_eye if crouching else config.stand_eye

func horizontal_speed(fighter: CharacterBody3D) -> float:
	return _horiz(fighter.velocity).length()

func state_name() -> String:
	match state:
		State.GROUNDED: return "grounded"
		State.AIR: return "air"
		State.SLIDE: return "slide"
		State.WALLRUN: return "wallrun"
		State.MANTLE: return "mantle"
		State.GRAPPLE: return "grapple"
	return "?"
