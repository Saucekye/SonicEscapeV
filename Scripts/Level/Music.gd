extends AudioStreamPlayer

var level = 0
var current_scene_name := ""
var new_scene_name := ""
var volume := -15

# ─────────────────────────────
# Fixed music per scene
# ─────────────────────────────
var scene_music := {
	"CharacterSelectScreen": preload("uid://c6n8dxpyff6vw"),
	"warningscreen": preload("uid://dsik0il3nyc8u")
}

# ─────────────────────────────
# Node2D playlist
# ─────────────────────────────
var node2d_music_pool := [
	preload("uid://d36stmjt5ako"),
	preload("uid://qtdltg818wt3"),
	preload("uid://cll8kes517od7")
]

var node2d_track_index := 0
var using_node2d_playlist := false
var was_music_playing := false   # ← detects flip to false

func _ready() -> void:
	bus = "Music"
	volume_db = volume
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Persistent across scenes
	get_tree().root.add_child(self)
	set_owner(null)

	current_scene_name = get_tree().current_scene.name
	update_scene_music()

func _process(delta: float) -> void:
	if get_tree().current_scene == null:
		return

	new_scene_name = get_tree().current_scene.name
	if new_scene_name != current_scene_name:
		current_scene_name = new_scene_name
		update_scene_music()

	# ─────────────────────────────
	# Playlist advance trigger
	# ─────────────────────────────
	if using_node2d_playlist:
		if was_music_playing and not Test.musicplaying:
			_advance_node2d_playlist()

		was_music_playing = Test.musicplaying

	# ─────────────────────────────
	# Music play logic (yours)
	# ─────────────────────────────
	if current_scene_name != "Node2D":
		if Test.music and not Test.musicplaying:
			Test.musicplaying = true
			volume_db = volume
			play()

	if current_scene_name == "Node2D":
		if (Test.level > 0 and not Test.level % 4 == 0) \
		and Test.music and not Test.musicplaying:
			Test.musicplaying = true
			volume_db = volume
			play()

	if volume_db != volume:
		volume_db = volume

func update_scene_music() -> void:
	if playing:
		stop()

	await get_tree().create_timer(0.5).timeout

	using_node2d_playlist = false
	was_music_playing = false

	if current_scene_name == "Node2D":
		if node2d_music_pool.is_empty():
			return

		# 🎲 Random starting track
		node2d_track_index = randi() % node2d_music_pool.size()
		stream = node2d_music_pool[node2d_track_index]
		using_node2d_playlist = true

		print("Node2D playlist start:",
			node2d_track_index,
			stream.resource_path)
	else:
		if scene_music.has(current_scene_name):
			stream = scene_music[current_scene_name]
			print("Changed music for scene:", current_scene_name)
		else:
			print("No music defined for scene:", current_scene_name)
			return

	Test.musicplaying = false

func _advance_node2d_playlist() -> void:
	if node2d_music_pool.is_empty():
		return

	node2d_track_index += 1
	if node2d_track_index >= node2d_music_pool.size():
		node2d_track_index = 0

	stream = node2d_music_pool[node2d_track_index]
	Test.musicplaying = false

	print("Advance Node2D playlist:",
		node2d_track_index,
		stream.resource_path)

func set_music_for_scene(scene_name: String) -> void:
	if scene_music.has(scene_name):
		if playing:
			stop()
		using_node2d_playlist = false
		stream = scene_music[scene_name]
		Test.musicplaying = false
		print("Set music for scene:", scene_name)
