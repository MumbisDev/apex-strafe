class_name BulletDecal
extends Decal
## Pooled bullet-hole decal with a procedural 64x64 texture; fades out after LIFETIME seconds.

const LIFETIME: float = 12.0
const FADE_TIME: float = 2.0
const TEX_SIZE: int = 64

static var _texture: ImageTexture

var _age: float = LIFETIME

static func shared_texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var img := Image.create_empty(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var c := Vector2(TEX_SIZE, TEX_SIZE) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var d := Vector2(x, y).distance_to(c) / (TEX_SIZE * 0.5)
			var ragged := 0.78 + rng.randf() * 0.2
			var core := clampf((ragged - d) / 0.25, 0.0, 1.0)
			var halo := clampf((1.0 - d) * 0.5, 0.0, 0.35)
			var a := maxf(core, halo)
			var shade := 0.02 + 0.1 * d
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	_texture = ImageTexture.create_from_image(img)
	return _texture

func _ready() -> void:
	texture_albedo = shared_texture()
	size = Vector3(0.22, 0.3, 0.22)
	visible = false
	set_process(false)

func place(pos: Vector3, normal: Vector3) -> void:
	global_transform = Transform3D(FxUtil.basis_up(normal), pos + normal * 0.02)
	_age = 0.0
	modulate = Color.WHITE
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		visible = false
		set_process(false)
	elif _age > LIFETIME - FADE_TIME:
		modulate.a = (LIFETIME - _age) / FADE_TIME
