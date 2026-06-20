extends Components_Action

@export var can_when_flying : bool = false
@export var meter_cost : int = 50
@export var await_time : float = 0.13
@export var time_elapsed : int = 200
@export var max_speed_startup : int = 1600
@export var max_speed_after_action : int = 1100
@export var y_sped : int = 650	## Y speed is automatically converted to negative value
@export var x_speed : int = 1200

func action() -> void:
	if not (player.is_player == true and Test.meter >= meter_cost and not Input.is_action_pressed("ui_down") and (not Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")) and Input.is_action_just_pressed("airspin") and player.direction != 0 and ((can_when_flying and not Input.is_action_pressed("dash")) or not player.flying)):
		return
	
	# Prevent from doing action while on wall
	if player.wall_cast.is_colliding() or player.wall_cast_2.is_colliding():
		return
		
	player.ap.play("airspin")
	player.time_elapsed = max_speed_startup
	player.max_speed = max_speed_startup
	player.can_dash = true
	player.can_stomp = true
	player.bounce = 0
	
	# Air horizontal boost — costs meter, launches in current direction with upward arc
	player.falling = true
	player.dashed = true
	player.ball = false
	if player.is_player == true:
		Test.meter -= meter_cost
	player.ap.play("airspin")
	player.motion.y = -abs(y_sped)
	player.fall_gravity = 0         # Brief gravity suspension for the spin hang-time
	player.spinaudio()
	player.smokeemit()
	player.max_speed = max_speed_after_action
	player.acc = 5000
	player.time_elapsed = time_elapsed
	player.motion.x = x_speed * sign(player.direction)
	await get_tree().create_timer(await_time).timeout
	player.fall_gravity = player.default
