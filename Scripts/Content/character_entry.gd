@tool
class_name CharacterEntry
extends Resource
## A playable character, as listed in game_content.tres.

## Name used in saves, online and co-op. Keep it short and unique, without spaces.
@export var id := "NewCharacter"
## The character scene (a copy of a character from Scenes/Characters/).
@export var scene: PackedScene

@export_group("Character Select")
## Portrait shown on the character select screen.
@export var select_icon: Texture2D
## Portrait shown while the character is hovered or picked.
@export var select_icon_active: Texture2D
## Picture behind the portrait once picked (the coloured banner).
@export var select_highlight: Texture2D
@export var hover_color := Color(1, 1, 1)
