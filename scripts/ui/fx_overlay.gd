class_name FxOverlay
extends ColorRect
## Full-screen shader overlay: low-health vignette + heartbeat, damage flash, speed lines,
## powerup tint, slide radial blur, death desaturation. Hidden (zero cost) when nothing is active.

const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float low_health = 0.0;
uniform float heartbeat = 0.0;
uniform float damage_flash = 0.0;
uniform float speed_lines = 0.0;
uniform vec4 tint = vec4(0.0);
uniform float blur = 0.0;
uniform float desaturate = 0.0;
uniform float death_vignette = 0.0;
uniform float time_s = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float r = length(d) * 1.41421;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	if (blur > 0.001) {
		vec3 acc = col;
		for (int i = 1; i <= 5; i++) {
			acc += textureLod(screen_tex, uv - d * (float(i) / 5.0) * blur * 0.05, 0.0).rgb;
		}
		col = acc / 6.0;
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate);
	col = mix(col, mix(col, tint.rgb, 0.35), tint.a);
	float vig = smoothstep(0.4, 1.1, r);
	col = mix(col, vec3(0.85, 0.0, 0.05), vig * low_health * (0.3 + 0.7 * heartbeat));
	col *= 1.0 - vig * death_vignette * 0.85;
	col = mix(col, vec3(1.0, 0.1, 0.1), damage_flash * (0.12 + 0.5 * vig));
	float ang = atan(d.y, d.x);
	float sector = floor(ang * 70.0);
	float n = hash(vec2(sector, floor(time_s * 24.0)));
	float streak = step(0.8, n) * smoothstep(0.3, 0.95, r);
	col += vec3(streak) * speed_lines * 0.35;
	COLOR = vec4(col, 1.0);
}
"""

const LOW_HEALTH_START: float = 30.0
const SPEED_LINES_START: float = 14.0
const SPEED_LINES_FULL: float = 24.0
const FLASH_DECAY: float = 3.0

var low_health: float = 0.0
var heartbeat: float = 0.0
var flash: float = 0.0
var speed_lines: float = 0.0
var blur: float = 0.0
var desaturate: float = 0.0
var death_vignette: float = 0.0
var tint_color: Color = Color(1, 1, 1, 0)

var _material: ShaderMaterial
var _target_lines: float = 0.0
var _target_blur: float = 0.0
var _dead: bool = false
var _hb_phase: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material
	visible = false

## Health drives the low-health vignette (below 30) and heartbeat.
func set_health(health: float) -> void:
	low_health = clampf((LOW_HEALTH_START - health) / LOW_HEALTH_START, 0.0, 1.0) if not _dead else 0.0

func set_speed(ups: float, sliding: bool = false) -> void:
	var t := clampf((ups - SPEED_LINES_START) / (SPEED_LINES_FULL - SPEED_LINES_START), 0.0, 1.0)
	_target_lines = t * Settings.speed_lines_amount
	_target_blur = clampf((ups - 12.0) / 10.0, 0.0, 1.0) * 0.6 if sliding else 0.0

func set_dead(dead: bool) -> void:
	_dead = dead
	if dead:
		low_health = 0.0

func set_tint(c: Color, strength: float) -> void:
	tint_color = Color(c.r, c.g, c.b, clampf(strength, 0.0, 1.0))

func flash_damage(amount: float) -> void:
	flash = clampf(maxf(flash, 0.3 + amount / 80.0), 0.0, 1.0)

func is_active() -> bool:
	return low_health > 0.0 or flash > 0.001 or speed_lines > 0.001 or blur > 0.001 \
			or desaturate > 0.001 or death_vignette > 0.001 or tint_color.a > 0.001

func _process(delta: float) -> void:
	_t += delta
	flash = maxf(0.0, flash - FLASH_DECAY * delta)
	speed_lines = move_toward(speed_lines, _target_lines, delta * 4.0)
	blur = move_toward(blur, _target_blur, delta * 3.0)
	desaturate = move_toward(desaturate, 0.85 if _dead else 0.0, delta * 1.5)
	death_vignette = move_toward(death_vignette, 1.0 if _dead else 0.0, delta * 0.8)
	_hb_phase += delta * (1.1 + low_health * 1.4)
	var p := fmod(_hb_phase, 1.0)
	heartbeat = exp(-pow(p * 14.0, 2.0)) + 0.6 * exp(-pow((p - 0.25) * 14.0, 2.0)) if low_health > 0.0 else 0.0
	var active := is_active()
	visible = active
	if not active:
		return
	_material.set_shader_parameter("low_health", low_health)
	_material.set_shader_parameter("heartbeat", clampf(heartbeat, 0.0, 1.0))
	_material.set_shader_parameter("damage_flash", flash)
	_material.set_shader_parameter("speed_lines", speed_lines)
	_material.set_shader_parameter("tint", tint_color)
	_material.set_shader_parameter("blur", blur)
	_material.set_shader_parameter("desaturate", desaturate)
	_material.set_shader_parameter("death_vignette", death_vignette)
	_material.set_shader_parameter("time_s", _t)
