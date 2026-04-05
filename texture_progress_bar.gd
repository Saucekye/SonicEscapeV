extends TextureProgressBar

@export var player_path: NodePath
var player: Node
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_node(player_path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		
	
	#pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.


	value = Test.meter
