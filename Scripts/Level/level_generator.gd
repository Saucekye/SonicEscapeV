extends Node2D

# ─────────────────────────────
# Chunk Scenes
# ─────────────────────────────
@export var chunk_start: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Start.tscn")

@export var chunk_01: PackedScene = preload("res://Scenes/LevelChunks/Chunk_01.tscn")
@export var chunk_02: PackedScene = preload("res://Scenes/LevelChunks/Chunk_02.tscn")
@export var chunk_03: PackedScene = preload("res://Scenes/LevelChunks/Chunk_03.tscn")
@export var chunk_04: PackedScene = preload("res://Scenes/LevelChunks/Chunk_04.tscn")
@export var chunk_05: PackedScene = preload("res://Scenes/LevelChunks/Chunk_05.tscn")
@export var chunk_06: PackedScene = preload("res://Scenes/LevelChunks/Chunk_06.tscn")
@export var chunk_07 : PackedScene = preload("res://Scenes/LevelChunks/Chunk_07.tscn")
@export var chunk_08 : PackedScene = preload("res://Scenes/LevelChunks/Chunk_08.tscn")
@export var chunk_09 : PackedScene = preload("res://Scenes/LevelChunks/Chunk_09.tscn")
@export var chunk_10 : PackedScene = preload("res://Scenes/LevelChunks/Chunk_10.tscn")
@export var chunk_11 : PackedScene = preload("res://Scenes/LevelChunks/Chunk_11.tscn")
@export var chunk_12 : PackedScene = preload("res://Scenes/LevelChunks/Chunk_12.tscn")
@export var chunk_boss: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Boss.tscn")
@export var chunk_boss1: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Boss1.tscn")
@export var chunk_boss2: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Boss2.tscn")
@export var chunk_end: PackedScene = preload("res://Scenes/LevelChunks/Chunk_End.tscn")
@export var chunk_rest: PackedScene = preload("res://Scenes/LevelChunks/Chunk_Rest.tscn")

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

@export var minimap_path: NodePath = "CanvasLayer/Minimap"

# ─────────────────────────────
# Ready
# ─────────────────────────────
func _ready():
	rng.randomize()

	if Test.level == 0:
		_spawn_rest_level()
	elif Test.level % 4 == 0:
		var roll = rng.randi_range(0, 3)
		if roll == 0:
			_spawn_boss_level()
		elif roll == 1:
			_spawn_boss1_level()
		elif roll == 2:
			_spawn_boss2_level()
		else:
			_spawn_rest_level()
	else:
		_spawn_start_chunk()
		_spawn_middle_chunks()
		_spawn_end_chunk()
		_spawn_miku_on_ground()

	if minimap_path != NodePath() and has_node(minimap_path):
		get_node(minimap_path).build_map(chunks)

# ─────────────────────────────
# Chunk Spawning Functions
# ─────────────────────────────
func _spawn_rest_level():
	var chunk := chunk_rest.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position = first_chunk_offset - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)
	end_spawned = true

func _spawn_boss_level():
	var chunk := chunk_boss.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position = first_chunk_offset - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)
	end_spawned = true

func _spawn_boss1_level():
	var chunk := chunk_boss1.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position = first_chunk_offset - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)
	end_spawned = true
	
func _spawn_boss2_level():
	var chunk := chunk_boss2.instantiate()
	add_child(chunk)
	var start = chunk.get_node("Start").global_position
	chunk.global_position = first_chunk_offset - start
	last_end_position = chunk.get_node("End").global_position
	chunks.append(chunk)
	end_spawned = true

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
	var options := [chunk_01, chunk_02, chunk_12, chunk_11, chunk_08, chunk_09, chunk_10]
	if last_chunk_scene != null:
		options.erase(last_chunk_scene)
	var chosen = options[rng.randi_range(0, options.size() - 1)]
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
	var miku = miku_scene.instantiate()
	add_child(miku)

	# Set scale to 125x125
	miku.scale = Vector2(125, 125)

	# Only middle chunks (between start and end)
	var valid_chunks := []
	if chunks.size() <= 2:
		print("Not enough chunks to spawn Miku")
		miku.global_position = first_chunk_offset
		return
	for i in range(1, chunks.size() - 1):
		valid_chunks.append(chunks[i])

	# Player start position
	var player_start_pos = chunks[0].get_node("Start").global_position
	var min_distance := 100

	var attempts := 1000
	while attempts > 0:
		attempts -= 1
		var chunk = valid_chunks[rng.randi_range(0, valid_chunks.size() - 1)]
		for child in chunk.get_children():
			if child is TileMap:
				var tilemap := child as TileMap
				var used = tilemap.get_used_cells(0)
				if used.is_empty():
					continue
				var cell = used[rng.randi_range(0, used.size() - 1)]
				var above = cell + Vector2i(0, -1)
				if tilemap.get_cell_source_id(0, above) == -1:
					var world_pos = tilemap.map_to_world(cell)
					world_pos += tilemap.global_position
					world_pos += Vector2(0, -32)
					if world_pos.distance_to(player_start_pos) >= min_distance:
						miku.global_position = world_pos
						return

	print("Failed to spawn Miku in middle chunks far from player")
	miku.global_position = first_chunk_offset
