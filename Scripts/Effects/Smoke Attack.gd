extends AnimatedSprite2D

# Optional motion and fade, so dust puffs can kick back and drift. With the
# defaults the effect stays where it spawned (the other smoke effects use that).
var velocity := Vector2.ZERO   ## World units per second
var drag := 0.0                ## How fast velocity bleeds off (units/s²)
var fade_out := false          ## Fade to transparent over the animation

var _frame_total := 1


# Called when the node enters the scene tree for the first time.
func _ready():
	play("default")
	if sprite_frames:
		_frame_total = max(1, sprite_frames.get_frame_count(animation))

func _process(delta):
	if velocity != Vector2.ZERO:
		position += velocity * delta
		velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	if fade_out:
		var progress := (float(frame) + frame_progress) / float(_frame_total)
		modulate.a = clamp(1.15 - progress * 1.15, 0.0, 1.0)

func _on_animation_finished():
	queue_free()
