extends Marker2D


# Called when the node enters the scene tree for the first time.
@onready var player = get_parent().get_node("CharacterBody2D")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position.x = player.position.x-10
