extends Player

@onready var fly_component: Node = $Fly
@onready var airspin_component: Node = $Airspin
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick

func handle_air_actions(is_grounded) -> void:
	if grinding == true:
		return
	fly_component.action()
	airspin_component.action()
	stomp_component.action()
	trick_component.action()
	
func handle_ground_action() -> void:
	pass
	
func handle_wall_mechanics() -> void:
	pass
