extends Components_Action

@export var flymeter : TextureProgressBar
@export var fly_meter_drain : float = 1		## Number of units drained while flying

func _process(_delta):
	# Sync the fly meter UI bar every frame
	flymeter.value = player.flymeter_current_amount  

func action() -> void:
	# ── Fly (hold jump while airborne) ────────────────────────────
	# Two separate conditions: sustained fly while holding, and initial press
	if player.can_dash and player.flying and player.flymeter_amount >= 1 and Input.is_action_pressed("ui_accept") and (not Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_down")):
		_flight()
		player.flymeter.visible = true  # Show meter only while actively flying

	if Input.is_action_just_pressed("ui_accept") and (not Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_down")) and player.can_dash and not player.is_coyote_time_active():
		_flight()
		player.can_stomp = true
		player.ap.play("fly")

func _flight() -> void:
	# For this character, "dash" is actually the fly flutter —
	# each call flaps once, drains flymeter by 1, and applies a gentle upward push.
	# It's called repeatedly each frame while ui_accept is held.
	player.falling = true
	player.ball = false
	player.crouch = false
	player.flying = true
	player.flymeter_current_amount -= fly_meter_drain	# Drain one unit of fly energy per flutter call
	player.ap.play("fly")
	player.motion.y = -450            # Small upward push per flutter
	player.sfx.pitch_scale = 2
	player.fall_gravity = 700         # Reduced gravity while hovering (vs default ~1700+)

	# Disable further dashing if meter is depleted
	if player.flymeter_current_amount >= 1:
		player.can_dash = true
	else:
		player.can_dash = false
	
