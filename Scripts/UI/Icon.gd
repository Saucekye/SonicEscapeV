extends Sprite2D

@onready var background_icon: Sprite2D = $"."
@onready var character_icon: Sprite2D = $"../Sprite2Dicon"
@onready var background_icon_player: AnimationPlayer = $"../AnimationPlayer"

var character_icon_player_original_position : Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalSignals.switch_new_active_player.connect(switch_icons)
	#character_icon_player_original_position = character_icon_player.global_position
	var new_player : Player = get_tree().get_first_node_in_group("active_player")
	switch_icons(new_player)
	# Keep the player icon clear of the CRT filter (crt_overlay.gd)
	if Test.crt and Test.crt.has_method("exclude"):
		Test.crt.call("exclude", [background_icon, character_icon])
	
func switch_icons(new_player : Player) -> void:
	character_icon.texture = new_player.icon_character
	#character_icon_player.global_position = character_icon_player_original_position
	#character_icon_player.global_position += new_player.icon_character_position_adjust
	#character_icon.position = Vector2(80, 45)	
	background_icon.texture = new_player.icon_background
	background_icon_player.play("play")
