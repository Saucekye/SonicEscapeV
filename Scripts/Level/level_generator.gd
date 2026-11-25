extends Node2D

# Chunk Scenes
@export var chunk_start: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Start.tscn")
@export var chunk_boss_final: PackedScene = preload("res://Scenes/LevelChunks/Chunk_FinalBoss.tscn")
@export var chunk_end: PackedScene = preload("res://Scenes/LevelChunks/Chunk_End.tscn")
@export var chunk_rest: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Rest.tscn")
@export var chunk_finalrest: PackedScene = preload("res://Scenes/LevelChunks/Chunk_RestFinal.tscn")
@export var chunk_tutorial: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Tutorial.tscn")   ## Level 1 training stage

# Level chunks and boss fights come from res://game_content.tres
var level_chunks: Array[PackedScene] = []

# Miku
@export var miku_scene: PackedScene = preload("res://Scenes/Obstacles/Miku/miku.tscn")

## Testing a boss
@export var test_boss: PackedScene

# Settings

@export var first_chunk_offset := Vector2(500, 1000)
# Sky routes: pieces that go above a chunk
@export var sky_routes: Array[PackedScene] = [
	preload("res://Scenes/LevelChunks/Overlays/Over_01.tscn"),
	preload("res://Scenes/LevelChunks/Overlays/Over_02.tscn"),
	preload("res://Scenes/LevelChunks/Overlays/Over_03.tscn")]
@export_range(0.0, 1.0) var sky_route_chance := 0.6   ## how often a chunk gets a sky route over it
@export var sky_route_gap := 14.0    ## clear space between a chunk's highest point
## Fewer rings: rings are kept in sets of 3, and no two sets closer than this
@export var ring_spacing := 300.0
## Size of the spring up to a sky route
@export var sky_spring_scale := 1.2
@export var sky_route_max_rise := 42.0   ## no sky route if it would be higher than this above the spring

# Runtime State
var chunks: Array[Node2D] = []
var last_end_position: Vector2
var last_chunk_scene: PackedScene = null
var end_spawned := false

var rng := RandomNumberGenerator.new()

# Persists across scene reloads: the last boss level whose rest area was already shown
static var rest_done_level := -1

@export var minimap_path: NodePath = "CanvasLayer/Minimap"

# Ready
func _ready():
	Test.note_floor(Test.level)
	var from_salvage := Test.back_from_salvage
	Test.back_from_salvage = false
	rng.randomize()
	if Test.level == 0 and not from_salvage:
		rest_done_level = -1  # new run, reset
		Test.salvage_done_level = -1
		Test.market_done_level = -1
		Test.clear_upgrades()
	elif Test.full_meter_each_floor:
		Test.meter = Test.maxmeter
	Test.shields_left = maxi(Test.shields_left, Test.shields_each_floor)
	Test.rest = false  # default; set to true only when a rest chunk spawns
	Test.in_rest_area = false   # set below for rest areas
	Test.floor_done = false
	if test_boss:
		_spawn_single_chunk(test_boss)
		return
	if Test.boss_rotation_order.is_empty():
		Test.build_boss_rotation()
	level_chunks = Content.level_chunks()
	if Test.playtest_chunk:
		level_chunks = [Test.playtest_chunk]
		Test.playtest_chunk = null   # once; the next floors are normal

	if Test.level == 0:
		_spawn_rest_level()
	elif Test.level == 1:
		_spawn_tutorial()   # Level 1 is always the training stage
	elif Test.level % 4 == 0:
		_spawn_next_boss_level()
	else:
		_spawn_start_chunk()
		_spawn_middle_chunks()
		_spawn_end_chunk()
		_thin_rings()
		_spawn_miku_on_ground.call_deferred()
		if Test.playtest_enemy:
			_spawn_playtest_enemies(Test.playtest_enemy)
			Test.playtest_enemy = null

	if minimap_path != NodePath() and has_node(minimap_path):
		var parts: Array[Node2D] = chunks.duplicate()
		for c in get_children():
			if c is Node2D and c.name.begins_with("SkyRoute"):
				parts.append(c)   # sky routes aren't chunks, but they're part of the floor
		get_node(minimap_path).build_map(parts)


# The Sonic Escape panel's Play on an enemy
func _spawn_playtest_enemies(scene: PackedScene) -> void:
	if chunks.size() < 2:
		return
	var from: Vector2 = chunks[0].get_node("End").global_position
	for i in 4:
		var enemy: Node2D = scene.instantiate()
		chunks[1].add_child(enemy)
		enemy.global_position = from + Vector2(350 + 300 * i, -160)

# Boss Rotation
func _spawn_next_boss_level():
	# Level 24 is the rest after the final boss; its goal proceeds normally
	if Test.level == 24:
		Test.in_rest_area = true
		_spawn_single_chunk(chunk_rest)
		Test.rest = false
		return

	# First visit to a boss level: spawn the rest area.
	# Its goal should reload the level WITHOUT incrementing Test.level (see Test.rest below).
	if rest_done_level != Test.level:
		rest_done_level = Test.level
		Test.in_rest_area = true
		if Test.level == 20:
			Test.rest = true
			_spawn_single_chunk(chunk_finalrest)	
		else:
			Test.rest = true
			_spawn_single_chunk(chunk_rest)
		return

	# Second visit (after the rest goal reloaded the level): spawn the boss
	Test.rest = false
	Pause.current_scene = "Boss"

	if Test.level % 20 == 0:
		_add_boss_miku(_spawn_single_chunk(chunk_boss_final))
		return

	if Test.playtest_arena:
		_add_boss_miku(_spawn_single_chunk(Test.playtest_arena))
		Test.playtest_arena = null   # once; the next floors are normal
		return
	var bosses := Content.bosses()
	if Test.boss_rotation_order.is_empty():
		Test.build_boss_rotation()
	var index: int = Test.boss_rotation_order.pop_front()
	var boss_chunk := _spawn_single_chunk(bosses[index % bosses.size()].arena)
	_add_boss_miku(boss_chunk)

# After level 8, a Miku drops into boss arenas
func _add_boss_miku(chunk: Node) -> void:
	if Test.level <= 8 or chunk == null:
		return
	var watcher = preload("res://Scripts/Level/boss_miku.gd").new()
	watcher.name = "BossMiku"
	watcher.setup(self, chunk)
	add_child(watcher)

# Spawns one chunk as the entire level
func _spawn_single_chunk(scene: PackedScene) -> Node:
	Test.rest = true
	var chunk := scene.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position = first_chunk_offset - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)
	end_spawned = true
	return chunk

# The training stage, followed by the normal goal chunk
func _spawn_tutorial():
	var chunk := chunk_tutorial.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position = first_chunk_offset - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)
	_spawn_end_chunk()

# Chunk Spawning Functions
func _spawn_rest_level():
	Test.in_rest_area = true
	_spawn_single_chunk(chunk_rest)
	Test.rest = false

func _spawn_start_chunk():
	var chunk := chunk_start.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position = first_chunk_offset - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)

func _spawn_middle_chunks():
	for i in range(Content.data().chunks_per_floor - 2):
		_spawn_next_chunk()

	var sky := 0
	for i in range(1, chunks.size()):
		if rng.randf() < sky_route_chance and _add_sky_route(chunks[i], sky):
			sky += 1


# Fewer rings: going along in order
func _thin_rings() -> void:
	if ring_spacing <= 0.0:
		return
	var sets: Array = []   # each one 3 rings
	var loose: Array = []
	for n in find_children("*", "CharacterBody2D", true, false):
		if not n.scene_file_path.ends_with("Rings.tscn"):
			continue
		var p: Node = n.get_parent()
		if p.scene_file_path.ends_with("ring_strand.tscn"):
			if p.get_child(0) == n:
				var own: Array = []
				for c in p.get_children():
					if c.scene_file_path.ends_with("Rings.tscn"):
						own.append(c)
				sets.append(own)
		else:
			loose.append(n)
	# Loose rings: join the ones next to each other into lines
	var line_of := {}
	var lines: Array = []
	for r in loose:
		if line_of.has(r):
			continue
		var line: Array = [r]
		line_of[r] = true
		var i := 0
		while i < line.size():
			for o in loose:
				if not line_of.has(o) and o.global_position.distance_to(line[i].global_position) < RING_LINK:
					line_of[o] = true
					line.append(o)
			i += 1
		lines.append(line)
	for line in lines:
		_order_line(line)
		var k := 0
		while k + 3 <= line.size():
			sets.append(line.slice(k, k + 3))
			k += 3
		for left in line.slice(k):   # 1 or 2 left over
			_drop_ring(left)
	var centre := func(grp: Array) -> Vector2:
		return (grp[0].global_position + grp[1].global_position + grp[2].global_position) / 3.0
	sets.sort_custom(func(a, b): return centre.call(a).x < centre.call(b).x)
	var kept: Array[Vector2] = []
	var gap2 := ring_spacing * ring_spacing
	for grp in sets:
		var at: Vector2 = centre.call(grp)
		var close := false
		for i in range(kept.size() - 1, -1, -1):
			if at.x - kept[i].x > ring_spacing:
				break
			if at.distance_squared_to(kept[i]) < gap2:
				close = true
				break
		if close:
			for r in grp:
				_drop_ring(r)
		else:
			kept.append(at)

const RING_LINK := 130.0   # rings closer than this are in the same line

# Put a line of rings in order from one end to the other
func _order_line(line: Array) -> void:
	if line.size() < 3:
		return
	var end: Node = line[0]
	for r in line:   # the ring furthest from any ring is an end
		if r.global_position.distance_squared_to(line[0].global_position) > end.global_position.distance_squared_to(line[0].global_position):
			end = r
	var rest := line.duplicate()
	rest.erase(end)
	line.clear()
	line.append(end)
	while not rest.is_empty():
		var last: Vector2 = line[-1].global_position
		var best: Node = rest[0]
		for r in rest:
			if r.global_position.distance_squared_to(last) < best.global_position.distance_squared_to(last):
				best = r
		rest.erase(best)
		line.append(best)

func _drop_ring(r: Node) -> void:
	r.get_parent().remove_child(r)
	r.queue_free()


const TILE := 38.4   # a chunk tile in world pixels

# Every solid tile of a chunk
func _chunk_solids(chunk: Node, with_rails := true) -> Array:
	var out := []
	for tm in chunk.find_children("*", "TileMapLayer", true, false):
		if not tm.collision_enabled:
			continue
		var half: Vector2 = tm.global_transform.get_scale() * 8.0
		for cell in tm.get_used_cells():
			var td: TileData = tm.get_cell_tile_data(cell)
			if td == null or td.get_collision_polygons_count(0) == 0:
				continue
			var c: Vector2 = tm.to_global(tm.map_to_local(cell))
			out.append(Rect2(c - half, half * 2.0))
	if with_rails:
		# How high the chunk's springs throw you counts as part of it too
		for sp in chunk.find_children("*", "", true, false):
			var v = sp.get("spring_velocity")
			if v is Vector2 and v.y < 0.0 and sp is Node2D:
				var apex: float = v.y * v.y / (2.0 * 2080.0)
				out.append(Rect2(sp.global_position - Vector2(TILE, apex), Vector2(2.0 * TILE, apex)))
		for rail in chunk.find_children("*", "Path2D", true, false):
			for q in rail.curve.get_baked_points():
				out.append(Rect2(rail.to_global(q) - Vector2(4, 4), Vector2(8, 8)))
	return out


# How long a sky route is, Start to End
var _sky_lengths := {}
func _sky_length(sc: PackedScene) -> float:
	if _sky_lengths.has(sc):
		return _sky_lengths[sc]
	var state := sc.get_state()
	var at := {}
	for i in state.get_node_count():
		var n := str(state.get_node_name(i))
		if n in ["Start", "End"]:
			for k in state.get_node_property_count(i):
				if state.get_node_property_name(i, k) == "position":
					at[n] = state.get_node_property_value(i, k)
	var length: float = (at.get("End", Vector2.ZERO) - at.get("Start", Vector2.ZERO)).x
	_sky_lengths[sc] = length
	return length


func _add_sky_route(base: Node2D, index: int) -> bool:
	if sky_routes.is_empty() or not base.has_node("Start") or not base.has_node("End"):
		return false
	var bs: Vector2 = base.get_node("Start").global_position
	var be: Vector2 = base.get_node("End").global_position
	var room := be.x - bs.x
	# The longest sky routes that fit, then one of them at random
	var fits := []
	for sc in sky_routes:
		var length := _sky_length(sc)
		if length + 12.0 * TILE <= room:
			fits.append([sc, length])
	if fits.is_empty():
		return false
	var pick: Array = fits[rng.randi_range(0, fits.size() - 1)]
	var length: float = pick[1]
	var solids := _chunk_solids(base)
	var ground := _chunk_solids(base, false)
	# The spring: somewhere in the first part of the chunk with ground under it
	for k in range(int(room * 0.4 / (2.0 * TILE))):
		var sx := bs.x + (2.5 + 2.0 * k) * TILE
		var floor_y := INF
		for r in ground:
			if r.position.x <= sx and r.end.x >= sx:
				floor_y = minf(floor_y, r.position.y)
		if floor_y == INF or not _flat(ground, sx, floor_y):
			continue
		var top := floor_y
		for r in solids:
			if r.end.x >= sx - TILE and r.position.x <= sx + 20.0 * TILE + length:
				top = minf(top, r.position.y)
		var sky_y := minf(top - sky_route_gap * TILE, floor_y - 10.0 * TILE)
		var rise := floor_y - sky_y
		if rise > sky_route_max_rise * TILE:
			continue
		var land_x := sx + maxf(8.0 * TILE, rise * 0.5)
		if land_x + length > be.x:
			break
		var clear := true
		for r in solids:
			if r.end.x >= sx - TILE and r.position.x <= land_x and r.end.y > sky_y and r.position.y < floor_y - 2.0:
				clear = false
				break
		if clear:
			_place_sky_route(pick[0], index, sx, floor_y, land_x, sky_y)
			return true
	return false


# Level ground either side
func _flat(ground: Array, x: float, y: float) -> bool:
	for dx in [-3.0 * TILE, -1.5 * TILE, 1.5 * TILE, 3.0 * TILE]:
		var top := INF
		for r in ground:
			if r.position.x <= x + dx and r.end.x >= x + dx:
				top = minf(top, r.position.y)
		if absf(top - y) > 2.0:
			return false
	return true


func _place_sky_route(scene: PackedScene, index: int, sx: float, floor_y: float, land_x: float, sky_y: float) -> void:
	var rise := floor_y - sky_y
	var route: Node2D = scene.instantiate()
	route.name = "SkyRoute%d" % index
	add_child(route)
	route.global_position += Vector2(land_x, sky_y) - route.get_node("Start").global_position
	# Up and over the edge of its first island
	var g := 2080.0
	var vy := sqrt(2.0 * g * (rise + 2.5 * TILE))
	var t_h := (vy - sqrt(vy * vy - 2.0 * g * rise)) / g
	var dist := land_x - sx
	var held_extra := 0.5 * 330.0 * t_h * t_h
	var vx := (dist - 50.0 - held_extra) / t_h
	var spring: Node2D = preload("res://Scenes/Obstacles/Spring/Spring.tscn").instantiate()
	spring.name = "SkySpring"
	spring.scale = Vector2.ONE * sky_spring_scale
	spring.set("spring_velocity", Vector2(vx, -vy))
	spring.set("show_arc", false)
	route.add_child(spring)
	spring.global_position = Vector2(sx, floor_y - 18.0 * sky_spring_scale)   # its bottom on the ground


func _spawn_next_chunk():
	if end_spawned:
		return
	var chunk_scene := _pick_random_chunk()
	var chunk := chunk_scene.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position += last_end_position - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)

func _pick_random_chunk() -> PackedScene:
	if last_chunk_scene != null and level_chunks.size() > 1:
		level_chunks.erase(last_chunk_scene)
	var chosen = level_chunks[rng.randi_range(0, level_chunks.size() - 1)]
	last_chunk_scene = chosen
	return chosen

func _spawn_end_chunk():
	var chunk := chunk_end.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position += last_end_position - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)
	end_spawned = true

# Miku Spawn Function
func _spawn_miku_on_ground():
	var spawned = false
	# Rarely an OC appears instead of Miku
	var miku = preload("res://Scripts/Effects/miku_saved.gd").rescue_scene(miku_scene, rng).instantiate()
	add_child(miku)
	miku.scale = Vector2(125, 125)

	var valid_chunks := []
	if chunks.size() <= 2:
		print("Not enough chunks to spawn Miku")
		miku.global_position = first_chunk_offset
		return
	for i in range(1, chunks.size() - 1):
		valid_chunks.append(chunks[i])

	var player_start_pos = chunks[0].get_node("Start").global_position
	var min_distance := 100

	var attempts := 1000
	while attempts > 0:
		attempts -= 1
		var chunk = valid_chunks[rng.randi_range(0, valid_chunks.size() - 1)]
		var layers = chunk.find_children("*", "TileMapLayer", true, false)
		# A chunk's own ground first
		var main_layer = chunk.get_node_or_null("Level/TileMapLayer")
		if main_layer and rng.randi_range(1, 100) <= 99:
			var only: Array[Node] = [main_layer]
			layers = only
		var target_layers: Array[Node] = []
		var roll = rng.randi_range(1, 100)

		if roll <= 99:
			if layers.size() > 3:
				target_layers = [layers[3]]
		else:
			if layers.size() > 0:
				target_layers.append(layers[0])
			if layers.size() > 1:
				target_layers.append(layers[1])
			target_layers.shuffle()
		if target_layers.is_empty() or target_layers[0].get_used_cells().is_empty():
			target_layers = layers

		for layer in target_layers:
			if layer is TileMapLayer:
				var tilemap := layer as TileMapLayer
				var used = tilemap.get_used_cells()
				if used.is_empty():
					print("used var is empty")
					continue
				var cell = used[rng.randi_range(0, used.size() - 1)]
				var above = cell + Vector2i(0, -1)
				if tilemap.get_cell_source_id(above) == -1:
					var world_pos = tilemap.to_global(tilemap.map_to_local(cell))
					world_pos += Vector2(0, -32 * miku.scale.y)
					if world_pos.distance_to(player_start_pos) >= min_distance:
						miku.global_position = world_pos
						spawned = true
						return

	if(spawned == false):
		print("Failed to spawn Miku in middle chunks far from player")
		miku.global_position = first_chunk_offset
