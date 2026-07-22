extends Area2D

var levelover = false



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.is_player:
			$Sprite2D.play("default")
	if body.is_in_group("Miku"):
		GlobalCanvasLayer.tricks += 10


func _on_sprite_2d_animation_finished() -> void:
			GlobalCanvasLayer.tricks += 1
			Test.end = true
			if levelover == false:
				Test.level += 1
				levelover = true
				if Test.level % 4 == 0:
					var tween = create_tween()
					# Fade out the screen
					# FIXED: Check if AudioStreamPlayer2D exists before trying to fade it
					tween.parallel().tween_property(MusicManager, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					await tween.finished
					MusicManager.stop()
					Test.musicplaying = false
				else:
					if Test.musicplaying == false:
						Test.musicplaying = false
						MusicManager.play()
