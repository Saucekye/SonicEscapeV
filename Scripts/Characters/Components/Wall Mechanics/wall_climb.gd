extends Components_Action

func action() -> void:
	if (not player.wall_cast.is_colliding() and not player.wall_cast_2.is_colliding()) or (player.raycast.is_colliding()) or player.rot != 0:
		return
		
	if player.is_player == true:
		player.tricknumber()
		GlobalCanvasLayer.tricks = 0

	print("ON WALL - Current animation: ", player.ap.current_animation)

	# Cancel all special states when grabbing a wall
	player.falling = false
	player.dashed = false
	player.ball = false
	player.crouch = false
	player.flying = false  # Glide ends on wall contact (transitions to climb)

	# ── Wall Climbing ──────────────────────────────────────────────
	if Input.is_action_pressed("ui_up"):
		player.motion.y = -280         # Climb upward
		player.ap.play("climb")
		player.ap.speed_scale = 1.0
	elif Input.is_action_pressed("ui_down"):
		player.motion.y = 280          # Slide down
		player.ap.play("climb")
		player.ap.speed_scale = -1.0   # Reverse animation when sliding down
	else:
		player.motion.y = 0            # Hold in place
		player.ap.play("climb")
		player.ap.speed_scale = 0.0    # Freeze animation when idle on wall

	# Face away from the wall
	if player.wall_cast.is_colliding():
		player.sprite.flip_h = true
	else:
		player.sprite.flip_h = false

	var wall_normal = player.get_wall_normal()
	var push_dir = 1 if wall_normal.x > 0 else -1

	if (Input.is_action_just_pressed("ui_accept")):
		# Wall jump — push away and launch upward, then restore dash
		player.can_dash = true
		player.position += Vector2(push_dir * 25, 0).rotated(player.rot)
		player.motion.x = 2500 * push_dir
		player.motion.y = (player.jump_velocity) / 1.5
		player.just_wall_jumped = true
		player.ap.speed_scale = 1.0
