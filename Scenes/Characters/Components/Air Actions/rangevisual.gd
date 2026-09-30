extends Node2D

@export var homing_attack: Node
@export var show_range: bool = true


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not show_range:
		return

	if homing_attack == null:
		return

	var range = homing_attack.homing_range

	draw_circle(
		Vector2.ZERO,
		range,
		Color(0.2, 0.7, 1.0, 0.08)
	)

	draw_arc(
		Vector2.ZERO,
		range,
		0.0,
		TAU,
		64,
		Color(0.2, 0.7, 1.0, 0.7),
		3.0
	)
