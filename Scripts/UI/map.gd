extends TileMapLayer

const DEFAULT_TEXTURE: Texture2D = preload("uid://cyfepbfpcsnnk")
const WHITE_TEXTURE: Texture2D = preload("uid://c0nh53qt2kem3")
const DARK_BLUE_TEXTURE: Texture2D = preload("uid://c445bptnbjv8h")
const BLUE_TEXTURE: Texture2D = preload("uid://benymv5usuft2")
const DARK_TEXTURE: Texture2D = preload("uid://0p2tvd4ht6t6")
const RED_TEXTURE: Texture2D = preload("uid://rk41slfbxvub")

func _ready():
	_swap_texture()

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
