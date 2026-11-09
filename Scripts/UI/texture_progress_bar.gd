extends TextureProgressBar

@export var player_path: NodePath
var player: Node
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not player_path.is_empty():
		player = get_node_or_null(player_path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		
	
	#pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.


	value = Test.meter
