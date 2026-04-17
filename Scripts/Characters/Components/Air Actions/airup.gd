extends Components_Action

func action() -> void:
	player.can_dash = true
	player.can_stomp = true
	player.bounce = 0
	
	# Air vertical boost — costs meter, launches straight up
	player.dashed = true
	player.ball = false
	if player.is_player == true:
		Test.meter -= 50
	player.ap.play("airup")
	player.motion.y = -1100
	player.spinaudio()
	player.smokeemit()
	await get_tree().create_timer(0.13).timeout
	player.fall_gravity = player.default
	await get_tree().create_timer(0.3).timeout  # Small delay before entering "falling" state
	player.falling = true
	player.ap.play("falling")
	
