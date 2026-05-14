extends Player

@onready var hover_component: Node = $Hover
@onready var airspin_component: Node = $Airspin
@onready var airup_component: Node = $Airup
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick
@onready var wall_jump_component: Node = $WallJump

func handle_air_actions(is_grounded) -> void:
	hover_component.action()
	airspin_component.action()
	airup_component.action()
	stomp_component.action()
	trick_component.action()

func handle_ground_action() -> void:
	pass

func handle_wall_mechanics() -> void:
	wall_jump_component.action()
