extends Player

@onready var swipe_attack_component: Node = $SwipeAttack
@onready var flick_component: Node = $Flick
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick

func handle_air_actions(is_grounded) -> void:
	if grinding == true:
		return

	# ── Swipe Attack (air) ─────────────────────────────────────────
	# Only triggers when not already swiping
	if Input.is_action_just_pressed("airspin") and not Input.is_action_pressed("ui_down") and dashed == false and swipe == false:
		swipe_attack_component.action()
		
	# ── Air Dash (flick) ───────────────────────────────────────────
	if Input.is_action_just_pressed("ui_accept") and not Input.is_action_pressed("ui_down") and can_dash == true and not $CollisionShape2D/WallCast.is_colliding() and not $CollisionShape2D/WallCast2.is_colliding() and not is_coyote_time_active():
		flick_component.action()
		
	# ── Stomp (downward slam) ──────────────────────────────────────
	if Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_down") and can_stomp == true and not is_on_wall():
		stomp_component.action()
			
	# ── Trick ──────────────────────────────────────────────────────
	if Input.is_action_just_pressed("trick") and not (is_on_wall_only() and (not $CollisionShape2D/Raycast.is_colliding()) and rot == 0):
		trick_component.action()
	
func handle_ground_action() -> void:
	# ── Swipe Attack (grounded) ─────────────────────────────────────────
	# Only triggers when not already swiping
	if Input.is_action_just_pressed("airspin") and dashed == false and swipe == false:
		swipe_attack_component.action()
	
func handle_wall_mechanics() -> void:
	pass
