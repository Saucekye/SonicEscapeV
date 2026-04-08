extends AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play("RESET")
	await(get_tree().create_timer(1.5)).timeout
	play("start")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
