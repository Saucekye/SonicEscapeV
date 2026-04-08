extends Node2D
signal dialogue
signal next

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "play1":
		emit_signal("next")
		$AnimationPlayer.play("play2")
	if anim_name == "play2":
		emit_signal("next")
		$AnimationPlayer.play("play3")
	if anim_name == "play3":
		emit_signal("next")
		$AnimationPlayer.play("play4")
	
	if anim_name == "play4":
		var result = ResourceLoader.load_threaded_get("uid://cap4asy61pcru")
		if result is PackedScene:
			get_tree().change_scene_to_packed(result)
		else:
			push_error("Failed to load next scene!")

func _on_control_cutscene() -> void:
	$AnimationPlayer.play("play1")

func _on_animation_player_animation_started(anim_name: StringName) -> void:
	if anim_name == "play1":
		await get_tree().create_timer(1).timeout
		emit_signal("dialogue")
		
