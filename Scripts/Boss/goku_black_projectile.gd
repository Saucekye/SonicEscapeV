extends Node2D

@onready var timer: Timer = $Timer
@onready var attackbox: Area2D = $Attackbox

@export var lifetime : int = 10

const PROJECTILE_SCALE : float = 3.0

var current_player
var start_speed : int = 600
var decelerration : int = 500
var base_speed : int = 400
var speed : int = start_speed

func _ready() -> void:
	timer.start(lifetime)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	current_player = _get_current_player()
	var to_player = (current_player.global_position- global_position).normalized()
	global_position += to_player * speed * delta
	if speed > base_speed:
		speed -= int(decelerration * delta)

func _get_current_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("Player")

	for player in players:
		if is_instance_valid(player) and player.get("is_player") == true:
			return player

	return null

func _on_timer_timeout() -> void:
	attackbox.monitoring = false
	attackbox.monitorable = false
	# tween until it disappears
	var tween_fade = get_tree().create_tween()
	tween_fade.tween_property(self, "modulate:a", 0, 0.333)
	await tween_fade.finished
	queue_free()
