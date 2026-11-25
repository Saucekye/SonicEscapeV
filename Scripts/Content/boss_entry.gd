@tool
class_name BossEntry
extends Resource
# A boss fight, as listed in game_content.tres

@export var display_name := "New Boss"
## The arena scene
@export var arena: PackedScene
## Turn off to keep the boss out of the run while it's being made
@export var enabled := true
