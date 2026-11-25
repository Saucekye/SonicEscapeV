extends Components_Action

@export var flymeter : TextureProgressBar
@export var fly_meter_drain : float = 1		## Number of units drained while flying
## Flying straight after an airspin keeps the airspin animation
@export var keep_airspin : bool = false

var was_flying : bool = false

func _process(_delta):
	# Sync the fly meter UI bar every frame
	flymeter.value = player.flymeter_current_amount  

func action() -> void:
	# Fly Two separate conditions
	if player.can_dash and player.flying and player.flymeter_amount >= 1 and player.inp_pressed("ui_accept") and (not player.inp_pressed("ui_down") or player.inp_pressed("ui_down")):
		_flight()
		was_flying = true
		player.flymeter.visible = true  # Show meter only while actively flying

	if player.inp_just_pressed("ui_accept") and (not player.inp_pressed("ui_down") or player.inp_pressed("ui_down")) and player.can_dash and not player.is_coyote_time_active():
		_flight()
		player.can_stomp = true
		_fly_anim()
		
	if !player.flying:
		player.fall_gravity = player.default

func _flight() -> void:
	# For this character, "dash" is actually the fly flutter —
	# each call flaps once, drains flymeter by 1, and applies a gentle upward push.
	# It's called repeatedly each frame while ui_accept is held.
	player.falling = true
	player.ball = false
	player.crouch = false
	player.flying = true
	player.flymeter_current_amount -= fly_meter_drain * Test.fly_drain_scale()	# Drain fly energy per flutter call
	_fly_anim()
	player.motion.y = -450            # Small upward push per flutter
	player.sfx.pitch_scale = 2
	player.fall_gravity = 700         # Reduced gravity while hovering (vs default ~1700+)
	player.is_boosting = false
	player.boost_sprite.visible = false
	GlobalCanvasLayer.boost = false
	# Disable further dashing if meter is depleted
	if player.flymeter_current_amount >= 1:
		player.can_dash = true
	else:
		player.can_dash = false
	


func _fly_anim() -> void:
	if keep_airspin and player.ap.current_animation == "airspin":
		return
	player.ap.play("fly")
