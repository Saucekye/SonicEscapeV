@tool
class_name CharacterEntry
extends Resource
# A playable character, as listed in game_content.tres

## Name used in saves
@export var id := "NewCharacter"
## The character scene
@export var scene: PackedScene

@export_group("Super")
## The character's super form
@export var super_scene: PackedScene

@export_group("Character Select")
## Portrait shown on the character select screen
@export var select_icon: Texture2D
## Portrait shown while the character is hovered or picked
@export var select_icon_active: Texture2D
## Picture behind the portrait once picked
@export var select_highlight: Texture2D
@export var hover_color := Color(1, 1, 1)

# Custom characters
var custom_dir := ""       # their folder
var display_name := ""     # the name to show
var base_id := ""          # whose moves it has
