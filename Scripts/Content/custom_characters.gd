class_name CustomCharacters
extends RefCounted
# Characters added without Godot

const DIR := "user://characters/"
const INFO := "character.txt"
const PICTURES := ["sheet.png", "icon.png", "highlight.png", "hud.png"]
const SOUNDS := ["ogg", "wav", "mp3"]
const MAX_VOICES := 12
const MAX_FILE := 4 * 1024 * 1024
const MAX_PACK := 8 * 1024 * 1024
const MAX_PICTURE := 4096
const ICON_MAX := 1024      # portraits are kept at most this big

static var _sounds := {}    # "cc:<id>/<file>" -> AudioStream
static var _signature := ""
static var problems: Array[String] = []   # folders that didn't load, and why


static func is_custom(id: String) -> bool:
	return id.contains("~")


static func sound(path: String) -> AudioStream:
	return _sounds.get(path)


# Read every folder again, replacing the custom characters in the list
static func load_all(data: GameContent) -> void:
	if data == null:
		return
	var kept: Array[CharacterEntry] = []
	for e in data.characters:
		if e and e.custom_dir == "":
			kept.append(e)
	data.characters = kept
	_sounds.clear()
	problems.clear()
	_signature = signature()
	for folder in _folders(DIR):
		var files := _read_folder(DIR + folder + "/")
		if files.is_empty():
			continue
		var bytes := _pack_files(files)
		var id := _clean(folder) + "~" + _hash(bytes)
		var e := _build(data, id, files, DIR + folder + "/")
		if e:
			data.characters.append(e)


# Something in the characters folder changed since it was read
static func changed() -> bool:
	return signature() != _signature


static func signature() -> String:
	var out := ""
	for folder in _folders(DIR):
		var path := DIR + folder + "/"
		out += folder + ":"
		for f in DirAccess.get_files_at(path):
			out += "%s%d," % [f, FileAccess.get_modified_time(path + f)]
	return out

# A new character from pictures anywhere on the computer
static func create(char_name: String, base_id: String, sheet_path: String, portrait_path: String) -> String:
	var clean := _clean(char_name.replace(" ", "_"))
	if clean == "":
		return "Type a name first"
	var sheet := Image.load_from_file(sheet_path)
	if sheet == null or sheet.is_empty():
		return "%s isn't a picture the game can read" % sheet_path.get_file()
	if sheet.get_width() > MAX_PICTURE or sheet.get_height() > MAX_PICTURE:
		return "That sheet is too big (%d pixels at most)" % MAX_PICTURE
	var portrait: Image = null
	if portrait_path != "":
		portrait = Image.load_from_file(portrait_path)
		if portrait == null or portrait.is_empty():
			return "%s isn't a picture the game can read" % portrait_path.get_file()
		_shrink(portrait, ICON_MAX)
	DirAccess.make_dir_recursive_absolute(DIR)
	_write_readme()
	var folder := DIR + clean + "/"
	var n := 1
	while DirAccess.dir_exists_absolute(folder):
		n += 1
		folder = DIR + "%s%d/" % [clean, n]
	DirAccess.make_dir_recursive_absolute(folder)
	if sheet.save_png(folder + "sheet.png") != OK:
		return "Couldn't save into the characters folder"
	if portrait:
		portrait.save_png(folder + "icon.png")
	var f := FileAccess.open(folder + INFO, FileAccess.WRITE)
	if f:
		f.store_string((EXAMPLE_INFO % base_id).replace("name = My Character", "name = " + char_name.strip_edges().substr(0, 24)))
		f.close()
	return ""


# A built-in character's sheet, saved where you like, to draw your own over
static func save_template(base_id: String, path: String) -> String:
	var base := Content.character(base_id)
	if base == null or base.scene == null:
		return "No character called %s" % base_id
	var node := base.scene.instantiate()
	var spr := node.get_node_or_null("Sprite2D") as Sprite2D
	var img: Image = spr.texture.get_image() if spr and spr.texture else null
	node.free()
	if img == null:
		return "Couldn't read %s's sheet" % base_id
	if img.is_compressed():
		img.decompress()
	if not path.get_extension().to_lower() == "png":
		path += ".png"
	return "" if img.save_png(path) == OK else "Couldn't save %s" % path.get_file()


const EXAMPLE_INFO := """# Your character. Paint over sheet.png (keep every pose in the same square) and icon.png.
# Lines starting with # are notes

# The name on the screens
name = My Character

# Whose moves you get, and whose sheet layout yours follows
based_on = %s

# Colour when hovered on the character select screen
color = #ff4040

# How fast and how high, compared with the base character
speed = 1.0
jump = 1.0
"""

const README := """CUSTOM CHARACTERS

Every folder in here is a character. Pick them from the CUSTOM window on the
character select screen.

The easy way: CUSTOM, then NEW, then pick your sprite sheet (and a portrait if
you like). Or make a folder here yourself with:
  sheet.png       the sprite sheet, in the same layout as the character whose moves
                  it has (TEMPLATE in the NEW window saves theirs to draw over). A
                  bigger sheet with the same grid shows in more detail.
  character.txt   the name, whose moves you get (based_on), colour, speed and jump
  icon.png        the portrait (made from the sheet if you leave it out)
  highlight.png   the big picture once you've picked it (the portrait if left out)
  hud.png         the picture by your rings (the portrait if left out)
  .ogg/.wav/.mp3  voice lines, said now and then like the others' (up to 12)

After changing files here, click back into the game window on the character
select screen to see them.
"""


static func make_folder() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_write_readme()


static func _write_readme() -> void:
	if FileAccess.file_exists(DIR + "README.txt"):
		return
	var f := FileAccess.open(DIR + "README.txt", FileAccess.WRITE)
	if f:
		f.store_string(README)
		f.close()


# BUILDING ONE

static func _build(data: GameContent, id: String, files: Dictionary, dir: String) -> CharacterEntry:
	var folder := id.get_slice("~", 0)
	if not files.has("sheet.png"):
		problems.append("%s: no sheet.png" % folder)
		return null
	var info := _info(_text(files.get(INFO, PackedByteArray())))
	var base := _built_in(data, str(info.get("based_on", info.get("base", "Sonic"))))
	if base == null:
		base = _built_in(data, "Sonic")
	if base == null or base.scene == null:
		return null
	var node := base.scene.instantiate()
	var spr := node.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or spr.texture == null:
		node.free()
		return null
	var sheet := _picture(files["sheet.png"])
	if sheet == null:
		node.free()
		problems.append("%s: sheet.png isn't a picture the game can read" % folder)
		return null
	var grid := Vector2i(spr.texture.get_size())
	spr.texture = _fit_sheet(sheet, grid)
	# The portrait: icon.png, or the first pose from the sheet
	var portrait: Image = _picture(files.get("icon.png", PackedByteArray()))
	var from_sheet := portrait == null
	var pose := _pose(sheet, spr.hframes, spr.vframes, _stance_frame(node))
	if from_sheet:
		portrait = pose
	var e := CharacterEntry.new()
	e.id = id
	e.custom_dir = dir
	e.base_id = base.id
	e.display_name = str(info.get("name", folder)).strip_edges().substr(0, 24)
	if e.display_name == "":
		e.display_name = folder
	e.select_icon = base.select_icon
	e.select_icon_active = _fit_picture(portrait, _size_of(base.select_icon_active, Vector2i(2654, 1758)))
	var big: Image = _picture(files.get("highlight.png", PackedByteArray()))
	if big == null:
		big = _padded(_big_pixels(_outlined(pose), 6), 2.4) if from_sheet else portrait   # the pose, big and sharp, all of it in view
	e.select_highlight = _fit_picture(big, _size_of(base.select_highlight, Vector2i(3850, 3489)))
	e.hover_color = _colour(info, base.hover_color)
	if e.hover_color != base.hover_color and "music_color" in node:
		node.music_color = e.hover_color
	var hud: Image = _picture(files.get("hud.png", PackedByteArray()))
	if "icon_character" in node:
		if hud == null:
			# By your rings
			hud = _placed(_bust(pose), _size_of(node.icon_character, Vector2i(2654, 1758)), 0.8, 0.14) if from_sheet else portrait
		node.icon_character = _fit_picture(hud, _size_of(node.icon_character, Vector2i(2654, 1758)))
	if "character_id" in node:
		node.character_id = id
	# Speed and jump, a little either way
	var speed := clampf(float(info.get("speed", "1")), 0.5, 1.5) if str(info.get("speed", "1")).is_valid_float() else 1.0
	var jump := clampf(float(info.get("jump", "1")), 0.5, 1.6) if str(info.get("jump", "1")).is_valid_float() else 1.0
	if speed != 1.0:
		for key in ["max_speed", "acc", "BASE_MAX_SPEDD", "MAX_SPEED", "ABOSLUTE_MAX_SPEED", "MAX_LOW_SPEED"]:
			if key in node:
				node.set(key, node.get(key) * speed)
	if jump != 1.0 and "jump_height" in node:
		node.jump_height *= jump
	# Voice lines
	var voices: Array = []
	var names: Array = files.keys()
	names.sort()
	for f in names:
		if voices.size() >= MAX_VOICES or not str(f).get_extension().to_lower() in SOUNDS:
			continue
		var s := _sound(files[f], str(f).get_extension().to_lower())
		if s:
			var path := "cc:%s/%s" % [id, f]
			s.set_meta("cc_path", path)
			_sounds[path] = s
			voices.append(s)
	if not voices.is_empty() and "audio_files" in node:
		node.audio_files = voices
	var scene := PackedScene.new()
	var err := scene.pack(node)
	node.free()
	if err != OK:
		return null
	e.scene = scene
	return e


static func _built_in(data: GameContent, id: String) -> CharacterEntry:
	for e in data.characters:
		if e and e.custom_dir == "" and e.id.to_lower() == id.strip_edges().to_lower().replace(" ", ""):
			return e
	return null


static func _find(data: GameContent, id: String) -> CharacterEntry:
	for e in data.characters:
		if e and e.id == id:
			return e
	return null


static func _size_of(tex: Texture2D, fallback: Vector2i) -> Vector2i:
	return Vector2i(tex.get_size()) if tex else fallback


static func _picture(bytes: PackedByteArray) -> Image:
	if bytes.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK or img.is_empty():
		return null
	if img.get_width() > MAX_PICTURE or img.get_height() > MAX_PICTURE:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


# The sheet at the base's size
static func _fit_sheet(img: Image, base: Vector2i) -> ImageTexture:
	var k := maxi(1, roundi(float(img.get_width()) / base.x))
	k = mini(k, 8)
	if img.get_size() != base * k:
		img.resize(base.x * k, base.y * k, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	if k > 1:
		tex.set_size_override(base)
	return tex


# A picture shown where the built-in one would be
static func _fit_picture(src: Image, shape: Vector2i) -> ImageTexture:
	var img := src.duplicate() as Image
	var aspect := float(shape.x) / shape.y
	var w := img.get_width()
	var h := img.get_height()
	var cw := maxi(w, roundi(h * aspect))
	var ch := maxi(h, roundi(w / aspect))
	if cw != w or ch != h:
		var canvas := Image.create_empty(cw, ch, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((cw - w) / 2, (ch - h) / 2))
		img = canvas
	var small := img.get_width() < 256
	_shrink(img, ICON_MAX)
	if small:
		# Pixel art: blow it up sharp
		var k := maxi(1, 256 / img.get_width())
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(shape)
	return tex


static func _padded(img: Image, by: float) -> Image:
	var w := roundi(img.get_width() * by)
	var h := roundi(img.get_height() * by)
	var canvas := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), (Vector2i(w, h) - img.get_size()) / 2)
	return canvas


static func _shrink(img: Image, longest: int) -> void:
	var big := maxi(img.get_width(), img.get_height())
	if big > longest:
		var f := float(longest) / big
		img.resize(maxi(1, roundi(img.get_width() * f)), maxi(1, roundi(img.get_height() * f)), Image.INTERPOLATE_LANCZOS)


static func _colour(info: Dictionary, fallback: Color) -> Color:
	var c := str(info.get("color", info.get("colour", "")))
	return Color.html(c) if Color.html_is_valid(c) else fallback


# Which pose the character stands in
static func _stance_frame(node: Node) -> int:
	var ap := node.find_child("AnimationPlayer", false, false) as AnimationPlayer
	if ap == null or not ap.has_animation("stance"):
		return 0
	var a := ap.get_animation("stance")
	for t in a.get_track_count():
		if str(a.track_get_path(t)) == "Sprite2D:frame" and a.track_get_key_count(t) > 0:
			return int(a.track_get_key_value(t, 0))
	return 0


# One pose from the sheet, cropped to what's drawn
static func _pose(sheet: Image, hframes: int, vframes: int, frame: int) -> Image:
	var fw := sheet.get_width() / maxi(1, hframes)
	var fh := sheet.get_height() / maxi(1, vframes)
	var cell := Vector2i(frame % maxi(1, hframes), frame / maxi(1, hframes))
	var pose := sheet.get_region(Rect2i(cell.x * fw, cell.y * fh, fw, fh))
	var used := pose.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		pose = sheet.get_region(Rect2i(0, 0, fw, fh))
		used = pose.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		pose = pose.get_region(used)
	return pose


# A one-pixel black outline round what's drawn, like the sprites in the game
static func _outlined(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.3:
				for d in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]:
					out.set_pixelv(Vector2i(x, y) + d, Color.BLACK)
	out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ONE)
	return out


# A picture on a see-through canvas the shape of `shape`
static func _placed(img: Image, shape: Vector2i, fill: float, right: float) -> Image:
	var h := roundi(img.get_height() / fill)
	var w := maxi(roundi(h * float(shape.x) / shape.y), img.get_width())
	var canvas := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var x := clampi((w - img.get_width()) / 2 + roundi(w * right), 0, w - img.get_width())
	canvas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, h - img.get_height()))
	return canvas


# The top of a pose
static func _bust(pose: Image) -> Image:
	var h := maxi(1, roundi(pose.get_height() * 0.55))
	var bust := pose.get_region(Rect2i(0, 0, pose.get_width(), h))
	var used := bust.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		bust = bust.get_region(Rect2i(used.position.x, 0, used.size.x, h))
	return bust


static func _big_pixels(img: Image, k: int) -> Image:
	var big := img.duplicate() as Image
	big.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return big


static func _sound(bytes: PackedByteArray, ext: String) -> AudioStream:
	if bytes.is_empty():
		return null
	match ext:
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		"wav":
			return AudioStreamWAV.load_from_buffer(bytes)
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			return mp3 if mp3.get_length() > 0.0 else null
	return null


# character.txt
static func _info(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		line = line.strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with(";") or not line.contains("="):
			continue
		var key := line.get_slice("=", 0).strip_edges().to_lower().replace(" ", "_")
		var value := line.substr(line.find("=") + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		out[key] = value
	return out


static func _text(bytes: PackedByteArray) -> String:
	return bytes.get_string_from_utf8() if not bytes.is_empty() else ""


# FILES

static func _folders(dir: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	var out := PackedStringArray()
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and _clean(d) != "":
			out.append(d)
	out.sort()
	return out


static func _read_folder(path: String) -> Dictionary:
	var files := {}
	var total := 0
	var names := Array(DirAccess.get_files_at(path))
	names.sort()
	for f in names:
		var low := str(f).to_lower()
		if not (low == INFO or low in PICTURES or low.get_extension() in SOUNDS):
			continue
		var bytes := FileAccess.get_file_as_bytes(path + f)
		if bytes.is_empty() or bytes.size() > MAX_FILE or total + bytes.size() > MAX_PACK:
			continue
		total += bytes.size()
		files[low] = bytes
	return files


static func _pack_files(files: Dictionary) -> PackedByteArray:
	var names: Array = files.keys()
	names.sort()
	var ordered := {}
	for f in names:
		ordered[f] = files[f]
	return var_to_bytes(ordered)

static func _hash(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 8)

# "My Guy!" -> "MyGuy"
static func _clean(text: String) -> String:
	var out := ""
	for ch in text:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
	return out.substr(0, 24)
