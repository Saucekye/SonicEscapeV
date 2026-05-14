extends Player

@onready var airspin_component: Node = $Airspin
@onready var flick_component: Node = $Flick
@onready var airup_component: Node = $Airup
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick
@onready var wall_jump_component: Node = $WallJump
@onready var drop_dash_component: Node = $DropDash
@onready var peelout_component: Node = $Peelout

func handle_air_actions(is_grounded) -> void:
	flick_component.action()
	airspin_component.action()
	airup_component.action()
	stomp_component.action()
	trick_component.action()

func handle_ground_action() -> void:
	drop_dash_component.action() 
	peelout_component.action()

func handle_wall_mechanics() -> void:
	wall_jump_component.action()
