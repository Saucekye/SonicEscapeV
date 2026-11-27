@abstract
class_name Components_Action extends Node

var player: Player
## How hard the screen shakes when this move goes off
@export var air_shake := 2.5
## How long that shake lasts
@export var air_shake_time := 0.12

func _ready() -> void:
	player = self.get_parent()

@abstract
func action() -> void


# A little screen shake when an air move goes off
func shake_a_little(scale := 1.0) -> void:
	if air_shake <= 0.0 or player == null or not player.is_player:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null or not cam.has_method("kick"):
		cam = player.get_viewport().get_camera_2d()
	if cam and cam.has_method("kick"):
		cam.kick(air_shake * scale, air_shake_time)
