extends Components_Action

@onready var boost_startaudio: AudioStreamPlayer = $BoostStartaudio

@export var max_speed_startup : int = 1600
@export var x_speed_increase : int = 10
@export var meter_cost_inital : float = 10
@export var meter_cost : float = 0.5

func action() -> void:
	if Test.meter < meter_cost or (Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")) or (!Input.is_action_pressed("airspin") or player.direction == 0):
		player.boost.visible = false
		GlobalCanvasLayer.boost = false
		return
	
	# Prevent from doing action while on wall
	if player.wall_cast.is_colliding() or player.wall_cast_2.is_colliding():
		return
		
	# Starting the dash comes at a greater cost
	if Input.is_action_just_pressed("airspin") and Test.meter < meter_cost_inital:
			return
		
	#  Allow teammates to boost too, but do not consume meter
	if player.is_player:
		Test.meter -= meter_cost
		
	if Input.is_action_just_pressed("airspin"):
		player.motion.x = max_speed_startup * player.direction
		if player.is_player:
			Test.meter -= 25
			if Test.meter <= 0:
				Test.meter = 0
			boost_startaudio.play()
			player.boost.visible = true
			player.boost.play("shockwave")
			GlobalCanvasLayer.boost = true
			GlobalSignals.emit_signal("camerashake")
	else:
		player.motion.x += x_speed_increase * player.direction
		
