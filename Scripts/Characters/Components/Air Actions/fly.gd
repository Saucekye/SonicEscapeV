extends Components_Action

func action() -> void:
	# For this character, "dash" is actually the fly flutter —
	# each call flaps once, drains flymeter by 1, and applies a gentle upward push.
	# It's called repeatedly each frame while ui_accept is held.
	player.falling = true
	player.ball = false
	player.crouch = false
	player.flying = true
	player.flymeter_amount -= 1              # Drain one unit of fly energy per flutter call
	player.ap.play("fly")
	player.motion.y = -450            # Small upward push per flutter
	player.sfx.pitch_scale = 2
	player.fall_gravity = 700         # Reduced gravity while hovering (vs default ~1700+)

	# Disable further dashing if meter is depleted
	if player.flymeter_amount >= 1:
		player.can_dash = true
	else:
		player.can_dash = false
