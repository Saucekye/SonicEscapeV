extends Components_Action

@export var meter_cost : int = 50
@export var launch_speed : int = 1100	## The y velocity the player is launched up, the value is automatically made neative.

func action() -> void:
	if not (player.is_player == true and Test.meter >= meter_cost and ((Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_up")) or Input.is_action_just_pressed("airup")) and not player.flying):
		return
	
	# Prevent character from doing action while on wall
	if player.wall_cast.is_colliding() or player.wall_cast_2.is_colliding():
		return
		
	player.can_dash = true
	player.can_dash = true
	player.can_stomp = true
	player.bounce = 0
	
	# Air vertical boost — costs meter, launches straight up
	player.dashed = true
	player.ball = false
	if player.is_player == true:
		Test.meter -= meter_cost
	player.ap.play("airup")
	player.motion.y = -abs(launch_speed)
	player.spinaudio()
	player.smokeemit()
	await get_tree().create_timer(0.13).timeout
	player.fall_gravity = player.default
	await get_tree().create_timer(0.3).timeout  # Small delay before entering "falling" state
	player.falling = true
	# The awaits can interrupt the death animation,
	# Only enter falling animation if last animation was airup
	if player.last_animation == "airup":
		player.ap.play("falling")
	
