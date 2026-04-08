extends Node2D

func _ready():
	randomize()  # ensures better randomness
	start_random_timer()

func start_random_timer():
	await get_tree().create_timer(randf_range(10.0, 20.0)).timeout
	$AnimatedSprite2D2/AnimationPlayer.play("fall")
	start_random_timer()
