@tool
extends RefCounted
# Makes new characters, bosses and levels by copying a working one

const BOSS_TEMPLATE := "res://Templates/Boss/Boss_Template.tscn"
const LEVEL_TEMPLATE := "res://Templates/Level/Level_Template.tscn"
const ANY_CHARACTER := "res://Scripts/Characters/any_character.gd"
const CUSTOM_ENEMY := "res://Scripts/Obstacles/Enemies/custom_enemy.gd"
# Starting points for a new enemy
const ENEMY_TEMPLATES := {
	"Egg Pawn (walks)": "res://Templates/Enemy/Enemy_Ground.tscn",
	"Flapper (flies)": "res://Templates/Enemy/Enemy_Flying.tscn",
}

# Files that were just copied and need importing before they can be loaded
var to_import: PackedStringArray = []
var _finish: Callable


# "my boss 2!" -> "MyBoss2"
static func clean_name(text: String) -> String:
	var out := ""
	for word in text.strip_edges().split(" ", false):
		var w := ""
		for ch in word:
			if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_":
				w += ch
		if w != "":
			out += w[0].to_upper() + w.substr(1)
	return out


# Copy a character
func make_character(id: String, from_id: String) -> String:
	id = clean_name(id)
	if id == "":
		return "!Type a name first."
	if Content.character(id):
		return "!There's already a character called %s." % id
	var source := Content.character(from_id)
	if source == null or source.scene == null:
		return "!Pick a character to copy."
	var folder := "res://Scenes/Characters/%s/" % id
	if DirAccess.dir_exists_absolute(folder):
		return "!The folder %s already exists." % folder
	DirAccess.make_dir_recursive_absolute(folder)
	var src_path := source.scene.resource_path
	var text := FileAccess.get_file_as_string(src_path)
	var moves := {}   # old path -> new path
	# The no-code character script
	var root_script := _root_value(text, "script")
	if root_script != "":
		moves[root_script] = ANY_CHARACTER
		var skip := _unused_abilities(text, FileAccess.get_file_as_string(root_script))
		if not skip.is_empty():
			text = _set_root_value(text, "skip_abilities", "Array[String](%s)" % JSON.stringify(skip))
	# Its own copy of the sprite sheet and the HUD icons
	var sheet := _node_value(text, "Sprite2D", ".", "texture")
	if sheet != "":
		moves[sheet] = folder + id.to_snake_case() + "_sheet." + sheet.get_extension()
	for key in ["icon_character", "icon_background"]:
		var p := _root_value(text, key)
		if p != "":
			moves[p] = folder + key.replace("icon_character", "hud_icon").replace("icon_background", "hud_panel") + "." + p.get_extension()
	var scene_path := folder + id + ".tscn"
	for from in moves:
		if moves[from] == ANY_CHARACTER:
			continue
		DirAccess.copy_absolute(from, moves[from])
		_copy_import_settings(from, moves[from])
		to_import.append(moves[from])
	_write_scene(text, scene_path, moves)
	# Character select pictures
	var pics := {}
	for key in ["select_icon", "select_icon_active", "select_highlight"]:
		var tex: Texture2D = source.get(key)
		if tex:
			var dst: String = folder + key + "." + tex.resource_path.get_extension()
			DirAccess.copy_absolute(tex.resource_path, dst)
			_copy_import_settings(tex.resource_path, dst)
			to_import.append(dst)
			pics[key] = dst
	_finish = func() -> void:
		var entry := CharacterEntry.new()
		entry.id = id
		entry.scene = load(scene_path)
		for key in pics:
			entry.set(key, load(pics[key]))
		entry.hover_color = source.hover_color
		Content.data().characters.append(entry)
		_save()
	return scene_path


# A new boss from the template
func make_boss(boss_name: String) -> String:
	var id := clean_name(boss_name)
	if id == "":
		return "!Type a name first."
	var folder := "res://Scenes/Bosses/%s/" % id
	if DirAccess.dir_exists_absolute(folder):
		return "!The folder %s already exists." % folder
	DirAccess.make_dir_recursive_absolute(folder)
	var moves := {
		"res://Templates/Boss/template_boss.gd": folder + id.to_snake_case() + ".gd",
		"res://Sprites/Obstacles/Enemies/flapper.png": folder + id.to_snake_case() + ".png",   # its own copy to paint over
	}
	for from in moves:
		DirAccess.copy_absolute(from, moves[from])
	to_import.append(moves["res://Sprites/Obstacles/Enemies/flapper.png"])
	var arena_path := folder + id + "_Arena.tscn"
	var text := FileAccess.get_file_as_string(BOSS_TEMPLATE)
	text = text.replace('boss_name = "Template Boss"', 'boss_name = "%s"' % boss_name.strip_edges().c_escape())
	_write_scene(text, arena_path, moves)
	_finish = func() -> void:
		var entry := BossEntry.new()
		entry.display_name = boss_name.strip_edges()
		entry.arena = load(arena_path)
		Content.data().bosses.append(entry)
		_save()
	return arena_path


# A new level chunk, copied from the template or another chunk
func make_level(level_name: String, from_path: String) -> String:
	var id := clean_name(level_name)
	if id == "":
		return "!Type a name first."
	var path := "res://Scenes/LevelChunks/Custom/%s.tscn" % id
	if FileAccess.file_exists(path):
		return "!%s already exists." % path
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_write_scene(FileAccess.get_file_as_string(from_path if from_path != "" else LEVEL_TEMPLATE), path, {})
	_finish = func() -> void:
		Content.data().level_chunks.append(load(path))
		_save()
	return path


# A new enemy, copied from a template or another enemy made this way
func make_enemy(enemy_name: String, from_path: String) -> String:
	var id := clean_name(enemy_name)
	if id == "":
		return "!Type a name first."
	var folder := "res://Scenes/Enemies/%s/" % id
	if DirAccess.dir_exists_absolute(folder):
		return "!The folder %s already exists." % folder
	var text := FileAccess.get_file_as_string(from_path)
	if not text.contains(CUSTOM_ENEMY):
		return "!Pick a template, or an enemy made with this panel, to copy."
	DirAccess.make_dir_recursive_absolute(folder)
	var moves := {}
	var sheet := _node_value(text, "Sprite2D", ".", "texture")
	if sheet != "":
		moves[sheet] = folder + id.to_snake_case() + "." + sheet.get_extension()   # its own copy to paint over
		DirAccess.copy_absolute(sheet, moves[sheet])
		to_import.append(moves[sheet])
	# The root node takes the enemy's name
	var root_line := text.substr(text.find("[node name=\""))
	root_line = root_line.substr(0, root_line.find("]") + 1)
	var old_name := root_line.get_slice("\"", 1)
	text = text.replace(root_line, root_line.replace('name="%s"' % old_name, 'name="%s"' % id))
	var path := folder + id + ".tscn"
	_write_scene(text, path, moves)
	_finish = func() -> void:
		Content.data().enemies.append(load(path))
		_save()
	return path


# A new Miku look or OC
func make_rescue(rescue_name: String, from_picture: String, is_oc: bool) -> String:
	var id := clean_name(rescue_name)
	if id == "":
		return "!Type a name first."
	if from_picture == "" or not FileAccess.file_exists(from_picture):
		return "!Pick a Miku look or OC to copy."
	var folder := "res://Sprites/Obstacles/%s/Custom/" % ("Ocs" if is_oc else "Miku")
	var path := folder + id.to_snake_case() + "." + from_picture.get_extension()
	if FileAccess.file_exists(path):
		return "!%s already exists." % path
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.copy_absolute(from_picture, path)
	to_import.append(path)
	var size := 1.0
	for entry in Content.data().ocs:
		if entry and entry.picture and entry.picture.resource_path == from_picture:
			size = entry.size
	_finish = func() -> void:
		if is_oc:
			var entry := OcEntry.new()
			entry.picture = load(path)
			entry.size = size
			Content.data().ocs.append(entry)
		else:
			Content.data().miku_looks.append(load(path))
		_save()
	return path


# Called by the panel once the copied files are imported
func finish() -> void:
	if _finish.is_valid():
		_finish.call()


func _save() -> void:
	ResourceSaver.save(Content.data(), Content.PATH)


# Writes a copy of a scene file
static func _copy_import_settings(from: String, to: String) -> void:
	var src := ConfigFile.new()
	if src.load(from + ".import") != OK or not src.has_section("params"):
		return
	var dst := ConfigFile.new()
	dst.set_value("remap", "importer", src.get_value("remap", "importer", "texture"))
	dst.set_value("remap", "type", src.get_value("remap", "type", "CompressedTexture2D"))
	for key in src.get_section_keys("params"):
		dst.set_value("params", key, src.get_value("params", key))
	dst.save(to + ".import")


static func _write_scene(text: String, path: String, moves: Dictionary) -> void:
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i]
		if line.begins_with("[gd_scene"):
			lines[i] = _drop_attr(line, "uid")
		elif line.begins_with("[ext_resource"):
			for from in moves:
				if line.contains('path="%s"' % from):
					lines[i] = _drop_attr(line.replace('path="%s"' % from, 'path="%s"' % moves[from]), "uid")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()


static func _drop_attr(line: String, attr: String) -> String:
	var rx := RegEx.create_from_string(" %s=\"[^\"]*\"" % attr)
	return rx.sub(line, "")


# Ability nodes that a character script never calls action on
static func _unused_abilities(scene_text: String, script_text: String) -> Array[String]:
	var called := {}
	var var_rx := RegEx.create_from_string("(?m)^@onready var (\\w+)[^=\\n]*= \\$\"?([^\"\\n]+)\"?")
	for m in var_rx.search_all(script_text):
		var call_rx := RegEx.create_from_string("(?m)^[ \\t]+%s\\.action\\(\\)" % m.get_string(1))
		if call_rx.search(script_text):
			called[m.get_string(2).strip_edges()] = true
	var out: Array[String] = []
	var node_rx := RegEx.create_from_string("(?m)^\\[node name=\"([^\"]+)\" parent=\"\\.\"[^\\]]*instance=ExtResource\\(\"([^\"]+)\"\\)")
	for m in node_rx.search_all(scene_text):
		if _ext_path(scene_text, m.get_string(2)).contains("/Components/") and not called.has(m.get_string(1)):
			out.append(m.get_string(1))
	return out


# Adds a property line on the scene's root node
static func _set_root_value(text: String, key: String, value: String) -> String:
	var lines := text.split("\n")
	var in_root := false
	for i in lines.size():
		if lines[i].begins_with("[node"):
			if in_root:
				lines.insert(i, "%s = %s" % [key, value])
				return "\n".join(lines)
			in_root = not lines[i].contains(" parent=")
		elif in_root and lines[i].begins_with(key + " = "):
			lines[i] = "%s = %s" % [key, value]
			return "\n".join(lines)
	return text


# The file path behind a property of the scene's root node, like its script
static func _root_value(text: String, key: String) -> String:
	var block := _node_block(text, "", "")
	return _ext_path(text, _ext_id(block, key))


static func _node_value(text: String, node_name: String, parent: String, key: String) -> String:
	var block := _node_block(text, node_name, parent)
	return _ext_path(text, _ext_id(block, key))


# The lines of one node in a scene file
static func _node_block(text: String, node_name: String, parent: String) -> String:
	var out := ""
	var inside := false
	for line in text.split("\n"):
		if line.begins_with("["):
			if inside:
				break
			if line.begins_with("[node"):
				var is_root := not line.contains(" parent=")
				inside = is_root if node_name == "" else (line.contains('name="%s"' % node_name) and line.contains('parent="%s"' % parent))
			continue
		if inside:
			out += line + "\n"
	return out


static func _ext_id(block: String, key: String) -> String:
	var rx := RegEx.create_from_string("(?m)^%s = ExtResource\\(\"([^\"]+)\"\\)" % key)
	var m := rx.search(block)
	return m.get_string(1) if m else ""


static func _ext_path(text: String, id: String) -> String:
	if id == "":
		return ""
	var rx := RegEx.create_from_string("\\[ext_resource [^\\]]*path=\"([^\"]+)\"[^\\]]* id=\"%s\"" % id)
	var m := rx.search(text)
	return m.get_string(1) if m else ""
