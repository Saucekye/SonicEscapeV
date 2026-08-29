extends Player

@onready var fly_component: Node = $Fly
@onready var airspin_component: Node = $Airspin
@onready var airspinup_component: Components_Action = $Airspinup
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick
@onready var airspin_up: Components_Action = $AirspinUp

func handle_air_actions(is_grounded) -> void:
	fly_component.action()
	airspinup_component.action()
	airspin_component.action()
	stomp_component.action()
	trick_component.action()
	
func handle_ground_action() -> void:
	pass
	
func handle_wall_mechanics() -> void:
	pass
