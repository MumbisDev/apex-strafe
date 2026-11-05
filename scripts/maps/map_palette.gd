class_name MapPalette
extends Resource
## Per-map colors, procedural grid texture, material cache and environment setup.

@export var id: String = ""
@export var floor_color: Color = Color(0.2, 0.2, 0.22)
@export var wall_color: Color = Color(0.3, 0.3, 0.33)
@export var accent_color: Color = Color(1.0, 0.5, 0.1)
@export var trim_color: Color = Color(1.0, 0.5, 0.1)
@export var sky_top: Color = Color(0.2, 0.3, 0.6)
@export var sky_horizon: Color = Color(0.7, 0.6, 0.6)
@export var fog_color: Color = Color(0.5, 0.45, 0.5)
@export var fog_density: float = 0.003
@export var sun_color: Color = Color(1.0, 0.9, 0.8)
@export var sun_energy: float = 1.1
@export var sun_rotation_deg: Vector3 = Vector3(-50.0, 35.0, 0.0)
@export var ambient_energy: float = 0.8

const GRID_SIZE: int = 256
const GRID_LINE_EVERY: int = 128
const GRID_UV_SCALE: float = 0.25

static var _grid_texture: ImageTexture = null

var _cache: Dictionary = {}

## Low-contrast tileable grid (256x256). Cached for all palettes.
static func grid_texture() -> ImageTexture:
	if _grid_texture != null:
		return _grid_texture
	var img := Image.create_empty(GRID_SIZE, GRID_SIZE, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.94, 0.94, 0.94))
	var minor := Color(0.9, 0.9, 0.9)
	var major := Color(0.8, 0.8, 0.8)
	for i in range(0, GRID_SIZE, GRID_LINE_EVERY / 4):
		img.fill_rect(Rect2i(i, 0, 1, GRID_SIZE), minor)
		img.fill_rect(Rect2i(0, i, GRID_SIZE, 1), minor)
	for i in range(0, GRID_SIZE, GRID_LINE_EVERY):
		img.fill_rect(Rect2i(i, 0, 2, GRID_SIZE), major)
		img.fill_rect(Rect2i(0, i, GRID_SIZE, 2), major)
	img.generate_mipmaps()
	_grid_texture = ImageTexture.create_from_image(img)
	return _grid_texture

func material(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "m%s_%s_%s" % [color.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = grid_texture()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * GRID_UV_SCALE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = roughness
	mat.metallic = metallic
	_cache[key] = mat
	return mat

func floor_material() -> StandardMaterial3D:
	return material(floor_color)

func glossy_floor_material() -> StandardMaterial3D:
	return material(floor_color, 0.25, 0.3)

func wall_material() -> StandardMaterial3D:
	return material(wall_color)

func accent_material() -> StandardMaterial3D:
	return material(accent_color, 0.6)

func emissive_material(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var key := "e%s_%s" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.5)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	_cache[key] = mat
	return mat

func build_environment(parent: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_horizon
	sky_mat.ground_horizon_color = sky_horizon.darkened(0.25)
	sky_mat.ground_bottom_color = fog_color.darkened(0.5)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.rotation_degrees = sun_rotation_deg
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 1.0
	sun.directional_shadow_max_distance = 160.0
	parent.add_child(sun)

static func foundry() -> MapPalette:
	var p := MapPalette.new()
	p.id = "foundry"
	p.floor_color = Color(0.16, 0.16, 0.18)
	p.wall_color = Color(0.24, 0.23, 0.26)
	p.accent_color = Color(1.0, 0.45, 0.08)
	p.trim_color = Color(1.0, 0.45, 0.08)
	p.sky_top = Color(0.28, 0.16, 0.42)
	p.sky_horizon = Color(1.0, 0.55, 0.3)
	p.fog_color = Color(0.45, 0.28, 0.3)
	p.sun_color = Color(1.0, 0.7, 0.5)
	p.sun_rotation_deg = Vector3(-35.0, 40.0, 0.0)
	return p

static func spire() -> MapPalette:
	var p := MapPalette.new()
	p.id = "spire"
	p.floor_color = Color(0.82, 0.9, 0.94)
	p.wall_color = Color(0.7, 0.84, 0.9)
	p.accent_color = Color(0.1, 0.85, 0.8)
	p.trim_color = Color(0.1, 0.95, 0.85)
	p.sky_top = Color(0.35, 0.65, 0.95)
	p.sky_horizon = Color(0.85, 0.95, 1.0)
	p.fog_color = Color(0.75, 0.9, 0.98)
	p.fog_density = 0.0015
	p.sun_energy = 1.3
	p.ambient_energy = 1.0
	p.sun_rotation_deg = Vector3(-55.0, 25.0, 0.0)
	return p

static func sprawl() -> MapPalette:
	var p := MapPalette.new()
	p.id = "sprawl"
	p.floor_color = Color(0.07, 0.07, 0.11)
	p.wall_color = Color(0.14, 0.12, 0.22)
	p.accent_color = Color(1.0, 0.15, 0.7)
	p.trim_color = Color(0.1, 1.0, 0.9)
	p.sky_top = Color(0.1, 0.05, 0.25)
	p.sky_horizon = Color(0.9, 0.2, 0.55)
	p.fog_color = Color(0.3, 0.12, 0.35)
	p.sun_color = Color(0.9, 0.6, 0.9)
	p.sun_energy = 0.8
	p.sun_rotation_deg = Vector3(-30.0, 60.0, 0.0)
	return p

static func practice_range() -> MapPalette:
	var p := MapPalette.new()
	p.id = "range"
	p.floor_color = Color(0.3, 0.32, 0.36)
	p.wall_color = Color(0.45, 0.48, 0.54)
	p.accent_color = Color(0.2, 0.8, 1.0)
	p.trim_color = Color(0.2, 0.9, 1.0)
	p.sky_top = Color(0.25, 0.4, 0.7)
	p.sky_horizon = Color(0.75, 0.82, 0.9)
	p.fog_color = Color(0.6, 0.65, 0.72)
	p.fog_density = 0.001
	p.sun_rotation_deg = Vector3(-60.0, 20.0, 0.0)
	return p
