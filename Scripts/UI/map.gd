extends TileMapLayer

const DEFAULT_TEXTURE: Texture2D = preload("res://Sprites/Tileset/NewTilesetPlatform2-export.png")
const WHITE_TEXTURE: Texture2D = preload("res://Sprites/Tileset/Tileset White.png")
const DARK_BLUE_TEXTURE: Texture2D = preload("res://Sprites/Tileset/Dark Blue.png")
const BLUE_TEXTURE: Texture2D = preload("res://Sprites/Tileset/Blue.png")
const DARK_TEXTURE: Texture2D = preload("res://Sprites/Tileset/Dark.png")
const RED_TEXTURE: Texture2D = preload("res://Sprites/Tileset/Red.png")

func _ready():
	_swap_texture()
	# Boss arenas and rest stops: glowing cave dressing (boss_arena.gd)
	var scene_file: String = owner.scene_file_path.get_file() if owner else ""
	if scene_file.begins_with("Chunk_Boss") or scene_file.begins_with("Chunk_Rest") or scene_file == "Chunk_FinalBoss.tscn":
		preload("res://Scripts/Level/boss_arena.gd").apply.call_deferred(self)
		return
	# Dress the terrain with Sonic Rush Adventure tiles (rush_skin.gd)
	preload("res://Scripts/Level/rush_skin.gd").apply.call_deferred(self, Test.current_background)

func _swap_texture():
	if tile_set == null:
		push_error("TileSet is null!")
		return

	# Duplicate so we don’t modify shared resource
	tile_set = tile_set.duplicate()

	if tile_set.get_source_count() == 0:
		push_error("No sources in TileSet!")
		return

	# In your case you only have ONE atlas source, so it's index 0
	var source := tile_set.get_source(0) as TileSetAtlasSource
	if source == null:
		push_error("Source 0 is not a TileSetAtlasSource!")
		return

	# Swap texture
	match Test.current_background:
		1:
			source.texture = DEFAULT_TEXTURE
		2:
			source.texture = DARK_TEXTURE
		3:
			source.texture = BLUE_TEXTURE
		4:
			source.texture = DARK_TEXTURE
		5:
			source.texture = RED_TEXTURE
		6:
			source.texture = WHITE_TEXTURE
		
	tile_set.emit_changed()
