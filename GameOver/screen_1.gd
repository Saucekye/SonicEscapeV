extends Node2D

func _ready() -> void:
	if randf() < 0.5:
		$Label2.text = "Your Actions have Consequences"
	else:
		$Label2.text = "There are no Second Chances"


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	Test.quit = true
