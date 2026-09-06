extends Node2D

@onready var sprite: Sprite2D = $ParallaxBackground/ParallaxLayer/Sprite2D
@onready var anim: AnimationPlayer = $ParallaxBackground/ParallaxLayer/Sprite2D/AnimationPlayer

var sprite_base_position: Vector2
var idle_float_time: float = 0.0
var idle_float_speed: float = 2.0
var idle_float_amplitude: float = 10.0
var idle_float_speed_y: float = 5.5
var idle_float_amplitude_y: float = 8.0
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
	sprite_base_position = sprite.position
	idle_float_time = 0.0
	is_idle = true
	anim.play("idle")
	_idle_attack_loop()

func _idle_attack_loop() -> void:
	while is_idle:
		var wait_time := randf_range(3.0, 4.0)
		await get_tree().create_timer(wait_time).timeout

		if not is_idle:
			break

		anim.play("attack2")
		await get_tree().create_timer(0.5).timeout
		$LightningEffect/AnimationTree.play("Left")
		await anim.animation_finished

		if not is_idle:
			break

		anim.play("idle")

func _on_node_2d_over() -> void:
	is_idle = false
	sprite.position = sprite_base_position
	anim.play("death")
