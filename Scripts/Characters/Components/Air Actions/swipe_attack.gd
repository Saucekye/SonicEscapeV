extends Components_Action

func action() -> void:
	if not (Input.is_action_just_pressed("airspin") and not Input.is_action_pressed("ui_down") and not player.dashed and not player.swipe):
		return
	
	# Swipe attack — short animation window that damages enemies on contact.
	# Sets swipe = true so the attackbox and animations know an attack is active.
	player.swipe = true
	player.dashed = true
	player.flying = false   # Cancel flight during the attack
	player.ball = false
	player.crouch = false
	player.ap.play("swipe")
	await get_tree().create_timer(0.25).timeout  # Attack active window
	player.dashed = false
	player.falling = false
	player.swipe = false
	player.fall_gravity = player.default
