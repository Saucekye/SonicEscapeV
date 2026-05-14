extends Player

@onready var glide_component: Node = $Glide
@onready var airup_component: Node = $Airup
@onready var airspin_component: Node = $Airspin
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick
@onready var wall_climb_component: Node = $WallClimb

func handle_air_actions(is_grounded) -> void:
	glide_component.action()#
	airspin_component.action()	# Lower speed cap than Sonic's airspin (1300 vs 1200... actually 1300 here vs 1200 there)
	airup_component.action()
	stomp_component.action()
	trick_component.action()

func handle_ground_action() -> void:
	pass

func handle_wall_mechanics() -> void:
	wall_climb_component.action()
