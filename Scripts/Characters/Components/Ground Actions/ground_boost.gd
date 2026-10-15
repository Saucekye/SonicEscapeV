extends Components_Action

@onready var boost_startaudio: AudioStreamPlayer = $BoostStartaudio

@export var max_speed_startup : int = 1500
@export var x_speed_increase : int = 15
@export var meter_cost_inital : float = 5
@export var meter_cost : float = 0.3

func action() -> void:
	if Test.meter < meter_cost or player.ball or player.grinding or (Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")) or (!Input.is_action_pressed("airspin") or player.direction == 0):
		player.boost_sprite.visible = false
		GlobalCanvasLayer.boost = false
		player.is_boosting = Input.is_action_pressed("airspin") and player.is_boosting
		return
	
	# Prevent from doing action while on wall
	if player.wall_cast.is_colliding() or player.wall_cast_2.is_colliding():
		player.is_boosting = false
		player.boost_sprite.visible = false
		GlobalCanvasLayer.boost = false
		return
		
	# Functionality if boost is pressed after all the conditions are met
	if Input.is_action_just_pressed("airspin"):
		# Starting the dash comes at a greater cost	
		if Test.meter < meter_cost_inital:
			player.is_boosting = false
			return
		if player.is_player:
			Test.meter -= meter_cost_inital
			boost_startaudio.play()
			player.boost_sprite.play("shockwave")
			GlobalSignals.emit_signal("camerashake")
		player.motion.x = max_speed_startup * player.direction
		player.is_boosting = true
	elif player.is_boosting:
		if player.is_player:
			player.boost_sprite.visible = true
			GlobalCanvasLayer.boost = true
		player.motion.x += x_speed_increase * player.direction
	else:
		player.boost_sprite.visible = false
		GlobalCanvasLayer.boost = false
		
	#  Allow teammates to boost too, but do not consume meter for them
	if player.is_player and player.is_boosting:
		Test.meter -= meter_cost
		
	if Test.meter <= 0:
		Test.meter = 0
