extends Label


@export var player_path: NodePath
var player: Node
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_node(player_path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if text == "000":
		$AnimationPlayer.play("Low")
	else:
		$AnimationPlayer.play("RESET")
	text = str(Test.rings).pad_zeros(3)
