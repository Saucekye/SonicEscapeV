extends Components_Action

func action() -> void:
	player.ap.play("airspin")
	player.time_elapsed = 200
	player.max_speed = 1600
	player.can_dash = true
	player.can_stomp = true
	player.bounce = 0
	
	# Air horizontal boost — costs meter, launches in current direction with upward arc
	player.falling = true
	player.dashed = true
	player.ball = false
	if player.is_player == true:
		Test.meter -= 50
	player.ap.play("airspin")
	player.motion.y = -650
	player.fall_gravity = 0         # Brief gravity suspension for the spin hang-time
	player.spinaudio()
	player.smokeemit()
	player.max_speed = 1200
	player.acc = 5000
	player.time_elapsed = 200
	player.motion.x = 1200 * sign(player.direction)
	await get_tree().create_timer(0.13).timeout
	player.fall_gravity = player.default
