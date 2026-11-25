extends VBoxContainer
# Under your character's icon

const AT := Vector2(24, 138)       # just below the icon, rings and meter
const FONT_SIZE := 16
const LINE_HEIGHT := 20.0
const COLOR := Color(0.85, 0.95, 1.0)
const SCORE_SIZE := 22
const USED := Color(0.5, 0.55, 0.6)   # a shield already used this floor

var _shown := ""


func _ready() -> void:
	position = AT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	var tick := Timer.new()
	tick.wait_time = 0.25
	tick.autostart = true
	tick.timeout.connect(_refresh)
	add_child(tick)
	_refresh()


# [what it says, still working, size] for the score and each upgrade you have
func _lines() -> Array:
	var out := []
	var here := get_tree().current_scene
	if here == null or not here.scene_file_path.ends_with("test3.tscn"):
		return out   # only in the side-scrolling levels
	out.append(["Score %d" % Test.run_score().total, true, SCORE_SIZE])
	if Test.meter_bonus > 0:
		out.append(["+%d max meter" % Test.meter_bonus, true])
	if Test.full_meter_each_floor:
		out.append(["Full meter every floor", true])
	if Test.boost_bonus > 0:
		out.append(["Boost +%d%%" % Test.boost_bonus, true])
	if Test.speed_bonus > 0:
		out.append(["Run +%d%%" % Test.speed_bonus, true])
	if Test.jump_bonus > 0:
		out.append(["Jump +%d%%" % Test.jump_bonus, true])
	if Test.meter_scale < 1.0:
		out.append(["Moves use %d%% less meter" % roundi((1.0 - Test.meter_scale) * 100.0), true])
	if Test.ring_loss_scale < 1.0:
		out.append(["Lose %d%% fewer rings" % roundi((1.0 - Test.ring_loss_scale) * 100.0), true])
	if Test.boss_hits > 1:
		out.append(["Boss hits x%d" % Test.boss_hits, true])
	if Test.extra_lives > 0:
		out.append(["Extra life" if Test.extra_lives == 1 else "%d extra lives" % Test.extra_lives, true])
	if Test.fly_bonus > 0:
		out.append(["Fly %d%% longer" % Test.fly_bonus, true])
	if Test.trick_meter_bonus > 0:
		out.append(["Tricks +%d%% meter" % Test.trick_meter_bonus, true])
	if Test.salvage_stuns > 0:
		out.append(["Stun hunters" if Test.salvage_stuns == 1 else "Stun hunters x%d" % Test.salvage_stuns, true])
	if Test.salvage_saves > 0:
		out.append(["Survive a hunter" if Test.salvage_saves == 1 else "Survive a hunter x%d" % Test.salvage_saves, true])
	if Test.chaos_emeralds > 0:
		out.append(["Chaos Emeralds %d/7" % Test.chaos_emeralds, true])
		out.append(["@gems", true, Test.chaos_emeralds])   # and the ones you have, each its own colour
	if Test.super_emeralds > 0:
		out.append(["Super Emeralds %d/7" % Test.super_emeralds + ("  HYPER!" if Test.super_emeralds >= Test.SUPER_EMERALDS else ""), true])
		out.append(["@supergems", true, Test.super_emeralds])
	if Test.shields_left > 0 or Test.shields_each_floor > 0:
		var what := "Shield" if Test.shields_left <= 1 else "%d shields" % Test.shields_left
		if Test.shields_each_floor > 0:
			what += " (one every floor)"
		out.append([what, Test.shields_left > 0])
	return out


func _refresh() -> void:
	var lines := _lines()
	var key := str(lines)
	if key == _shown:
		return
	_shown = key
	for c in get_children():
		if not (c is Timer):
			c.queue_free()
	for l in lines:
		if l[0] == "@gems" or l[0] == "@supergems":
			add_child(_gems(int(l[2]), l[0] == "@supergems"))
			continue

		var row := Control.new()
		var px: int = l[2] if l.size() > 2 else FONT_SIZE
		row.custom_minimum_size = Vector2(0, LINE_HEIGHT * px / FONT_SIZE)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var label := Label.new()
		label.text = l[0]
		label.add_theme_font_size_override("font_size", px)
		label.add_theme_color_override("font_color", (Color.WHITE if l.size() > 2 else COLOR) if l[1] else USED)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position.y = (row.custom_minimum_size.y - label.get_minimum_size().y) * 0.5
		row.add_child(label)


# The emeralds you've got, in their colours
const GEM_SIZE := 30
const GEM_FRAMES := 9
const GEMS := ["res://Sprites/Salvage/Emeralds/emerald_1_green.png", "res://Sprites/Salvage/Emeralds/emerald_2_red.png",
	"res://Sprites/Salvage/Emeralds/emerald_3_blue.png", "res://Sprites/Salvage/Emeralds/emerald_4_yellow.png",
	"res://Sprites/Salvage/Emeralds/emerald_5_cyan.png", "res://Sprites/Salvage/Emeralds/emerald_6_purple.png",
	"res://Sprites/Salvage/Emeralds/emerald_7_white.png"]

# Just the gem from the first frame
static var _gem_texs := {}

static func _gem_tex(tex: Texture2D) -> Texture2D:
	if _gem_texs.has(tex.resource_path):
		return _gem_texs[tex.resource_path]
	var r := Rect2i(_gem_rect(tex))
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img = img.get_region(r)
	img.convert(Image.FORMAT_RGBA8)
	# a white pixel not touching the gem's colour is a sparkle
	for pass_i in 3:
		var gone: Array[Vector2i] = []
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.5 or not (c.r > 0.99 and c.g > 0.99 and c.b > 0.99):
					continue
				var touches := false
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= img.get_width() or ny >= img.get_height():
							continue
						var n := img.get_pixel(nx, ny)
						if n.a > 0.5 and not (n.r > 0.99 and n.g > 0.99 and n.b > 0.99):
							touches = true
				if not touches:
					gone.append(Vector2i(x, y))
		for g in gone:
			img.set_pixelv(g, Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	_gem_texs[tex.resource_path] = out
	return out


# The part of the first frame the gem is drawn in, with a pixel to spare
static var _rects := {}

static func _gem_rect(tex: Texture2D) -> Rect2:
	if _rects.has(tex.resource_path):
		return _rects[tex.resource_path]
	var w := tex.get_width() / GEM_FRAMES
	var r := Rect2(0, 0, w, tex.get_height())
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		# the gem itself
		var lo := Vector2i(w, img.get_height())
		var hi := Vector2i(-1, -1)
		for y in img.get_height():
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and not (c.r > 0.99 and c.g > 0.99 and c.b > 0.99):
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		if hi.x >= lo.x:
			r = Rect2(Rect2i(lo, hi - lo + Vector2i.ONE).grow(2)).intersection(r)
	_rects[tex.resource_path] = r
	return r


func _gems(count: int, super_ones := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in mini(count, GEMS.size()):
		var tex: Texture2D = load(GEMS[i].replace("/emerald_", "/super_emerald_") if super_ones else GEMS[i])
		var at := _gem_tex(tex)   # just the gem, all of it
		var r := TextureRect.new()
		r.texture = at
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.custom_minimum_size = Vector2(GEM_SIZE, GEM_SIZE)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	return row
