class_name LoadingScreen
extends Control
## Loading screen: progress bar, step text, rotating movement tips, 0.2 s fade-in. Yields a frame per
## step so the bar animates, then hands over to the match scene.

const STEPS: Array[String] = [
	"Building arena...", "Generating waypoints...", "Spawning fighters...",
	"Warming particle and audio pools...", "Ready!",
]
const TIPS: Array[String] = [
	"Hold jump to bunnyhop, strafe and turn the same direction to gain speed.",
	"Crouch while running to slide, jump out of a slide to keep your speed.",
	"Rockets at your feet launch you, but cost health.",
	"Grapple shortens while held: swing and release to carry the speed.",
	"Wall-run by holding into a wall after leaving the ground.",
	"Headshots multiply damage. Aim for the visor.",
	"Pickups show a respawn ring: use it to time the map.",
]
const TIP_INTERVAL: float = 3.0
const STEP_DELAY: float = 0.05
const FADE_IN: float = 0.2

var _bar: ProgressBar
var _step_label: Label
var _tip_label: Label
var _tip_index: int = 0
var _tip_t: float = 0.0

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_tip_index = randi() % TIPS.size()
	_tip_label.text = TIPS[_tip_index]
	_run.call_deferred()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var title := Label.new()
	title.text = "LOADING %s" % Game.match_config.map_id.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	v.add_child(title)
	_bar = ProgressBar.new()
	_bar.max_value = float(STEPS.size())
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	_bar.add_theme_stylebox_override("background", UITheme.box(UITheme.PANEL, Color(0, 0, 0, 0), 0, 4, 0))
	_bar.add_theme_stylebox_override("fill", UITheme.box(UITheme.ACCENT, Color(0, 0, 0, 0), 0, 4, 0))
	v.add_child(_bar)
	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_step_label)
	_tip_label = Label.new()
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(_tip_label)

func _process(delta: float) -> void:
	_tip_t += delta
	if _tip_t >= TIP_INTERVAL:
		_tip_t = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip_label.text = TIPS[_tip_index]

func _run() -> void:
	for text in STEPS:
		_step_label.text = text
		_bar.value += 1.0
		await get_tree().process_frame
		await get_tree().create_timer(STEP_DELAY).timeout
	Game.go_match()
