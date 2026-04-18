extends Components_Action

func action() -> void:
	# ── Glide (hold jump while airborne) ──────────────────────────
	if player.flying == true and Input.is_action_pressed("ui_accept"):
		_handle_hover_physics()
	else:
		# Not actively gliding — resume normal falling
		player.flying = false
		player.fall_gravity = player.default
		player.falling = true

	# Initial jump press in air starts the glide
	if Input.is_action_just_pressed("ui_accept") and not Input.is_action_pressed("ui_down") and not player.is_coyote_time_active():
		_dash(player.direction if player.direction != 0 else (1 if not player.sprite.flip_h else -1))

# ─────────────────────────────────────────────
# Hover Physics
# Called every frame while flying is true and jump is held.
# Uses "flick" animation (not "fly" like Knuckles).
# ─────────────────────────────────────────────
func _handle_hover_physics():
	if (player.flying and Input.is_action_pressed("ui_accept")) and not Input.is_action_just_released("ui_accept") and not player.is_on_wall():
		if player.ap.current_animation != "flick":
			player.ap.play("flick")
			player.ap.speed_scale = 1

		# Clamp descent speed for a gentle float
		player.motion.y = clamp(player.motion.y, -100, 400)

		# BUG: glide_direction is calculated here but never applied to motion.x
		# Forward momentum during glide relies entirely on whatever motion.x was when glide started
		# TODO: add  motion.x = move_toward(motion.x, 1100 * glide_direction, acc * delta)
		var glide_direction = 1 if player.sprite.flip_h == false else -1

		# ── Glide End Conditions ───────────────────────────────────────
		if player.is_on_floor():
			player.flying = false
			player.fall_gravity = player.default
			player.can_dash = true
			player.smokeemit()
		elif player.is_on_wall():
			# Wall contact ends glide — wall mechanics will take over next frame
			player.flying = false
			player.fall_gravity = player.default
			player.can_dash = true
		elif not Input.is_action_pressed("ui_accept"):
			# Button released mid-glide — resume falling
			player.flying = false
			player.fall_gravity = player.default
			player.falling = true

func _dash(direction):
	# Initiates the glide — sets flying = true so handle_glide_physics runs each frame.
	# Unlike Knuckles, this version sets speed caps but does NOT set motion.x directly.
	# BUG: glide_direction is computed but never applied — the character won't gain
	#      forward momentum from the glide start unless they were already moving.
	# TODO: add  motion.x = 1100 * glide_direction  if abs(motion.x) < 1100
	player.falling = false
	player.ball = false
	player.crouch = false
	player.flying = true
	player.can_dash = false

	player.motion.y = clamp(player.motion.y, -200, 100)  # Gentle starting descent
	player.fall_gravity = 80                        # Very low gravity while gliding

	var glide_direction = sign(player.direction) if player.direction != 0 else (1 if player.sprite.flip_h == false else -1)
	if abs(player.motion.x) < 1100:
		# Speed cap and momentum are set, but motion.x is never assigned here
		player.max_speed = 850
		player.acc = 3000
		player.time_elapsed = 60
