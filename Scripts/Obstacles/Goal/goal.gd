extends Area2D

var levelover = false

func _ready() -> void:
	add_to_group("goal")   # online, net.gd ends the floor through finish_level()
	$Sprite2D.frame = 0
	# Also watch Miku's physics layer (5), or she could never reach the goal
	set_collision_mask_value(5, true)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.is_player:
			Test.floor_done = true   # stops the floor timer (timer.gd)
			GlobalSignals.emit_signal("camerashake")
			$Sprite2D.play("default")
			Net.goal_reached()   # online: a 10 s countdown for everyone, then the next floor
			
	if preload("res://Scripts/Effects/miku_saved.gd").is_rescue(body):   # Miku, or an OC in her place
		GlobalCanvasLayer.tricks += 10
		preload("res://Scripts/Effects/miku_saved.gd").save(body)   # points pop-up and score

func _on_sprite_2d_animation_finished() -> void:
			if Net.online:
				return   # online: the countdown (net.gd) ends the floor for everyone
			finish_level()


## End the floor: on to the next one. Called when the goal's animation finishes,
## or online by net.gd when the goal countdown runs out (on the host).
func finish_level() -> void:
			GlobalCanvasLayer.tricks += 1
			Test.end = true
			if levelover == false:
				if Test.rest == false and Test.final == false:
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
