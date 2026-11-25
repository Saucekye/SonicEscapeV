@tool
class_name GameContent
extends Resource
# Everything the game picks from

## Playable characters, in the order they appear on the character select screen
@export var characters: Array[CharacterEntry] = []
## Boss fights
@export var bosses: Array[BossEntry] = []
## Level chunks
@export var level_chunks: Array[PackedScene] = []
## Enemies to place in levels
@export var enemies: Array[PackedScene] = []

@export_group("Rescues")
## Miku's looks: one is picked each time a Miku appears
@export var miku_looks: Array[Texture2D] = []
## OCs: sometimes one turns up in place of a Miku
@export var ocs: Array[OcEntry] = []
## How often an OC turns up instead of a Miku
@export_range(0.0, 1.0, 0.01) var oc_chance := 0.1

@export_group("Floors")
## Songs that play during levels
@export var level_songs: Array[AudioStream] = []
## Level backgrounds
@export var level_backgrounds: Array[BackgroundEntry] = []
## How many level chunks make up a normal floor, counting the start and the goal
@export_range(3, 40) var chunks_per_floor := 6
