extends Camera2D

@onready var player = get_node("/root/Node2D/PlayerController/CharacterBody2D")

func _process(_delta):
	global_position.x = player.global_position.x
