extends Player

@onready var glide_component: Node = $Glide
@onready var airup_component: Node = $Airup
@onready var airspin_component: Node = $Airspin
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick
@onready var wall_climb_component: Node = $WallClimb

func handle_air_actions(is_grounded) -> void:
	if grinding == true:
		return
	
	# ── Glide (hold jump while airborne) ──────────────────────────
	glide_component.action()
	
	# ── Air Spin (horizontal boost, costs meter) ───────────────────
	# Lower speed cap than Sonic's airspin (1300 vs 1200... actually 1300 here vs 1200 there)
	if is_player == true and Test.meter >= 50 and not Input.is_action_pressed("ui_down") and (not Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")) and Input.is_action_just_pressed("airspin") and direction != 0:
		airspin_component.action()
	
	# ── Air Up ─────────────────────────────────────────────────────
	if is_player == true and Test.meter >= 50 and ((Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_up")) or Input.is_action_just_pressed("airup")):
		airup_component.action()
		
	# ── Stomp ──────────────────────────────────────────────────────
	if Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_down") and can_stomp == true and not is_on_wall():
		stomp_component.action()
		
	if Input.is_action_just_pressed("trick") and not (is_on_wall_only() and (not $CollisionShape2D/Raycast.is_colliding()) and rot == 0) and flying == false:
		trick_component.action()

func handle_ground_action() -> void:
	pass

func handle_wall_mechanics() -> void:
	wall_climb_component.action()
