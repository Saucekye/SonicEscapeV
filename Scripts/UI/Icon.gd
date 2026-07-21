extends Sprite2D

@onready var background_icon: Sprite2D = $"."
@onready var character_icon: Sprite2D = $"../Sprite2D2"
@onready var background_icon_player: AnimationPlayer = $"../AnimationPlayer"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalSignals.switch_new_active_player.connect(switch_icons)
	background_icon_player.play("play")
	
func switch_icons(new_player : Player) -> void:
	background_icon.texture = new_player.icon_background
	background_icon_player.play("play")
