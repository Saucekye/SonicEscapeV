extends RefCounted
## Boss arena dressing in the spirit of Animal Well's glowing caves (original
## art, drawn in code by Shaders/boss_arena.gdshader): carved ground, glowing
## edges with a halo and fireflies (the fireflies only
## with Effects on).
## The tiles are hidden but keep their collisions, so the arena plays the same.
## Called from map.gd for the terrain of every boss chunk (Chunk_Boss*.tscn and
## Chunk_FinalBoss.tscn) and rest stop (Chunk_Rest*.tscn), so they share one look.

const SHADER := preload("res://Shaders/boss_arena.gdshader")
const CHARACTER_LIGHT := preload("res://Scenes/Effects/boss_character_light.tscn")
## Boss fights: the blue parts of the arena (glow lines, halo, wave rows, bricks)
## fade to these reds as the fight starts. Rest stops stay blue.
const RED_FADE := 1.2   # seconds
const WATER_EXTEND := 120   # tiles the boss water reaches past each arena wall (covers any screen width)
const BOSS_REDS := {
	"floor_line": Color(1.0, 0.55, 0.47),
	"floor_line2": Color(0.78, 0.18, 0.14),
	"wall_line": Color(1.0, 0.3, 0.24),
	"wall_line2": Color(0.62, 0.09, 0.09),
	"fill_base": Color(0.07, 0.016, 0.02),
	"wave_color": Color(0.58, 0.15, 0.17),
	"brick_color": Color(0.48, 0.13, 0.18),
	"halo_color": Color(1.0, 0.25, 0.16),
}
const TILE := 16
const MARGIN := 3   # tiles of air drawn around the terrain, for the halo


static func apply(layer: TileMapLayer) -> void:
	if layer.has_node("ArenaDress"):
		return
	var used := layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var area := used.grow(MARGIN)
	# Which tiles are solid, one pixel per tile
	var img := Image.create(area.size.x, area.size.y, false, Image.FORMAT_L8)
	for cell in layer.get_used_cells():
		img.set_pixel(cell.x - area.position.x, cell.y - area.position.y, Color.WHITE)
	var occ := ImageTexture.create_from_image(img)

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("occ", occ)
	mat.set_shader_parameter("occ_origin", Vector2(area.position))
	mat.set_shader_parameter("rect_origin", Vector2(area.position * TILE))
	mat.set_shader_parameter("tile", float(TILE))
	mat.set_shader_parameter("animate", Test.effects_enabled)
	mat.set_shader_parameter("fireflies", false)   # no yellow fireflies (turned off; was Test.effects_enabled)

	var rect := ColorRect.new()
	rect.name = "ArenaDress"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(area.position * TILE)
	rect.size = Vector2(area.size * TILE)
	rect.material = mat
	layer.add_child(rect)
	layer.self_modulate.a = 0.0   # hide the plain tiles; collisions stay

	# Boss arenas: the floor is a mirror of dark water (rest stops keep their ground)
	var scene_file: String = layer.owner.scene_file_path.get_file() if layer.owner else ""
	if scene_file.begins_with("Chunk_Boss") or scene_file == "Chunk_FinalBoss.tscn":
		_add_water(layer, used)
		# The arena's blue glow turns red once the boss's health bar shows up
		for key in BOSS_REDS:
			# start from the shader's own blue (an unset material value reads as null)
			mat.set_shader_parameter(key, RenderingServer.shader_get_parameter_default(SHADER.get_rid(), key))
		_red_when_bar_shows(rect, mat, layer.get_node_or_null("ArenaWater"))
		# Characters are lit by the arena while they're in it (boss_character_light.gd)
		var light = CHARACTER_LIGHT.instantiate()
		light.arena = rect
		light.arena_material = mat
		rect.add_child(light)



## Dark reflective water filling the arena below its floor line, like a stage in
## Your Only Move Is HUSTLE: everything above (characters, the boss, attacks, the
## sky) is mirrored with soft ripples. Purely visual: the floor stays solid.
## Uses the game's ReflectiveWater (Scripts/Effects/reflective_water.gd).
static func _add_water(layer: TileMapLayer, used: Rect2i) -> void:
	# Find the floor under the middle of the arena, then the walls either side of it
	var cx := used.position.x + used.size.x / 2
	var cy := used.position.y + used.size.y / 2
	var floor_y := 0
	var found := false   # (cell coordinates can be negative, so no -1 sentinel)
	for y in range(cy, used.end.y):
		if layer.get_cell_source_id(Vector2i(cx, y)) != -1:
			floor_y = y
			found = true
			break
	if not found:
		return
	var left := cx
	while left > used.position.x and layer.get_cell_source_id(Vector2i(left - 1, floor_y - 1)) == -1:
		left -= 1
	var right := cx
	while right < used.end.x - 1 and layer.get_cell_source_id(Vector2i(right + 1, floor_y - 1)) == -1:
		right += 1
	# Stretch it well past the arena walls so it spans the whole screen width
	left -= WATER_EXTEND
	right += WATER_EXTEND
	var water := ReflectiveWater.new()
	water.name = "ArenaWater"
	# Starts just under the glowing floor line (2 tileset pixels), which stays as the waterline
	var line := 2.0
	water.position = Vector2(left * TILE, floor_y * TILE + line)
	water.size = Vector2((right - left + 1) * TILE, (used.end.y - floor_y + 30) * TILE - line)
	water.water_color = Color(0.02, 0.025, 0.07, 1.0)
	water.reflection_tint = Color(0.62, 0.7, 0.95)
	water.reflectivity = 0.62
	water.ripple_strength = 0.0025
	water.surface_color = Color(0.47, 1.0, 0.92)
	# Drawn after the characters and the boss, so they're in the reflection
	water.z_index = 90
	water.z_as_relative = false
	layer.add_child(water)
	var m := water.material as ShaderMaterial
	if m:
		m.set_shader_parameter("surface_px", 0.0)    # the floor line is already drawn
		m.set_shader_parameter("fade_uv", 0.5)


## Waits for the boss health bar (any visible "BossUIContainer") to appear, then
## fades the arena and its water from blue to red. Fights with no health bar
## turn red straight away.
static func _red_when_bar_shows(rect: Control, mat: ShaderMaterial, water: Node) -> void:
	var tree := rect.get_tree()
	var state := {"waited": 0, "fn": null}   # (a lambda can't refer to itself, so it's kept here)
	var check := func() -> void:
		if not is_instance_valid(rect):
			tree.process_frame.disconnect(state.fn)
			return
		state.waited += 1
		if state.waited % 6 != 0:
			return   # a few checks a second is plenty
		var bars := tree.root.find_children("BossUIContainer", "", true, false)
		var shown := false
		for b in bars:
			if b is CanvasItem and (b as CanvasItem).is_visible_in_tree():
				shown = true
		if not shown and not (bars.is_empty() and state.waited > 180):
			return
		tree.process_frame.disconnect(state.fn)
		var tw := rect.create_tween().set_parallel(true)
		for key in BOSS_REDS:
			tw.tween_property(mat, "shader_parameter/" + key, BOSS_REDS[key], RED_FADE)
		if is_instance_valid(water):
			tw.tween_property(water, "water_color", Color(0.07, 0.016, 0.02, 1.0), RED_FADE)
			tw.tween_property(water, "reflection_tint", Color(0.95, 0.66, 0.62), RED_FADE)
			tw.tween_property(water, "surface_color", Color(1.0, 0.55, 0.47), RED_FADE)
	state.fn = check
	tree.process_frame.connect(check)
