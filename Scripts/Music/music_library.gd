class_name MusicLibrary
extends RefCounted
## Your own music and playlists.
##
## Put .mp3, .ogg or .wav files in the game's music folder (the MUSIC screen's
## "OPEN MUSIC FOLDER" button opens it), press REFRESH, and they're listed next to
## the game's own songs. Make playlists out of any mix of them, pick one under
## "PLAYING", and the levels play it instead of the game's soundtrack.
##
## Where things live:
##   - your songs: the "music" folder in the game's save folder (user://music), and
##     also a "Music" folder next to the game's .exe if you make one
##   - playlists and which one is playing: user://playlists.cfg
##
## A song is stored in a playlist as an id: "game:<res:// path>" for one of the
## game's songs, "file:<path on your PC>" for one of yours.

const USER_FOLDER := "user://music"
const SAVE_PATH := "user://playlists.cfg"
const EXTENSIONS := ["mp3", "ogg", "wav"]
const GAME_SOUNDTRACK := ""   # the "playing" value for the game's own songs

static var _cache := {}       # id -> AudioStream (your files, loaded once)


## The folders your songs are read from (the first is the one we open for you)
static func folders() -> Array[String]:
	var out: Array[String] = [ProjectSettings.globalize_path(USER_FOLDER)]
	if not OS.has_feature("editor") and not OS.has_feature("web"):
		var next_to_exe := OS.get_executable_path().get_base_dir().path_join("Music")
		if DirAccess.dir_exists_absolute(next_to_exe):
			out.append(next_to_exe)
	return out


## Adding files only works in the downloadable game (a browser can't see your PC's files)
static func can_add_files() -> bool:
	return not OS.has_feature("web")


static func open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(USER_FOLDER)
	OS.shell_open(ProjectSettings.globalize_path(USER_FOLDER))


## Your song files: [{"id", "name"}], sorted by name
static func your_songs() -> Array:
	DirAccess.make_dir_recursive_absolute(USER_FOLDER)
	var out: Array = []
	for folder in folders():
		_scan(folder, out, 0)
	out.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out


static func _scan(folder: String, out: Array, depth: int) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for f in dir.get_files():
		if f.get_extension().to_lower() in EXTENSIONS:
			out.append({"id": "file:" + folder.path_join(f), "name": f.get_basename()})
	if depth < 2:   # (one or two folders deep, e.g. an album folder)
		for d in dir.get_directories():
			_scan(folder.path_join(d), out, depth + 1)


## The game's own songs (MusicManager's level songs): [{"id", "name"}]
static func game_songs(pool: Array) -> Array:
	var out: Array = []
	for s in pool:
		if s is Resource and s.resource_path != "":
			out.append({"id": "game:" + s.resource_path, "name": s.resource_path.get_file().get_basename()})
	return out


static func name_of(id: String) -> String:
	return id.substr(id.find(":") + 1).get_file().get_basename()


## The song for an id, or null if it's gone (a file you removed)
static func load_song(id: String) -> AudioStream:
	if id.begins_with("game:"):
		var path := id.substr(5)
		return load(path) as AudioStream if ResourceLoader.exists(path) else null
	if not id.begins_with("file:"):
		return null
	if _cache.has(id):
		return _cache[id]
	var path := id.substr(5)
	if not FileAccess.file_exists(path):
		return null
	var stream: AudioStream = null
	match path.get_extension().to_lower():
		"mp3":
			stream = AudioStreamMP3.load_from_file(path)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
		"wav":
			stream = AudioStreamWAV.load_from_file(path)
	if stream == null:
		push_warning("Couldn't play this music file: " + path)
		return null
	# Plays once, then the playlist moves on (the game's own songs loop as before)
	if "loop" in stream:
		stream.set("loop", false)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.take_over_path(path)   # (its name shows in the music box like the game's songs)
	_cache[id] = stream
	return stream


# ── Playlists (saved) ─────────────────────────────────────────────────────────
static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg


## Playlist names, in the order they were made
static func playlist_names() -> Array:
	var cfg := _cfg()
	return Array(cfg.get_value("order", "names", []))


static func playlist(name: String) -> Array:
	return Array(_cfg().get_value("playlists", name, []))


static func save_playlist(name: String, ids: Array) -> void:
	var cfg := _cfg()
	cfg.set_value("playlists", name, ids)
	var names := Array(cfg.get_value("order", "names", []))
	if not name in names:
		names.append(name)
	cfg.set_value("order", "names", names)
	cfg.save(SAVE_PATH)


static func delete_playlist(name: String) -> void:
	var cfg := _cfg()
	if cfg.has_section_key("playlists", name):
		cfg.erase_section_key("playlists", name)
	var names := Array(cfg.get_value("order", "names", []))
	names.erase(name)
	cfg.set_value("order", "names", names)
	if str(cfg.get_value("settings", "playing", GAME_SOUNDTRACK)) == name:
		cfg.set_value("settings", "playing", GAME_SOUNDTRACK)
	cfg.save(SAVE_PATH)


static func rename_playlist(old_name: String, new_name: String) -> bool:
	new_name = new_name.strip_edges()
	if new_name == "" or new_name == old_name or new_name in playlist_names():
		return false
	var cfg := _cfg()
	var ids = cfg.get_value("playlists", old_name, [])
	cfg.erase_section_key("playlists", old_name)
	cfg.set_value("playlists", new_name, ids)
	var names := Array(cfg.get_value("order", "names", []))
	var i := names.find(old_name)
	if i >= 0:
		names[i] = new_name
	cfg.set_value("order", "names", names)
	if str(cfg.get_value("settings", "playing", GAME_SOUNDTRACK)) == old_name:
		cfg.set_value("settings", "playing", new_name)
	cfg.save(SAVE_PATH)
	return true


## A name for a new playlist that isn't taken yet ("Playlist 1", "Playlist 2"...)
static func new_name() -> String:
	var names := playlist_names()
	var n := 1
	while ("Playlist %d" % n) in names:
		n += 1
	return "Playlist %d" % n


## Which playlist the levels play ("" = the game's soundtrack)
static func playing() -> String:
	var p := str(_cfg().get_value("settings", "playing", GAME_SOUNDTRACK))
	return p if p in playlist_names() else GAME_SOUNDTRACK


static func set_playing(name: String) -> void:
	var cfg := _cfg()
	cfg.set_value("settings", "playing", name)
	cfg.save(SAVE_PATH)


static func shuffle() -> bool:
	return bool(_cfg().get_value("settings", "shuffle", false))


static func set_shuffle(on: bool) -> void:
	var cfg := _cfg()
	cfg.set_value("settings", "shuffle", on)
	cfg.save(SAVE_PATH)


## The songs of the playlist that's playing (empty = use the game's soundtrack)
static func playing_songs() -> Array:
	var name := playing()
	if name == GAME_SOUNDTRACK:
		return []
	var out: Array = []
	for id in playlist(name):
		var s := load_song(str(id))
		if s:
			out.append(s)
	return out
