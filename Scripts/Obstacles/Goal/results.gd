extends Sprite2D

signal goal
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Test.ridenemies = false
	Test.fail = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Test.end == true:
		emit_signal("goal")
		Test.ridenemies = true
		Test.end = false
		$AnimationPlayer.play("restart")
		


func _on_canvas_layer_restart() -> void:
	get_tree().reload_current_scene()
	$AnimationPlayer.play("restart")
