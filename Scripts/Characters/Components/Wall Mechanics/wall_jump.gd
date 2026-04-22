extends Components_Action

func action() -> void:
	# Wall-slide and wall-jump logic — only fires when pressing against a wall in the air
	if (not player.wall_cast.is_colliding() and not player.wall_cast_2.is_colliding()) or (player.raycast.is_colliding()) or not player.rot == 0:
		return
	if player.is_player == true:
		player.tricknumber()
		GlobalCanvasLayer.tricks = 0
	player.falling = false
	player.dashed = false
	player.ball = false
	player.crouch = false
	player.flying = false             # Blaze's glide ends when hitting a wall
	player.motion.y = (player.motion.y)/1.3  # Slow the fall while on the wall
	player.ap.play("onwallair")
	
	# Flip sprite to face away from the wall
	if player.wall_cast.is_colliding():
		player.sprite.flip_h = true
	else:
		player.sprite.flip_h = false
	
	var wall_normal = player.get_wall_normal()
	var push_dir = 1 if wall_normal.x > 0 else -1  # Direction away from the wall
	
	if (Input.is_action_just_pressed("ui_accept")):
		# Wall jump: push away from wall and launch upward
		player.position += Vector2(push_dir * 25, 0).rotated(player.rot)
		player.motion.x = 2500 * push_dir
		player.motion.y = (player.jump_velocity) / 1.5
		player.just_wall_jumped = true
