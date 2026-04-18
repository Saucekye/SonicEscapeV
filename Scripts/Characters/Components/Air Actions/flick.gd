extends Components_Action

func action() -> void:
	player.can_dash = false
	player.can_stomp = true
	player.ap.play("flick")
	
	# Air dash: brief horizontal burst with a pop upward and no gravity
	player.falling = true
	player.dashed = true
	player.ball = false
	player.crouch = false
	player.can_dash = false
	player.ap.play("flick")
	player.motion.y = -450
	player.fall_gravity = 0           # Disable gravity briefly for the dash hang-time
	player.smokeemit()
	player.sfx.pitch_scale = 2
	player.sfx.stream = load("res://Sounds/SonicSFX/SA_113.wav")
	player.sfx.play()

	# Only override speed if below dash threshold — respects existing momentum
	if abs(player.motion.x) <= 1050:
		player.time_elapsed = 60
		player.max_speed = 1000
		player.acc = 5000
		player.motion.x = 1050 * sign(player.direction) if player.direction != 0 else 1050 * (1 if player.sprite.flip_h == false else -1)
	await get_tree().create_timer(0.13).timeout
	player.fall_gravity = player.default   # Restore gravity after dash hang
	player.dashx = true
	player.can_dash = false
