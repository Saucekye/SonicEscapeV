extends Player

@onready var airspin_component: Node = $Airspin
@onready var flick: Node = $Flick
@onready var airup_component: Node = $Airup
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick

func handle_air_actions(is_grounded):
	if grinding == false:
		# ── Air Dash (flick) ───────────────────────────────────────────
		if Input.is_action_just_pressed("ui_accept") and not Input.is_action_pressed("ui_down") and can_dash == true and not $CollisionShape2D/WallCast.is_colliding() and not $CollisionShape2D/WallCast2.is_colliding() and not is_coyote_time_active():
			flick.action()
			print("OOOOOOOIIIIIIIIIIEEEEEEEEEAAAAAAAAAAAAAAAAA2")
				
		# ── Air Spin (horizontal boost, costs meter) ───────────────────
		if is_player == true and Test.meter >= 50 and not Input.is_action_pressed("ui_down") and (not Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")) and Input.is_action_just_pressed("airspin") and direction != 0:
			airspin_component.action()
			print("OOOOOOOIIIIIIIIIIEEEEEEEEEAAAAAAAAAAAAAAAAA")
				
		# ── Air Up (vertical boost, costs meter) ──────────────────────
		if is_player == true and Test.meter >= 50 and ((Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_up")) or Input.is_action_just_pressed("airup")):
			airup_component.action()
			
		# ── Stomp (downward slam) ──────────────────────────────────────
		if Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_down") and can_stomp == true and not is_on_wall():
			stomp_component.action()
				
		# ── Trick ──────────────────────────────────────────────────────
		if Input.is_action_just_pressed("trick") and not (is_on_wall_only() and (not $CollisionShape2D/Raycast.is_colliding()) and rot == 0):
			trick_component.action()
