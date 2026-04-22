extends Player

@onready var swipe_attack_component: Node = $SwipeAttack
@onready var flick_component: Node = $Flick
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick

func handle_air_actions(is_grounded) -> void:
	if grinding == true:
		return
	swipe_attack_component.action()
	flick_component.action()
	stomp_component.action()
	trick_component.action()
	
func handle_ground_action() -> void:
	# Only triggers when not already swiping
	swipe_attack_component.action()
	
func handle_wall_mechanics() -> void:
	pass
