@tool
class_name GameContent
extends Resource
## Everything the game picks from: characters, boss fights and level chunks.
## The one list to edit when adding content. Open res://game_content.tres in the
## Inspector, or use the Sonic Escape panel in the editor (it fills this in for you).

## Playable characters, in the order they appear on the character select screen.
@export var characters: Array[CharacterEntry] = []
## Boss fights. Every 4th floor is a boss; the run goes through these in a random order.
## (The final boss on floor 20 is separate: Scenes/LevelChunks/Chunk_FinalBoss.tscn.)
@export var bosses: Array[BossEntry] = []
## Level chunks. Each floor strings random chunks from this list between the start and the end.
@export var level_chunks: Array[PackedScene] = []
