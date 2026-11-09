class_name SalvageItem
extends Resource
## One kind of item in the Salvage mini game. Each is a file in Scenes/Salvage/Items/;
## the Salvage scene's "Item Kinds" list picks which ones can turn up. Duplicate a
## file to make a new kind.
## Items are flat sprites that turn to face you, like the characters. Put your art in
## Texture; until then a basic shape in the item's colour stands in for it.

@export var display_name := "Item"
@export var cost := 5            ## rings it takes to salvage
@export var value := 30          ## what it's worth when you get it out
@export var texture: Texture2D   ## the item's picture (empty = the placeholder shape below)
@export var height := 0.5        ## how tall it stands, in metres
@export_group("Placeholder")
@export_enum("square", "circle", "triangle", "diamond") var shape := "square"
@export var color := Color(0.6, 0.6, 0.6)
