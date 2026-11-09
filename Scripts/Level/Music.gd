extends AudioStreamPlayer

signal song_started(song_name: String)
signal song_stopped
signal pool_changed   # the level songs changed (your playlist picked, or back to the game's)

var level = 0
var current_scene_name := ""
var new_scene_name := ""
var volume := -15
var is_muted = false
var display_teto : bool = true
var can_play : bool = true

# ─────────────────────────────
# Fixed music per scene
# ─────────────────────────────

var scene_music := {
	"CharacterSelectScreen": preload("res://Music/CharacterSelect/zerogravitymenumix.MP3"),
	"warningscreen": preload("res://Music/Intro/sos.MP3"),
	
}

# ─────────────────────────────
# Node2D playlist
# ─────────────────────────────
var node2d_music_pool := [
	preload("res://Music/Level/[Artisan] Azealia_Banks - Luxury Remix.mp3"),
	preload("res://Music/Level/[Artisan] PinkPantheress ft. Rema - Another Life.MP3"),
	preload("res://Music/Level/[TNH Nebula] Workbench In 'Da Club Sonic CD Jersey Superfunk REMIX.mp3"),
	preload("res://Music/Level/[TNH Nebula] Work It Out Ft. JanettPlanett.MP3"),
	preload("res://Music/Level/[TNH Nebula] I'm Yours and You're Mine Ft. Hatsune Miku.mp3"),
	preload("res://Music/Level/[TNH Nebula] Kasane Teto - 医学 Igaku (Medicine)   REMIX.mp3"),
	preload("res://Music/Level/[Sonic Escape] Been Here Before.MP3")
]

# The game's own level songs (node2d_music_pool is these, or your playlist's
# songs when you picked one in the MUSIC screen: music_library.gd)
var game_pool: Array = []
var custom_active := false   # node2d_music_pool is your playlist

var node2d_track_index := 0
var using_node2d_playlist := false
var was_music_playing := false   # ← detects flip to false
var last_checked_level := -1     # ← detects Test.level changing mid-scene

func _ready() -> void:
	bus = "Music"
	volume_db = volume
	process_mode = Node.PROCESS_MODE_ALWAYS
	GlobalSignals.game_over.connect(_on_game_over)
	set_owner(null)
	game_pool = node2d_music_pool.duplicate()
	_use_playlist_pool()
	# Your songs play once, then the playlist moves on to the next
	finished.connect(func() -> void:
		if using_node2d_playlist:
			Test.musicplaying = false)

	current_scene_name = get_tree().current_scene.name
	update_scene_music()

func _process(delta: float) -> void:
	if get_tree().current_scene == null:
		return

	new_scene_name = get_tree().current_scene.name
	# The vision scenes' root is also called "Node2D", like a level; they play
	# their own music, so treat them separately
	if get_tree().current_scene.scene_file_path.ends_with("vision.tscn") or new_scene_name == "Salvage":
		new_scene_name = "Vision"   # (the Salvage mini game is silent too)
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
		# Catch Test.level hitting 25 mid-scene (no scene-name change,
		# no track-end needed) and force the last track right away.
		# ─────────────────────────────
		if Test.level != last_checked_level:
			last_checked_level = Test.level
			if Test.level == 25 and Test.complete:
				_force_last_track()

	# ─────────────────────────────
	# Music play logic (yours)
	# ─────────────────────────────
	if current_scene_name == "Vision":
		# Nothing from the levels or rest areas plays during a vision
		if playing:
			stop()
		Test.musicplaying = false
		return


	if current_scene_name != "Node2D" and current_scene_name != "Titlescreen":
		if Test.music and not Test.musicplaying:
			Test.musicplaying = true
			volume_db = volume
			play()

	if current_scene_name == "Node2D" and current_scene_name != "Titlescreen":
		if (Test.level > 0 and not Test.level % 4 == 0) \
		and Test.music and not Test.musicplaying:
			Test.musicplaying = true
			volume_db = volume
			play()
			

	if volume_db != volume:
		volume_db = volume

## Use the playlist picked in the MUSIC screen, or the game's songs if none.
## Returns true if the songs changed.
func _use_playlist_pool() -> bool:
	var mine: Array = MusicLibrary.playing_songs()
	var want: Array = mine if not mine.is_empty() else game_pool
	if want == node2d_music_pool:
		return false
	node2d_music_pool = want
	custom_active = not mine.is_empty()
	node2d_track_index = 0
	pool_changed.emit()
	return true


## The MUSIC screen changed which playlist plays (or its songs): switch now if
## we're in a level
func apply_playlist() -> void:
	MusicLibrary._cache.clear()   # (re-read files you replaced)
	var changed := _use_playlist_pool()
	if not changed and not custom_active:
		return
	if current_scene_name == "Node2D" and using_node2d_playlist and not Test.music_locked:
		node2d_track_index = _first_index()
		stream = node2d_music_pool[node2d_track_index] if not node2d_music_pool.is_empty() else null
		if playing:
			stop()
		Test.musicplaying = false
		was_music_playing = false   # (a fresh start, not "the song ended": don't skip ahead)


func _first_index() -> int:
	if custom_active:
		return randi() % node2d_music_pool.size() if MusicLibrary.shuffle() and node2d_music_pool.size() > 0 else 0
	var playable := _get_playable_indices()
	return 0 if playable.is_empty() else playable[randi() % playable.size()]


func _get_playable_indices() -> Array:
	var indices : Array = []
	if custom_active:
		return range(node2d_music_pool.size())
	var last_index := node2d_music_pool.size() - 1
	for i in range(node2d_music_pool.size()):
		if i == last_index and not Test.complete:
			continue
		indices.append(i)
	return indices

func update_scene_music() -> void:
	if playing:
		stop()

	await get_tree().create_timer(0.5).timeout

	using_node2d_playlist = false
	was_music_playing = false

	if current_scene_name == "Node2D":
		_use_playlist_pool()
		if node2d_music_pool.is_empty():
			return

		# 🎲 Random starting track (last track reserved for Test.complete == true)
		# (your playlist: from the top, or anywhere when shuffled)
		if Test.level == 25 and Test.complete and not custom_active:
			node2d_track_index = node2d_music_pool.size() - 1
		else:
			node2d_track_index = _first_index()

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

	if custom_active:
		# Your playlist: the next song, or a different random one when shuffled
		if MusicLibrary.shuffle() and node2d_music_pool.size() > 1:
			var before := node2d_track_index
			while node2d_track_index == before:
				node2d_track_index = randi() % node2d_music_pool.size()
		else:
			node2d_track_index = (node2d_track_index + 1) % node2d_music_pool.size()
	elif Test.level == 25 and Test.complete:
		node2d_track_index = node2d_music_pool.size() - 1
	else:
		node2d_track_index += 1
		if node2d_track_index >= node2d_music_pool.size():
			node2d_track_index = 0
		# Skip the reserved last track unless Test.complete is true
		if node2d_track_index == node2d_music_pool.size() - 1 and not Test.complete:
			node2d_track_index = 0

	stream = node2d_music_pool[node2d_track_index]
	Test.musicplaying = false
	
	print("Advance Node2D playlist:",
		node2d_track_index,
		stream.resource_path)

func _force_last_track() -> void:
	if node2d_music_pool.is_empty() or custom_active:
		return   # (your own playlist keeps playing)
	if not Test.complete:
		return

	node2d_track_index = node2d_music_pool.size() - 1
	stream = node2d_music_pool[node2d_track_index]

	if playing:
		stop()
	Test.musicplaying = false

	print("Forced last Node2D track (level 25):",
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

func _on_game_over():
	const FADEOUT_TIME : float = 3.0
	var fadeout_tween = get_tree().create_tween()
	fadeout_tween.tween_property(self, "volume_db", -40, FADEOUT_TIME)
	await fadeout_tween.finished
	playing = false
