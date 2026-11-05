class_name KillVolume
extends Area3D
## Trigger volume that reports fighters entering it (void or hazard such as lava).
## MatchManager connects to `fighter_entered` and applies death attribution.

signal fighter_entered(body: Node3D, kind: String)

var kind: String = "void"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	fighter_entered.emit(body, kind)
