extends Area2D
## A boss shot: flies straight, hurts the player on touch (it's in the
## "enemyattack" group), and disappears after a few seconds.

@export var lifetime := 4.0
var velocity := Vector2.ZERO


func _process(delta: float) -> void:
	position += velocity * delta
	rotation += 8.0 * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
