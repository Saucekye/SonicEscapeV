extends Player

@onready var fly_component: Node = $Fly
@onready var airspin_component: Node = $Airspin
@onready var airspinup_component: Components_Action = $Airspinup
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick
@onready var homingattack_component: Node = $"Homing Attack"
@onready var ground_boost_component: Components_Action = $GroundBoost
@onready var wall_jump_component: Node = $WallJump

func handle_air_actions(is_grounded) -> void:
	# Don't Homing Attack if Down + ui_accept are pressed together
	if Input.is_action_just_pressed("ui_accept") and not Input.is_action_pressed("ui_down"):
		if homingattack_component.has_target():
			homingattack_component.action()
			return

	# Normal air actions
	fly_component.action()
	airspinup_component.action()
	airspin_component.action()
	stomp_component.action()
	trick_component.action()

func handle_ground_action() -> void:
	ground_boost_component.action()

func handle_wall_mechanics() -> void:
	pass


func _on_boost_animation_finished() -> void:
	$Boost.play("default")
