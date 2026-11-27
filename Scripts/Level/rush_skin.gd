extends RefCounted
# Dresses the terrain with Sonic Rush tiles, painted straight onto the tiles' own shapes,
# in colours taken from the stage's background

const SKIN_SHADER := preload("res://Shaders/terrain_skin.gdshader")
const ART := "res://Sprites/Tileset/RushAdventure/"
const TEXEL_WORLD := 1.125   # world units per art pixel, same as the characters
const SHADE_DEPTH := 40.0    # art pixels of darkening under the surface
const SHADE_STRENGTH := 0.45 # how dark it starts
const ENV_BLEND := 0.6       # how far the colours move to the background's

# Background id
const STAGES := {
	1: {"zone": "neon_tech"},
	2: {"zone": "brick_ruins"},
	4: {"zone": "roof_town"},
	5: {"zone": "industrial"},
}

static var _env := {}        # background id -> [shadow, light]
static var _shapes := {}     # tile source texture + tile -> its picture


static func apply(layer: TileMapLayer, background_id: int, with_surfaces: bool = true) -> void:
	if not Test.rush_terrain or not STAGES.has(background_id) or not is_instance_valid(layer):
		return
	var stage: Dictionary = STAGES[background_id]
	var fill: Texture2D = load(ART + stage.zone + "_fill.png")
	var strip: Texture2D = load(ART + stage.zone + "_surface.png")
	var mask := _mask(layer)
	if fill == null or strip == null or mask.is_empty():
		return
	var env: Array = _env_colours(layer, background_id)
	var m := ShaderMaterial.new()
	m.shader = SKIN_SHADER
	m.set_shader_parameter("mask_tex", ImageTexture.create_from_image(mask.image))
	m.set_shader_parameter("mask_origin", mask.origin)
	var xf := layer.get_global_transform()
	m.set_shader_parameter("layer_origin", xf.origin)
	m.set_shader_parameter("layer_scale", xf.get_scale())
	m.set_shader_parameter("fill_tex", fill)
	m.set_shader_parameter("fill_size", float(fill.get_height()))
	m.set_shader_parameter("fill_count", float(fill.get_width()) / float(fill.get_height()))
	m.set_shader_parameter("strip_tex", strip)
	m.set_shader_parameter("strip_size", Vector2(strip.get_size()))
	m.set_shader_parameter("surfaces", with_surfaces)
	m.set_shader_parameter("texel_world", TEXEL_WORLD)
	# Art pixels in one of the layer's own pixels
	m.set_shader_parameter("art_per_px", absf(layer.get_global_transform().get_scale().y) / TEXEL_WORLD)
	m.set_shader_parameter("shade_depth", SHADE_DEPTH)
	m.set_shader_parameter("shade_strength", SHADE_STRENGTH)
	m.set_shader_parameter("env_shadow", env[0])
	m.set_shader_parameter("env_light", env[1])
	m.set_shader_parameter("env_blend", ENV_BLEND)
	layer.material = m


# Where the layer is solid, one pixel per tile pixel, with clear tiles above and below
static func _mask(layer: TileMapLayer) -> Dictionary:
	var used := layer.get_used_rect()
	if used.size == Vector2i.ZERO or layer.tile_set == null:
		return {}
	var ts: Vector2i = layer.tile_set.tile_size
	var pad := Vector2i(0, 2)
	var cells := used.size + pad * 2
	var img := Image.create(cells.x * ts.x, cells.y * ts.y, false, Image.FORMAT_RGBA8)
	for cell in layer.get_used_cells():
		var pic := _tile_picture(layer, cell)
		if pic:
			img.blit_rect(pic, Rect2i(Vector2i.ZERO, ts), (cell - used.position + pad) * ts)
	# In the layer's own pixels (cell (0, 0) starts at its origin)
	return {"image": img, "origin": Vector2((used.position - pad) * ts)}


static func _tile_picture(layer: TileMapLayer, cell: Vector2i) -> Image:
	var source_id := layer.get_cell_source_id(cell)
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or source.texture == null:
		return null
	var coords := layer.get_cell_atlas_coords(cell)
	var alt := layer.get_cell_alternative_tile(cell)
	var key := [source.texture.resource_path, coords, alt]
	if _shapes.has(key):
		return _shapes[key]
	var sheet_key := [source.texture.resource_path]
	if not _shapes.has(sheet_key):
		var sheet := source.texture.get_image()
		if sheet.is_compressed():
			sheet.decompress()
		sheet.convert(Image.FORMAT_RGBA8)
		_shapes[sheet_key] = sheet
	var region := source.get_tile_texture_region(coords)
	var pic: Image = (_shapes[sheet_key] as Image).get_region(region)
	var td := source.get_tile_data(coords, alt & 0xFFF)
	var flip_h := (alt & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
	var flip_v := (alt & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
	var transpose := (alt & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	if td:
		flip_h = flip_h != td.flip_h
		flip_v = flip_v != td.flip_v
		transpose = transpose != td.transpose
	if transpose:
		pic.rotate_90(CLOCKWISE)
		pic.flip_x()
	if flip_h:
		pic.flip_x()
	if flip_v:
		pic.flip_y()
	_shapes[key] = pic
	return pic


# The background's darkest and brightest colours, so the ground is lit like it
static func _env_colours(layer: TileMapLayer, background_id: int) -> Array:
	if _env.has(background_id):
		return _env[background_id]
	var samples: Array[Color] = []
	var scene := layer.get_tree().current_scene if layer.is_inside_tree() else null
	var bg_root: Node = scene.find_child("Background", true, false) if scene else null
	if bg_root:
		for n in bg_root.find_children("*", "Sprite2D", true, false):
			var tex: Texture2D = n.texture
			if tex == null:
				continue
			var img := tex.get_image()
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(24, 24, Image.INTERPOLATE_NEAREST)
			var tint: Color = n.modulate * n.self_modulate
			for y in 24:
				for x in 24:
					var c := img.get_pixel(x, y)
					if c.a > 0.5:
						samples.append(c * tint)
	if samples.size() < 20:
		_env[background_id] = [Color(0.1, 0.1, 0.12), Color(0.9, 0.9, 0.9)]
		return _env[background_id]
	samples.sort_custom(func(a, b): return a.get_luminance() < b.get_luminance())
	var n := maxi(samples.size() / 6, 1)
	var dark := Color(0, 0, 0)
	var light := Color(0, 0, 0)
	for i in n:
		dark += samples[i]
		light += samples[samples.size() - 1 - i]
	dark /= float(n)
	light /= float(n)
	dark.a = 1.0
	light.a = 1.0
	_env[background_id] = [dark, light]
	return _env[background_id]
