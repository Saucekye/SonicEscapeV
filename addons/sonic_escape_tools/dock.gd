@tool
extends ScrollContainer
## The Sonic Escape panel: make a new character, boss or level from a working
## copy, open the ones that exist, and play any of them straight away.

const Maker := preload("res://addons/sonic_escape_tools/content_maker.gd")
const GUIDE := "res://MODDING.md"
const GAME_SCENE := "res://Scenes/Level/test3.tscn"

var _status: Label
var _play_as: OptionButton
var _lists := {}       # "characters" / "bosses" / "levels" -> OptionButton
var _names := {}       # same keys -> LineEdit for the new one's name
var _copy_from := {}   # "characters" / "levels" -> OptionButton
var _filled := false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var intro := Label.new()
	intro.text = "Make a new character, boss or level from a working copy, then press Play to try it."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var top := HBoxContainer.new()
	box.add_child(top)
	_button(top, "Open the guide", _open_guide)
	_button(top, "Content list", _open_content)

	_section(box, "characters", "Characters", "character", "Copy of")
	_section(box, "bosses", "Bosses", "boss", "")
	_section(box, "levels", "Levels", "level", "Copy of")

	box.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := Label.new()
	l.text = "Play as"
	row.add_child(l)
	_play_as = OptionButton.new()
	_play_as.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_play_as)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	# The lists load the whole content list (every scene in it), so they're
	# filled the first time the panel is shown rather than when the editor starts.
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree() and not _filled:
			refresh())


func _section(box: VBoxContainer, key: String, title: String, one: String, copy_label: String) -> void:
	box.add_child(HSeparator.new())
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 18)
	box.add_child(head)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(pick)
	_lists[key] = pick
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row, "Open", _open.bind(key))
	_button(row, "Play", _play.bind(key))
	var new_row := HBoxContainer.new()
	box.add_child(new_row)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "New %s name" % one
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_row.add_child(name_edit)
	_names[key] = name_edit
	_button(new_row, "Create", _create.bind(key))
	if copy_label != "":
		var copy_row := HBoxContainer.new()
		box.add_child(copy_row)
		var l := Label.new()
		l.text = copy_label
		copy_row.add_child(l)
		var from := OptionButton.new()
		from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy_row.add_child(from)
		_copy_from[key] = from


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Fill the lists from game_content.tres
func refresh() -> void:
	_filled = true
	var chars: OptionButton = _lists.characters
	chars.clear()
	_play_as.clear()
	_copy_from.characters.clear()
	for entry in Content.characters():
		chars.add_item(entry.id)
		_play_as.add_item(entry.id)
		_copy_from.characters.add_item(entry.id)
	var bosses: OptionButton = _lists.bosses
	bosses.clear()
	for entry in Content.data().bosses:
		bosses.add_item(entry.display_name + ("" if entry.enabled else "  (off)"))
	var levels: OptionButton = _lists.levels
	levels.clear()
	_copy_from.levels.clear()
	_copy_from.levels.add_item("Template (ground, enemies, rings)")
	_copy_from.levels.set_item_metadata(0, "")
	for scene in Content.level_chunks():
		levels.add_item(scene.resource_path.get_file().get_basename())
		levels.set_item_metadata(levels.item_count - 1, scene.resource_path)
		_copy_from.levels.add_item(scene.resource_path.get_file().get_basename())
		_copy_from.levels.set_item_metadata(_copy_from.levels.item_count - 1, scene.resource_path)


func _selected_path(key: String) -> String:
	var pick: OptionButton = _lists[key]
	if pick.selected < 0:
		return ""
	match key:
		"characters":
			var entry := Content.character(pick.get_item_text(pick.selected))
			return entry.scene.resource_path if entry and entry.scene else ""
		"bosses":
			var entry: BossEntry = Content.data().bosses[pick.selected]
			return entry.arena.resource_path if entry.arena else ""
		_:
			return str(pick.get_item_metadata(pick.selected))


func _open(key: String) -> void:
	var path := _selected_path(key)
	if path == "":
		_say("Pick one from the list first.")
		return
	_open_scene(path)
	_say("Opened %s" % path)


func _play(key: String) -> void:
	var pick: OptionButton = _lists[key]
	if pick.selected < 0:
		_say("Pick one from the list first.")
		return
	var cfg := ConfigFile.new()
	cfg.set_value("play", "mode", {"characters": "character", "bosses": "boss", "levels": "level"}[key])
	var as_char := _play_as.get_item_text(_play_as.selected) if _play_as.selected >= 0 else "Sonic"
	match key:
		"characters":
			as_char = pick.get_item_text(pick.selected)
		"bosses":
			cfg.set_value("play", "arena", _selected_path(key))
		"levels":
			cfg.set_value("play", "chunk", _selected_path(key))
	cfg.set_value("play", "character", as_char)
	cfg.save("user://playtest.cfg")
	EditorInterface.save_all_scenes()
	EditorInterface.play_custom_scene(GAME_SCENE)


func _create(key: String) -> void:
	var maker := Maker.new()
	var name_text: String = _names[key].text
	var path := ""
	match key:
		"characters":
			var from: OptionButton = _copy_from.characters
			path = maker.make_character(name_text, from.get_item_text(from.selected) if from.selected >= 0 else "")
		"bosses":
			path = maker.make_boss(name_text)
		"levels":
			var from: OptionButton = _copy_from.levels
			path = maker.make_level(name_text, str(from.get_item_metadata(from.selected)) if from.selected >= 0 else "")
	if path.begins_with("!"):
		_say(path.substr(1))
		return
	_say("Making %s..." % path)
	# Let the editor find and import the copied files before they're used
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	var wait := 0.0
	while wait < 30.0 and (fs.is_scanning() or not _all_loadable(maker.to_import)):
		await get_tree().create_timer(0.2).timeout
		wait += 0.2
	if not _all_loadable(maker.to_import):
		fs.reimport_files(maker.to_import)
	maker.finish()
	_names[key].text = ""
	refresh()
	var pick: OptionButton = _lists[key]
	pick.select(pick.item_count - 1)
	_open_scene(path)
	_say("Made %s and added it to the content list. It's open now; press Play to try it." % path)


func _all_loadable(paths: PackedStringArray) -> bool:
	for p in paths:
		if not ResourceLoader.exists(p):
			return false
	return true


func _open_scene(path: String) -> void:
	EditorInterface.open_scene_from_path(path)
	EditorInterface.set_main_screen_editor("2D")


func _open_guide() -> void:
	OS.shell_open(ProjectSettings.globalize_path(GUIDE))


func _open_content() -> void:
	EditorInterface.edit_resource(Content.data())
	_say("The content list is in the Inspector. Drag scenes into it, or untick 'Enabled' on a boss.")


func _say(text: String) -> void:
	_status.text = text
	print("[Sonic Escape] ", text)
