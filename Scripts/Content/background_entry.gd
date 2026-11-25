@tool
class_name BackgroundEntry
extends Resource
# A level background, as listed in game_content.tres

## The background scene
@export var scene: PackedScene
## Which stage look goes with it
@export_enum("Blue night:1", "Warm sunset:2", "Purple:4", "Red dusk:5") var style := 1
