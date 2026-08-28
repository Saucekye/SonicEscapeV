extends Node2D
@onready var sprite: Sprite2D = $ParallaxBackground/ParallaxLayer/Sprite2D
@onready var anim: AnimationPlayer = $ParallaxBackground/ParallaxLayer/Sprite2D/AnimationPlayer
var sprite_base_position: Vector2
var idle_float_time: float = 0.0
var idle_float_speed: float = 2.0        # how fast it bobs horizontally
var idle_float_amplitude: float = 10.0    # how far it moves in pixels (x)
var idle_float_speed_y: float = 5.5      # vertical bob speed (different = less linear motion)
var idle_float_amplitude_y: float = 8.0  # how far it moves in pixels (y)
var is_idle: bool = false

func _ready() -> void:
	sprite_base_position = sprite.position

func _process(delta: float) -> void:
	if is_idle:
		idle_float_time += delta
		sprite.position.x = sprite_base_position.x + sin(idle_float_time * idle_float_speed) * idle_float_amplitude
		sprite.position.y = sprite_base_position.y + cos(idle_float_time * idle_float_speed_y) * idle_float_amplitude_y

func _on_node_2d_lunara() -> void:
	is_idle = false
	anim.play("intro")
	await anim.animation_finished
	sprite_base_position = sprite.position  # lock in position after intro finishes
	idle_float_time = 0.0
	is_idle = true
	anim.play("idle")

func _on_node_2d_over() -> void:
	is_idle = false
	sprite.position = sprite_base_position  # snap back to rest position, avoids jump
	anim.play("death")
