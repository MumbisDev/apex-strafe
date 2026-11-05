class_name HudVitals
extends VBoxContainer
## Bottom-left block: powerup timers, health number and bar, armor bar.

const HEALTH_OK: Color = Color("#4DFF88")
const HEALTH_LOW: Color = Color("#FF3B3B")
const ARMOR_COLOR: Color = Color("#4D9FFF")
const POWERUP_COLORS: Dictionary = {
	"OVERCHARGE": Color("#B84DFF"),
	"HASTE": Color("#19E3FF"),
	"SHIELD": Color("#FFFFFF"),
}

var health_value: float = 100.0
var armor_value: float = 0.0
var health_label: Label
var armor_label: Label
var health_bar: ProgressBar
var armor_bar: ProgressBar
var _max_health: float = 100.0
var _initialized: bool = false
var _powerup_row: HBoxContainer
var _powerup_labels: Dictionary = {} ## name -> Label

static func health_color(health: float) -> Color:
	if health < 25.0:
		return HEALTH_LOW
	if health < 50.0:
		return UITheme.WARN
	return HEALTH_OK

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	_powerup_row = HBoxContainer.new()
	_powerup_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_powerup_row.add_theme_constant_override("separation", 12)
	add_child(_powerup_row)
	for key: String in POWERUP_COLORS:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
		l.add_theme_color_override("font_color", POWERUP_COLORS[key] as Color)
		_powerup_row.add_child(l)
		_powerup_labels[key] = l
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 56)
	add_child(health_label)
	health_bar = _bar(Vector2(260, 14), HEALTH_OK)
	armor_bar = _bar(Vector2(260, 8), ARMOR_COLOR)
	armor_label = Label.new()
	armor_label.add_theme_font_size_override("font_size", 16)
	armor_label.add_theme_color_override("font_color", ARMOR_COLOR)
	add_child(armor_label)
	set_health(health_value, armor_value)

func set_health(health: float, armor: float, max_health: float = 100.0) -> void:
	if health == health_value and armor == armor_value and max_health == _max_health and _initialized:
		return
	_initialized = true
	_max_health = max_health
	health_value = health
	armor_value = armor
	var col := health_color(health)
	health_label.text = str(ceili(maxf(health, 0.0)))
	health_label.add_theme_color_override("font_color", col)
	health_bar.max_value = maxf(100.0, max_health)
	health_bar.value = health
	(health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col
	armor_bar.value = armor
	armor_label.text = "ARMOR %d" % ceili(armor)
	armor_label.visible = armor > 0.0
	armor_bar.visible = armor > 0.0

## active: powerup name (upper case) -> seconds remaining.
func set_powerups(active: Dictionary) -> void:
	for key: String in _powerup_labels:
		var l := _powerup_labels[key] as Label
		var left := float(active.get(key, 0.0))
		l.visible = left > 0.0
		if l.visible:
			l.text = "%s %.0fs" % [key, ceilf(left)]

func is_powerup_visible(key: String) -> bool:
	return _powerup_labels.has(key) and (_powerup_labels[key] as Label).visible

func _bar(min_size: Vector2, fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.show_percentage = false
	b.custom_minimum_size = min_size
	b.min_value = 0.0
	b.max_value = 100.0
	b.add_theme_stylebox_override("background", UITheme.box(Color(UITheme.PANEL, 0.85), Color(0, 0, 0, 0), 0, 3, 0))
	b.add_theme_stylebox_override("fill", UITheme.box(fill, Color(0, 0, 0, 0), 0, 3, 0))
	add_child(b)
	return b
