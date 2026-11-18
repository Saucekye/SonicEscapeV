extends Node

@export var is_running : bool = false
@export var push_strength_x : int = 100
@export var accel_push_strength : float = 0

const PULL_DIR : int = -1

var active_player: CharacterBody2D
var players
var pull_dir : Vector2 = Vector2.ZERO
var tween_strength : Tween
var current_push_strength_x : float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if accel_push_strength < 0:
		current_push_strength_x = push_strength_x
	process_mode = Node.PROCESS_MODE_DISABLED

func _physics_process(delta: float) -> void:
	players = get_tree().get_nodes_in_group("active_player")
		
	if accel_push_strength > 0 and current_push_strength_x < push_strength_x:
		current_push_strength_x += accel_push_strength * delta
	print(current_push_strength_x)
	for player in players:
		player.global_position.x += PULL_DIR * push_strength_x * delta
