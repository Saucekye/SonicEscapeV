extends Components_Action

func action() -> void:	
	# Guard: don't process peelout if spindash is active
	if player.is_spinningdash or Input.is_action_pressed("ui_down") or player.motion.x != 0:
		return
		
	if player.is_on_floor() and Input.is_action_pressed("ui_up") and player.ball == false and player.next_bounce == false and player.motion.x == 0 and player.direction == 0: 
		player.control_lock = true
		player.crouch = true
		if player.is_spinningdash == false and player.is_ready == false:
			player.ap.play("ready")
		
		if Input.is_action_pressed("ui_accept") and not player.is_spinning and not player.is_ready:
			revpeelout()

	elif player.is_on_floor() and Input.is_action_just_released("ui_up") and player.is_spinning and player.is_ready:
		# Release: launch forward at full peel-out speed
		player.control_lock = false
		player.crouch = false
		player.sfx.pitch_scale = 1.5
		player.sfx.stream = load("res://Sounds/SonicSFX/spindash.MP3")
		player.sfx.play()
		player.time_elapsed = 300
		player.is_spinning = false
		player.is_ready = false
		player.spin_dash_speed = clamp(player.spin_charge * player.spin_dash_acceleration, 0, 1600)
		player.motion.x = player.spin_dash_speed * sign(player.motion.x) if player.motion.x != 0 else player.spin_dash_speed * (1 if player.sprite.flip_h == false else -1)
		player.max_speed = 1800
		player.acc = 5000
		player.ap.play("Dash max")
		player.smokeemit()
		
	elif not player.is_spinningdash:
		# Not in any special state — ensure flags are clean
		player.is_ready = false
		player.is_spinning = false
		
func revpeelout():
	# Start the rev peel-out animation
	Input.is_action_pressed("ui_up")  # Note: this line has no effect — likely a leftover check
	player.ap.play("Revpeelout")
	player.is_ready = true
