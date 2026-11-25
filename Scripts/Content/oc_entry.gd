@tool
class_name OcEntry
extends Resource
# An OC who can turn up in place of a Miku, as listed in game_content.tres

## Their sprite sheet
@export var picture: Texture2D
## Shown above them
@export var credit := ""
## Make them bigger or smaller
@export var size := 1.0
