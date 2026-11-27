@tool
extends ScrollContainer
# The Sonic Escape panel

const Maker := preload("res://addons/sonic_escape_tools/content_maker.gd")
const GAME_SCENE := "res://Scenes/Level/test3.tscn"
# The Place buttons
const PLACEABLE := {
	"Rings": ["res://Scenes/Obstacles/Rings/ring_strand.tscn", "Rings"],
	"Spring": ["res://Scenes/Obstacles/Spring/Spring.tscn", "Level"],
	"Rail": ["res://Scenes/Obstacles/Rail/Rail.tscn", "Level"],
	"Loop": ["res://Scenes/Obstacles/Loop/loop.tscn", "Level"],
}

var _status: Label
var _play_as: OptionButton
var _lists := {}       # "characters" / "bosses" / "levels" / "enemies" / "rescues" -> OptionButton
var _names := {}       # same keys -> LineEdit for the new one's name
var _copy_from := {}   # "characters" / "levels" / "enemies" / "rescues" -> OptionButton
var _filled := false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var intro := Label.new()
	intro.text = "Make a new character, boss, level, enemy or Miku from a working copy, then press Play to try it."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var top := HBoxContainer.new()
	box.add_child(top)
	_button(top, "Content list", _open_content)

	_section(box, "characters", "Characters", "character", "Copy of")
	_section(box, "bosses", "Bosses", "boss", "")
	_section(box, "levels", "Levels", "level", "Copy of")
	_section(box, "enemies", "Enemies", "enemy", "Copy of")
	_section(box, "rescues", "Mikus and OCs", "Miku or OC", "Copy of")

	# Place things in the open level, in the middle of the view
	box.add_child(HSeparator.new())
	var place_head := Label.new()
	place_head.text = "Place in the open level"
	place_head.add_theme_font_size_override("font_size", 18)
	box.add_child(place_head)
	var place := HFlowContainer.new()
	box.add_child(place)
	for what in PLACEABLE:
		_button(place, what, _place.bind(PLACEABLE[what][0], PLACEABLE[what][1]))
	_button(place, "Enemy", _place_enemy)

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
	# The lists load the whole content list
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


# Fill the lists from game_content.tres
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
	var enemies: OptionButton = _lists.enemies
	enemies.clear()
	_copy_from.enemies.clear()
	for template in Maker.ENEMY_TEMPLATES:
		_add(_copy_from.enemies, template, Maker.ENEMY_TEMPLATES[template])
	for scene in Content.enemies():
		var nice: String = {"enemy": "Egg Pawn", "enemyfly": "Flapper"}.get(scene.resource_path.get_file().get_basename(), scene.resource_path.get_file().get_basename())
		_add(enemies, nice, scene.resource_path)
		if FileAccess.get_file_as_string(scene.resource_path).contains(Maker.CUSTOM_ENEMY):
			_add(_copy_from.enemies, nice, scene.resource_path)
	var rescues: OptionButton = _lists.rescues
	rescues.clear()
	_copy_from.rescues.clear()
	for tex in Content.data().miku_looks:
		if tex:
			var nice := "Miku: " + tex.resource_path.get_file().get_basename()
			_add(rescues, nice, [tex.resource_path, false])
			_add(_copy_from.rescues, nice, [tex.resource_path, false])
	for entry in Content.data().ocs:
		if entry and entry.picture:
			var nice := "OC: " + (entry.credit if entry.credit != "" else entry.picture.resource_path.get_file().get_basename())
			_add(rescues, nice, [entry.picture.resource_path, true])
			_add(_copy_from.rescues, nice, [entry.picture.resource_path, true])


func _add(pick: OptionButton, text: String, meta: Variant) -> void:
	pick.add_item(text)
	pick.set_item_metadata(pick.item_count - 1, meta)


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
		"rescues":
			return str(pick.get_item_metadata(pick.selected)[0])
		_:
			return str(pick.get_item_metadata(pick.selected))


func _open(key: String) -> void:
	var path := _selected_path(key)
	if path == "":
		_say("Pick one from the list first.")
		return
	if key == "rescues":
		# A picture: show it in the FileSystem and the Inspector
		EditorInterface.get_file_system_dock().navigate_to_path(path)
		EditorInterface.edit_resource(load(path))
		_say("%s is selected in the FileSystem. Paint over it in any drawing program (right-click > Open in External Program)." % path)
		return
	_open_scene(path)
	_say("Opened %s" % path)


func _play(key: String) -> void:
	var pick: OptionButton = _lists[key]
	if pick.selected < 0:
		_say("Pick one from the list first.")
		return
	var cfg := ConfigFile.new()
	cfg.set_value("play", "mode", {"characters": "character", "bosses": "boss", "levels": "level", "enemies": "enemy", "rescues": "rescue"}[key])
	var as_char := _play_as.get_item_text(_play_as.selected) if _play_as.selected >= 0 else "Sonic"
	match key:
		"characters":
			as_char = pick.get_item_text(pick.selected)
		"bosses":
			cfg.set_value("play", "arena", _selected_path(key))
		"levels":
			cfg.set_value("play", "chunk", _selected_path(key))
		"enemies":
			cfg.set_value("play", "enemy", _selected_path(key))
		"rescues":
			cfg.set_value("play", "look", _selected_path(key))
			cfg.set_value("play", "is_oc", bool(pick.get_item_metadata(pick.selected)[1]))
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
		"enemies":
			var from: OptionButton = _copy_from.enemies
			path = maker.make_enemy(name_text, str(from.get_item_metadata(from.selected)) if from.selected >= 0 else "")
		"rescues":
			var from: OptionButton = _copy_from.rescues
			var meta: Array = from.get_item_metadata(from.selected) if from.selected >= 0 else ["", false]
			path = maker.make_rescue(name_text, str(meta[0]), bool(meta[1]))
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
	for i in pick.item_count:
		var meta = pick.get_item_metadata(i)
		if (meta is Array and str(meta[0]) == path) or str(meta) == path:
			pick.select(i)
	if key == "rescues":
		_open(key)
		_say("Made %s and added it to the content list. Paint over it, then press Play to meet them." % path)
		return
	_open_scene(path)
	match key:
		"enemies":
			_say("Made %s. Click its root node to set how it moves and fights in the Inspector, press Play to try it, or open a level and press Place > Enemy." % path)
		_:
			_say("Made %s and added it to the content list. It's open now; press Play to try it." % path)


# Put a copy of a scene in the open level, in the middle of the view
func _place(scene_path: String, parent_name: String) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or not (root is Node2D):
		_say("Open a level first (Levels > Open).")
		return
	var parent: Node = root.get_node_or_null(parent_name)
	if parent == null:
		parent = root
	var thing: Node2D = load(scene_path).instantiate()
	var vp := EditorInterface.get_editor_viewport_2d()
	var middle: Vector2 = vp.global_canvas_transform.affine_inverse() * (Vector2(vp.size) * 0.5)
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Place %s" % thing.name)
	ur.add_do_method(parent, "add_child", thing, true)
	ur.add_do_method(thing, "set_owner", root)
	ur.add_do_property(thing, "global_position", middle)
	ur.add_do_reference(thing)
	ur.add_undo_method(parent, "remove_child", thing)
	ur.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(thing)
	_say("Placed %s in the middle of the view. Drag it where you want it (Ctrl+Z takes it back)." % thing.name)


func _place_enemy() -> void:
	var path := _selected_path("enemies")
	if path == "":
		_say("Pick an enemy in the Enemies list first.")
		return
	_place(path, "Enemies")


func _all_loadable(paths: PackedStringArray) -> bool:
	for p in paths:
		if not ResourceLoader.exists(p):
			return false
	return true


func _open_scene(path: String) -> void:
	EditorInterface.open_scene_from_path(path)
	EditorInterface.set_main_screen_editor("2D")

func _open_content() -> void:
	EditorInterface.edit_resource(Content.data())
	_say("The content list is in the Inspector. Drag scenes into it, or untick 'Enabled' on a boss.")


func _say(text: String) -> void:
	_status.text = text
	print("[Sonic Escape] ", text)
