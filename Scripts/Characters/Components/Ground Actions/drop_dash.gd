extends Components_Action

func action() -> void:
# ── Drop Dash Release ──────────────────────────────────────────
	if not player.is_drop_dashing or not player.drop_dash_charge >= player.drop_dash_charge_time:
		return
	if Input.is_action_pressed("ui_accept"):
		_execute_drop_dash()
	else:
		# Button was released before landing — cancel the drop dash
		player.is_drop_dashing = false
		player.drop_dash_charge = 0.0

func _execute_drop_dash() -> void:
	# Trigger a drop dash burst on landing after a charged air hold
	player.is_drop_dashing = false
	player.drop_dash_charge = 0.0
	player.ball = true
	player.crouch = true
	
	var dash_direction = 1 if not player.sprite.flip_h else -1
	if player.direction != 0:
		dash_direction = sign(player.direction)
	
	# Only apply if below the speed threshold (avoids fighting existing fast momentum)
	if player.max_speed <= 1000:
		player.motion.x = player.drop_dash_speed * dash_direction
		player.time_elapsed = 100
		player.max_speed = 1000
		player.acc = 5000
	
	player.smokeemit()
	player.sfx.pitch_scale = 1.5
	player.sfx.stream = load("res://Sounds/SonicSFX/spindash.MP3")
	player.sfx.play()
	player.ap.play("ball")
	player.ap.speed_scale = 2
