extends Player

@onready var fly_component: Node = $Fly
@onready var airspin_component: Node = $Airspin
@onready var airspinup_component: Components_Action = $Airspinup
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick
@onready var airspin_up_component: Components_Action = $Airspinup
@onready var ground_boost_component: Components_Action = $GroundBoost

func handle_air_actions(is_grounded) -> void:
	fly_component.action()
	airspin_up_component.action()
	airspin_component.action()
	stomp_component.action()
	trick_component.action()
	
func handle_ground_action() -> void:
	ground_boost_component.action()
	
func handle_wall_mechanics() -> void:
	pass
