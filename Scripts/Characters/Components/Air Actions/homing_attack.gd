extends Components_Action

@export var launch_y: float = 450
@export var min_launch_x : float = 1050

func action() -> void:
	if not (Input.is_action_just_pressed("ui_accept") and not Input.is_action_pressed("ui_down") and player.can_dash == true and not player.wall_cast.is_colliding() and not player.wall_cast_2.is_colliding() and not player.is_coyote_time_active()):
		return
	
	# Prevent from doing action while on wall
	if player.wall_cast.is_colliding() or player.wall_cast_2.is_colliding():
		return
	
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
	player.motion.y = -launch_y 
	player.fall_gravity = 0           # Disable gravity briefly for the dash hang-time
	player.smokeemit()
	player.sfx.pitch_scale = 2
	player.sfx.stream = load("res://Sounds/SonicSFX/SA_113.wav")
	player.sfx.play()

	# Only override speed if below dash threshold — respects existing momentum
	if abs(player.motion.x) <= min_launch_x:
		player.time_elapsed = 60
		player.max_speed = 1000
		player.acc = 5000
		player.motion.x = min_launch_x * sign(player.direction) if player.direction != 0 else min_launch_x * (1 if player.sprite.flip_h == false else -1)
	
	await get_tree().create_timer(0.13).timeout
	player.fall_gravity = player.default   # Restore gravity after dash hang
	player.dashx = true
	player.can_dash = false
