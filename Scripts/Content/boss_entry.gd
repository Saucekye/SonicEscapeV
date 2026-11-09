@tool
class_name BossEntry
extends Resource
## A boss fight, as listed in game_content.tres.

@export var display_name := "New Boss"
## The arena scene: the room, the boss and its health bar (see Scenes/LevelChunks/Chunk_Boss*.tscn).
@export var arena: PackedScene
## Turn off to keep the boss out of the run while it's being made.
@export var enabled := true
