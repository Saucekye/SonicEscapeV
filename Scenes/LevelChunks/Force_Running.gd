extends Node2D

@onready var end: Marker2D = $"../End"

const PULL_DIR : int = -1
const PULL_STRENGTH : int = 100

var active_player: CharacterBody2D
var pull_dir : Vector2
var players

func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("active_player")
	for player in players:
		#if player != null and is_instance_valid(Player):	
			#pull_dir = (end.global_position - player.global_position).normalized()
			#player.global_position += pull_dir * PULL_STRENGTH * delta
		player.global_position.x -= 100 * delta
