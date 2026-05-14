extends ColorRect

@onready var fade_animation_player: AnimationPlayer = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Test.ridenemies = false
	Test.fail = false
	GlobalSignals.connect("game_over", _on_game_over)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Test.end == true:
		emit_signal("goal")
		Test.ridenemies = true
		Test.end = false
		fade_animation_player.play("restart")

func _on_canvas_layer_restart() -> void:
	get_tree().reload_current_scene()
	fade_animation_player.play("restart")

func _on_game_over():
	fade_animation_player.play("Game_Over")
