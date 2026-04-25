extends Components_Action

func action() -> void:
	if not (Input.is_action_just_pressed("trick") and not (player.is_on_wall_only() and (not player.raycast.is_colliding()) and player.rot == 0) and not player.flying):
		return
			
	player.ap.play("play")
	
	# Cycle through trick animations in order; gain meter and count tricks
	player.dashed = true
	player.falling = true
	if player.is_player == true:
		Test.meter += 1
		GlobalCanvasLayer.tricks += 1
		
	var tricks = ["trick1", "trick2", "trick3", "trick4"]
	var last_index = tricks.find(player.last_trick)
	var next_index = (last_index + 1) % tricks.size()  # Always moves to the next in sequence
	var new_trick = tricks[next_index]
	player.last_trick = new_trick
	player.sparkemit()
	player.sfx.pitch_scale = 1
	player.sfx.stream = load("res://Sounds/SonicSFX/sparklesfx.MP3")
	player.sfx.play()
	player.ap.play(new_trick)
	await get_tree().create_timer(0.3).timeout
	# Only re-enable dash/fall if trick button was released during the animation
	if not Input.is_action_pressed("trick"):
		player.dashed = false
