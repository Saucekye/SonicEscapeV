extends Player

@onready var fly_component: Node = $Fly
@onready var airspin_component: Node = $Airspin
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick

func handle_air_actions(is_grounded) -> void:
	if grinding == true:
		return
	
	# ── Fly (hold jump while airborne) ────────────────────────────
	# Two separate conditions: sustained fly while holding, and initial press
	if can_dash == true and flying == true and flymeter_amount >= 1 and Input.is_action_pressed("ui_accept") and (not Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_down")):
		fly_component.action()
		flymeter.visible = true  # Show meter only while actively flying

	if Input.is_action_just_pressed("ui_accept") and (not Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_down")) and can_dash == true and not is_coyote_time_active():
		fly_component.action()
		can_stomp = true
		ap.play("fly")
			
	# ── Air Spin (horizontal boost, costs meter) ───────────────────
	if is_player == true and Test.meter >= 50 and not Input.is_action_pressed("ui_down") and (not Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")) and Input.is_action_just_pressed("airspin") and direction != 0:
		airspin_component.action()
		
	# ── Stomp (downward slam) ──────────────────────────────────────
	if Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_down") and can_stomp == true and not is_on_wall():
		stomp_component.action()
			
	# ── Trick ──────────────────────────────────────────────────────
	if Input.is_action_just_pressed("trick") and not (is_on_wall_only() and (not $CollisionShape2D/Raycast.is_colliding()) and rot == 0):
		trick_component.action()
	
func handle_ground_action() -> void:
	pass
	
func handle_wall_mechanics() -> void:
	pass
