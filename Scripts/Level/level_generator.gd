extends Node2D

# ─────────────────────────────
# Chunk Scenes
# ─────────────────────────────
@export var chunk_start: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Start.tscn")
@export var chunk_boss_final: PackedScene = preload("res://Scenes/LevelChunks/Chunk_FinalBoss.tscn")
@export var chunk_end: PackedScene = preload("res://Scenes/LevelChunks/Chunk_End.tscn")
@export var chunk_rest: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Rest.tscn")
@export var chunk_finalrest: PackedScene = preload("res://Scenes/LevelChunks/Chunk_RestFinal.tscn")

# Level chunks and boss fights come from res://game_content.tres (Content)
var level_chunks: Array[PackedScene] = []

# Miku
@export var miku_scene: PackedScene = preload("res://Scenes/Obstacles/Miku/miku.tscn")

# ─────────────────────────────
# Settings
# ─────────────────────────────
@export var max_chunks := 10
@export var first_chunk_offset := Vector2(500, 1000)

# ─────────────────────────────
# Runtime State
# ─────────────────────────────
var chunks: Array[Node2D] = []
var last_end_position: Vector2
var last_chunk_scene: PackedScene = null
var end_spawned := false

var rng := RandomNumberGenerator.new()

# Persists across scene reloads: the last boss level whose rest area was already shown
static var rest_done_level := -1

@export var minimap_path: NodePath = "CanvasLayer/Minimap"

# ─────────────────────────────
# Ready
# ─────────────────────────────
func _ready():
	rng.randomize()
	if Net.online:
		# Online: every player generates the same floor (net.gd)
		rng.seed = Net.floor_seed()
		seed(rng.seed)
	if Test.level == 0:
		rest_done_level = -1  # new run, reset
		Test.salvage_done_level = -1
	Test.rest = false  # default; set to true only when a rest chunk spawns
	Test.in_rest_area = false   # set below for rest areas; the timers don't run there
	Test.floor_done = false
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
		_spawn_miku_on_ground.call_deferred()

	if minimap_path != NodePath() and has_node(minimap_path):
		get_node(minimap_path).build_map(chunks)

# ─────────────────────────────
# Boss Rotation
# ─────────────────────────────
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

# After level 8, a Miku drops into boss arenas when the boss is down to half
# health; she's saved if she's still there when the boss is beaten (boss_miku.gd)
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

# The training stage (tutorial_stage.gd), followed by the normal goal chunk
func _spawn_tutorial():
	var ref := chunk_start.instantiate()
	var tile_set: TileSet = ref.get_node("Level/TileMapLayer").tile_set
	ref.free()
	var chunk = preload("res://Scripts/Level/tutorial_stage.gd").create(tile_set)
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position = first_chunk_offset - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)
	_spawn_end_chunk()

# ─────────────────────────────
# Chunk Spawning Functions
# ─────────────────────────────
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
	for i in range(max_chunks - 2):
		_spawn_next_chunk()

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

# ─────────────────────────────
# Miku Spawn Function
# ─────────────────────────────
func _spawn_miku_on_ground():
	var spawned = false
	# Rarely an OC appears instead of Miku (miku_saved.gd)
	var miku = preload("res://Scripts/Effects/miku_saved.gd").rescue_scene(miku_scene, Net.shared_rng("ground_miku") if Net.online else rng).instantiate()
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
