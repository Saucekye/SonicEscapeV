extends Components_Action

@export var speed_y : int = 1000
@export var fall_gravity : int = 10500
@export var bounce_one : float = 750
@export var bounce_two : float = 950
@export var bounce_three : float = 1100

func _physics_process(_delta: float) -> void:
	# ── Bounce Logic (from airdown / stomp) ────────────────────────────
	
	# Prevent player from doing action while on wall
	if player.wall_cast.is_colliding() or player.wall_cast_2.is_colliding():
		return
	
	if player.is_on_floor():
		if player.falling == false and player.next_bounce == false:
			player.bounce = 0  # Reset bounce counter when landing normally
			
		if Input.is_action_pressed("airspin"):
			# Holding airspin cancels the next bounce
			player.next_bounce = false
			player.can_stomp = true
			
		# Trigger the bounce height for consecutive stomps
		if player.next_bounce == true and player.falling == true:
			match player.bounce:
				1:
					player.motion.y = -bounce_one
				2:
					player.motion.y = -bounce_two
				_ when player.bounce >= 3: 
					player.motion.y = -bounce_three
			player.can_stomp = true

func action() -> void:
	if not (Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_down") and player.can_stomp == true and not player.is_on_wall()):
		return
	
	player.can_dash = true
	player.can_stomp = false
	
	# Stomp: slam straight down at high speed, set up for a bounce on landing
	player.bounce += 1
	player.next_bounce = true
	player.falling = true
	player.dashed = true
	player.can_dash = true
	player.flying = false
	player.time_elapsed = 0
	player.motion.y = speed_y
	player.ap.play("stomp")
	player.fall_gravity = fall_gravity     # Very high fall gravity for a fast, snappy slam
	player.sfx.pitch_scale = 2
	player.sfx.stream = load("res://Sounds/SonicSFX/Spiked.wav")
	player.sfx.play()
	player.motion.x = 0             # Cancel all horizontal momentum for a clean vertical drop
	await get_tree().create_timer(0.13).timeout
	player.fall_gravity = player.default
	player.dashx = true
	player.dashed = false
