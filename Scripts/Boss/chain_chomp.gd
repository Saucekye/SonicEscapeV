extends Node2D

@onready var timer: Timer = $Timer
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var positions : Array[Marker2D]

var speed : int = 700
var to_player : Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	global_position += to_player * speed * delta

func _on_timer_timeout() -> void:
	print(" GO GO GO GOG OGO GO GOGO GO")
	print(" GO GO GO GOG OGO GO GOGO GO")
	print(" GO GO GO GOG OGO GO GOGO GO")
	print(" GO GO GO GOG OGO GO GOGO GO")
	print(" GO GO GO GOG OGO GO GOGO GO")
	print(" GO GO GO GOG OGO GO GOGO GO")
	_do_attack()

func _do_attack():
	# Get a marker position to set to
	var position_index = randi() % positions.size()
	global_position = positions[position_index].global_position
	var current_player = _get_current_player()
	to_player = (current_player.global_position - global_position).normalized()
	
	if global_position.x < current_player.global_position.x:
		animated_sprite_2d.flip_h = false
	else:
		animated_sprite_2d.flip_h = true

func _get_current_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("Player")

	for player in players:
		if is_instance_valid(player) and player.get("is_player") == true:
			return player

	return null

func _on_goat_black_boss_defeated() -> void:
	queue_free()
