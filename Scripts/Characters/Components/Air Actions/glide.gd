extends Components_Action

func action() -> void:
	if player.flying == true and Input.is_action_pressed("ui_accept"):
		_handle_glide_physics()
	else:
		# If not actively gliding, resume normal falling
		player.flying = false
		player.fall_gravity = player.default
		player.falling = true

	# Jump press in air starts the glide
	if Input.is_action_just_pressed("ui_accept") and not Input.is_action_pressed("ui_down") and not player.is_coyote_time_active():
		_dash(player.direction if player.direction != 0 else (1 if not player.sprite.flip_h else -1))

func _dash(direction) -> void:
	# For Knuckles, "dash" initiates the glide — not a burst dash like Sonic's.
	# Sets up low gravity and a minimum forward speed, then handle_glide_physics
	# takes over each frame while jump is held.
	player.falling = false     # Not falling while gliding
	player.ball = false
	player.crouch = false
	player.flying = true       # Glide flag — triggers handle_glide_physics every frame
	player.can_dash = false

	player.motion.y = clamp(player.motion.y, -200, 100)  # Gentle starting descent
	player.fall_gravity = 80                        # Much lower than default — nearly floating

	var glide_direction = sign(direction) if direction != 0 else (1 if player.sprite.flip_h == false else -1)
	if abs(player.motion.x) < 1100:
		# Only set speed if below the glide threshold; respects existing momentum
		player.motion.x = 1100 * glide_direction
		player.max_speed = 850   # Lower cap during glide to keep it controlled
		player.acc = 3000
		player.time_elapsed = 60

func _handle_glide_physics() -> void:
	if (player.flying and Input.is_action_pressed("ui_accept")) and not Input.is_action_just_released("ui_accept") and not player.is_on_wall():
		if player.ap.current_animation != "fly":
			player.ap.play("fly")
			player.ap.speed_scale = 1

		# Clamp vertical speed to a gentle glide descent range
		player.motion.y = clamp(player.motion.y, -100, 400)

		# Maintain forward horizontal momentum during glide
		var glide_direction = 1 if player.sprite.flip_h == false else -1
		if abs(player.motion.x) < 1100:
			player.motion.x = move_toward(player.motion.x, 1100 * glide_direction, player.acc * get_process_delta_time())

		# ── Glide End Conditions ───────────────────────────────────────
		if player.is_on_floor():
			# Landed — end glide and emit smoke
			player.flying = false
			player.fall_gravity = player.default
			player.can_dash = true
			player.smokeemit()
		elif player.is_on_wall():
			# Hit a wall — transition to wall-climb (handle_wall_mechanics takes over)
			player.flying = false
			player.fall_gravity = player.default
			player.can_dash = true
		elif not Input.is_action_pressed("ui_accept"):
			# Button released mid-glide — fall normally
			player.flying = false
			player.fall_gravity = player.default
			player.falling = true
