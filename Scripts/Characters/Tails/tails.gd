extends Player

@onready var fly_component: Node = $Fly
@onready var swipe_attack_component: Node = $SwipeAttack
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick

func handle_air_actions(is_grounded) -> void:
	fly_component.action()
	swipe_attack_component.action()
	stomp_component.action()
	trick_component.action()

func handle_ground_action() -> void:
	# Only triggers when not already swiping
	swipe_attack_component.action()

func handle_wall_mechanics() -> void:
	pass
