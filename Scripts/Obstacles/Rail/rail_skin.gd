extends RefCounted
## Grind rails dressed to match each stage. A shaded pixel-art tube with brackets, in colours taken from
## that stage's Rush terrain tiles (Sprites/Tileset/RushAdventure), laid along the
## rail's path at the characters' pixel size. Called from Rail.gd.

const TEXEL_WORLD := 1.125   # world units per character art pixel
const TILE := 32             # art pixels between brackets

## Per background id (Background.gd): tube colours from dark to light, an outline,
## the bracket colour and an accent (the small light or stripe on each bracket).
const STAGES := {
	1: { # night city, neon tech: violet tube, red lights
		"outline": Color8(20, 12, 34), "dark": Color8(82, 41, 165), "mid": Color8(123, 82, 206),
		"light": Color8(198, 66, 255), "hi": Color8(255, 189, 247), "bracket": Color8(82, 66, 74), "accent": Color8(255, 0, 0)},
	2: { # sunset, brick ruins: brass, rust-red
		"outline": Color8(28, 20, 10), "dark": Color8(107, 90, 57), "mid": Color8(140, 123, 90),
		"light": Color8(181, 165, 123), "hi": Color8(239, 239, 206), "bracket": Color8(70, 52, 30), "accent": Color8(189, 49, 0)},
	4: { # purple town, rooftops: pale stone and wood
		"outline": Color8(40, 32, 20), "dark": Color8(119, 105, 76), "mid": Color8(170, 160, 132),
		"light": Color8(213, 205, 180), "hi": Color8(250, 248, 232), "bracket": Color8(55, 47, 31), "accent": Color8(170, 60, 45)},
	5: { # grey city, industrial: steel with caution-orange brackets
		"outline": Color8(0, 0, 0), "dark": Color8(74, 90, 107), "mid": Color8(108, 126, 144),
		"light": Color8(160, 178, 192), "hi": Color8(232, 240, 245), "bracket": Color8(99, 41, 8), "accent": Color8(255, 140, 0), "stripes": true},
	6: { # every 4th floor, teal tech: teal tube, green lights
		"outline": Color8(0, 30, 22), "dark": Color8(0, 74, 57), "mid": Color8(0, 99, 82),
		"light": Color8(82, 189, 231), "hi": Color8(198, 247, 255), "bracket": Color8(0, 49, 33), "accent": Color8(0, 198, 99)},
}

static var _cache := {}


## Returns true if the rail was skinned (Rail.gd then skips its plain line)
static func apply(rail: Path2D) -> bool:
	if not Test.rush_terrain:
		return false
	var id: int = Test.current_background
	if not STAGES.has(id) or rail.curve == null:
		return false
	var points := rail.curve.get_baked_points()
	if points.size() < 2:
		return false
	var tex: Texture2D = _cache.get(id)
	if tex == null:
		tex = _make_texture(STAGES[id])
		_cache[id] = tex
	var line := Line2D.new()
	line.name = "RailSkin"
	line.points = points
	line.texture = tex
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_y: float = max(0.001, abs(rail.global_scale.y))
	line.width = tex.get_height() * TEXEL_WORLD / scale_y
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = false
	rail.add_child(line)
	return true


static func _make_texture(p: Dictionary) -> Texture2D:
	# 32 x 8 tile: a round tube (outline, highlight, body, shadow, outline) with a
	# bracket and a little light at the start of each tile
	var h := 8
	var img := Image.create(TILE, h, false, Image.FORMAT_RGBA8)
	var rows := [p.outline, p.hi, p.light, p.mid, p.mid, p.dark, p.dark, p.outline]
	for x in TILE:
		for y in h:
			img.set_pixel(x, y, rows[y])
		# Broken shine along the top, like polished metal
		if (x % 8) in [5, 6]:
			img.set_pixel(x, 1, p.light)
		# Soft reflected light near the bottom
		if (x % 8) == 2:
			img.set_pixel(x, 5, p.mid)
	# Bracket clamped round the tube
	for x in [0, 1, 2, 3]:
		for y in h:
			var c: Color = p.bracket
			if y == 0 or y == h - 1:
				c = p.outline
			elif x == 1 and y <= 2:
				c = (p.bracket as Color).lightened(0.35)   # lit edge of the clamp
			img.set_pixel(x, y, c)
	if p.get("stripes", false):
		# Caution stripes on the clamp
		for y in range(1, h - 1):
			for x in [0, 1, 2, 3]:
				if (x + y) % 4 < 2:
					img.set_pixel(x, y, p.accent)
	else:
		img.set_pixel(1, 4, p.accent)
		img.set_pixel(2, 4, p.accent)
		img.set_pixel(1, 3, (p.accent as Color).lightened(0.5))
	return ImageTexture.create_from_image(img)
