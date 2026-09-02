extends Node2D

@export var chance: float = 0.5  # 50% chance

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if randf() <= 0.5:
		if randf() <= 0.25 and Test.complete == true:
			get_tree().change_scene_to_file("res://GameOver/screen2.tscn")
		else:
			get_tree().change_scene_to_file("res://GameOver/screen1.tscn")
	else:
		Test.quit = true
	
