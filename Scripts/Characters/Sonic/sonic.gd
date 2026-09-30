extends Player

@onready var airspin_component: Node = $Airspin
@onready var flick_component: Node = $Flick
@onready var homingattack_component: Node = $HomingAttack
@onready var airup_component: Node = $Airup
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick
@onready var wall_jump_component: Node = $WallJump
@onready var drop_dash_component: Node = $DropDash
@onready var peelout_component: Node = $Peelout
@onready var ground_boost_component: Components_Action = $GroundBoost


func handle_air_actions(is_grounded) -> void:
	# Don't Homing Attack if Down + ui_accept are pressed together
	if Input.is_action_just_pressed("ui_accept") and not Input.is_action_pressed("ui_down"):
		if homingattack_component.has_target():
			homingattack_component.action()
			return

	# Normal air actions
	flick_component.action()
	airspin_component.action()
	airup_component.action()
	stomp_component.action()
	trick_component.action()


func handle_ground_action() -> void:
	drop_dash_component.action()
	peelout_component.action()
	ground_boost_component.action()


func handle_wall_mechanics() -> void:
	wall_jump_component.action()


func _on_boost_animation_finished() -> void:
	$Boost.play("default")
