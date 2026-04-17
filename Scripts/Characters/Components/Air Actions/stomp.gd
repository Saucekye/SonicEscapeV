extends Components_Action

func action() -> void:
	player.can_dash = true
	player.can_stomp = false
	
	# Stomp: slam straight down at high speed, set up for a bounce on landing
	player.bounce += 1
	player.next_bounce = true
	player.falling = true
	player.dashed = true
	player.can_dash = true
	player.time_elapsed = 0
	player.motion.y = 1000
	player.ap.play("stomp")
	player.fall_gravity = 10500     # Very high fall gravity for a fast, snappy slam
	player.sfx.pitch_scale = 2
	player.sfx.stream = load("res://Sounds/SonicSFX/Spiked.wav")
	player.sfx.play()
	player.motion.x = 0             # Cancel all horizontal momentum for a clean vertical drop
	await get_tree().create_timer(0.13).timeout
	player.fall_gravity = player.default
	player.dashx = true
	player.dashed = false
