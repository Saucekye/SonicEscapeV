extends CanvasLayer
## The MUSIC screen: your own songs and playlists (music_library.gd).
## Opened from the pause menu's Settings ("Music Playlists"). Works with a mouse,
## a keyboard or a controller (B / Esc goes back).
##
##   PLAYING      which playlist the levels play (or the game's soundtrack), and shuffle
##   SONGS        the game's songs and yours; OPEN MUSIC FOLDER, then REFRESH after
##                adding files. ADD (or pick a song) puts it in the playlist on the right.
##   PLAYLIST     pick one to change, NEW / RENAME / DELETE, and its songs in order
##                (UP / DOWN to move one, REMOVE to take it out)

signal closed

const RUSH := preload("res://Scripts/UI/rush_theme.gd")

var _playing: OptionButton
var _shuffle: CheckButton
var _songs: ItemList
var _song_ids: Array = []
var _lists: OptionButton
var _name_edit: LineEdit
var _tracks: ItemList
var _note: Label
var _first: Control


static func open(parent: Node) -> Node:
	var s = load("res://Scripts/Music/music_screen.gd").new()
	parent.add_child(s)
	return s


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = RUSH.build()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(RUSH.BLACK, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 40
	page.offset_right = -40
	page.offset_top = 24
	page.offset_bottom = -20
	page.add_theme_constant_override("separation", 10)
	root.add_child(page)

	var title := Label.new()
	title.text = "MUSIC"
	title.add_theme_font_size_override("font_size", 40)
	page.add_child(title)

	# PLAYING: which playlist the levels use
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	page.add_child(top)
	top.add_child(_label("Playing"))
	_playing = OptionButton.new()
	_playing.custom_minimum_size.x = 360
	_playing.fit_to_longest_item = false
	_playing.item_selected.connect(_on_playing_picked)
	top.add_child(_playing)
	_shuffle = CheckButton.new()
	_shuffle.text = "Shuffle"
	_shuffle.button_pressed = MusicLibrary.shuffle()
	_shuffle.toggled.connect(func(on: bool) -> void:
		MusicLibrary.set_shuffle(on)
		MusicManager.apply_playlist())
	top.add_child(_shuffle)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	page.add_child(cols)

	# SONGS: everything you can put in a playlist
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(_label("Songs"))
	_songs = ItemList.new()
	_songs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_songs.item_activated.connect(func(_i: int) -> void: _add_song())
	left.add_child(_songs)
	var lb := HBoxContainer.new()
	left.add_child(lb)
	var add := _button("Add >", _add_song)
	lb.add_child(add)
	if MusicLibrary.can_add_files():
		lb.add_child(_button("Open Music Folder", func() -> void: MusicLibrary.open_folder()))
		lb.add_child(_button("Refresh", _refresh_songs))

	# PLAYLIST: the one you're changing
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var pr := HBoxContainer.new()
	right.add_child(pr)
	pr.add_child(_label("Playlist"))
	_lists = OptionButton.new()
	_lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lists.fit_to_longest_item = false
	_lists.item_selected.connect(func(_i: int) -> void: _show_playlist())
	pr.add_child(_lists)
	var nr := HBoxContainer.new()
	right.add_child(nr)
	nr.add_child(_button("New", _new_playlist))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "name"
	_name_edit.text_submitted.connect(func(_t: String) -> void: _rename())
	nr.add_child(_name_edit)
	nr.add_child(_button("Rename", _rename))
	nr.add_child(_button("Delete", _delete_playlist))
	_tracks = ItemList.new()
	_tracks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_tracks)
	var tb := HBoxContainer.new()
	right.add_child(tb)
	tb.add_child(_button("Up", func() -> void: _move(-1)))
	tb.add_child(_button("Down", func() -> void: _move(1)))
	tb.add_child(_button("Remove", _remove_song))

	var bottom := HBoxContainer.new()
	page.add_child(bottom)
	var back := _button("Back", close)
	bottom.add_child(back)
	_note = Label.new()
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 18)
	bottom.add_child(_note)

	_refresh_songs()
	_refresh_playlists()
	_first = _songs
	_songs.grab_focus.call_deferred()
	if _songs.item_count > 0:
		_songs.select(0)


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _button(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(f)
	return b


func _say(t: String) -> void:
	_note.text = t


# ── Songs ─────────────────────────────────────────────────────────────────────
func _refresh_songs() -> void:
	var keep := _songs.get_selected_items()
	_songs.clear()
	_song_ids.clear()
	for s in MusicLibrary.game_songs(MusicManager.game_pool):
		_songs.add_item(str(s.name))
		_song_ids.append(s.id)
	var mine := MusicLibrary.your_songs()
	for s in mine:
		_songs.add_item("♪ " + str(s.name))
		_song_ids.append(s.id)
	if not keep.is_empty() and keep[0] < _songs.item_count:
		_songs.select(keep[0])
	if not MusicLibrary.can_add_files():
		_say("Adding your own songs works in the downloadable version of the game. You can still make playlists of the game's songs here.")
	elif mine.is_empty():
		_say("Add your own songs: OPEN MUSIC FOLDER, put .mp3, .ogg or .wav files in it, then REFRESH. Yours are marked ♪.")
	else:
		_say("%d of your songs found (marked ♪). Added more? Press REFRESH." % mine.size())
	MusicManager.apply_playlist()   # (a file you replaced plays the new version)


func _add_song() -> void:
	var sel := _songs.get_selected_items()
	if sel.is_empty():
		_say("Pick a song on the left first.")
		return
	var name := _current_list()
	if name == "":
		name = MusicLibrary.new_name()   # no playlist yet: make one
		MusicLibrary.save_playlist(name, [])
		_refresh_playlists(name)
	var ids := MusicLibrary.playlist(name)
	ids.append(_song_ids[sel[0]])
	MusicLibrary.save_playlist(name, ids)
	_show_playlist(ids.size() - 1)
	_say("Added %s to %s." % [MusicLibrary.name_of(_song_ids[sel[0]]), name])
	_changed(name)


# ── Playlists ─────────────────────────────────────────────────────────────────
func _current_list() -> String:
	return _lists.get_item_text(_lists.selected) if _lists.selected >= 0 and _lists.item_count > 0 else ""


func _refresh_playlists(select := "") -> void:
	var names := MusicLibrary.playlist_names()
	if select == "":
		select = _current_list()
	_lists.clear()
	for n in names:
		_lists.add_item(str(n))
	var i := names.find(select)
	if _lists.item_count > 0:
		_lists.select(i if i >= 0 else 0)
	_playing.clear()
	_playing.add_item("Game soundtrack")
	for n in names:
		_playing.add_item(str(n))
	var p := MusicLibrary.playing()
	_playing.select(0 if p == MusicLibrary.GAME_SOUNDTRACK else names.find(p) + 1)
	_show_playlist()


func _show_playlist(select := -1) -> void:
	_tracks.clear()
	var name := _current_list()
	_name_edit.text = name
	for id in MusicLibrary.playlist(name):
		var label := MusicLibrary.name_of(str(id))
		if str(id).begins_with("file:"):
			label = "♪ " + label
		if MusicLibrary.load_song(str(id)) == null:
			label += "  (missing)"
		_tracks.add_item(label)
	if select >= 0 and select < _tracks.item_count:
		_tracks.select(select)


func _new_playlist() -> void:
	var name := MusicLibrary.new_name()
	MusicLibrary.save_playlist(name, [])
	_refresh_playlists(name)
	_say("Made %s. Add songs from the left, then pick it under PLAYING." % name)


func _rename() -> void:
	var old := _current_list()
	if old == "":
		return
	if MusicLibrary.rename_playlist(old, _name_edit.text):
		_refresh_playlists(_name_edit.text.strip_edges())
		_say("Renamed to %s." % _current_list())
	else:
		_name_edit.text = old
		_say("Pick a name that isn't empty or taken.")


func _delete_playlist() -> void:
	var name := _current_list()
	if name == "":
		return
	MusicLibrary.delete_playlist(name)
	_refresh_playlists()
	_say("Deleted %s." % name)
	MusicManager.apply_playlist()


func _move(step: int) -> void:
	var sel := _tracks.get_selected_items()
	var name := _current_list()
	if sel.is_empty() or name == "":
		return
	var ids := MusicLibrary.playlist(name)
	var i: int = sel[0]
	var j := clampi(i + step, 0, ids.size() - 1)
	if i == j:
		return
	var t = ids[i]
	ids[i] = ids[j]
	ids[j] = t
	MusicLibrary.save_playlist(name, ids)
	_show_playlist(j)
	_changed(name)


func _remove_song() -> void:
	var sel := _tracks.get_selected_items()
	var name := _current_list()
	if sel.is_empty() or name == "":
		return
	var ids := MusicLibrary.playlist(name)
	ids.remove_at(sel[0])
	MusicLibrary.save_playlist(name, ids)
	_show_playlist(mini(sel[0], ids.size() - 1))
	_changed(name)


func _on_playing_picked(i: int) -> void:
	var name := MusicLibrary.GAME_SOUNDTRACK if i == 0 else _playing.get_item_text(i)
	if name != MusicLibrary.GAME_SOUNDTRACK and MusicLibrary.playlist(name).is_empty():
		_say("%s has no songs yet: add some first." % name)
	MusicLibrary.set_playing(name)
	MusicManager.apply_playlist()
	if name != MusicLibrary.GAME_SOUNDTRACK:
		_say("Levels now play %s." % name)
	else:
		_say("Levels now play the game's soundtrack.")


## The playlist that's playing was changed: play the new version
func _changed(name: String) -> void:
	if name == MusicLibrary.playing():
		MusicManager.apply_playlist()


# ── Closing ───────────────────────────────────────────────────────────────────
func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _name_edit.has_focus() and event is InputEventKey:
		return   # (typing a name)
	var back: bool = event.is_action_pressed("ui_cancel") \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if back:
		for o in [_playing, _lists]:
			if o.get_popup().visible:
				return
		get_viewport().set_input_as_handled()
		close()
