extends Node2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D

var has_interacted : bool = false

signal makima_intro_done

func _on_area_2d_area_entered(area: Area2D) -> void:
	if !area.is_in_group("Player") or has_interacted:
		return
	var TWEEN_TIME : float = 1.5
	var sprite_tween : Tween = get_tree().create_tween()
	has_interacted = true
	area_2d.monitoring = false
	sprite_tween.tween_property(animated_sprite_2d, "modulate:a", 0, TWEEN_TIME)
	await sprite_tween.finished
	makima_intro_done.emit()
	
