extends RefCounted
## Puts the stage backgrounds on the characters' pixel grid, so there
## are no mixels (pixels of different sizes side by side).
##
## The characters draw one art pixel per 1.125 world units; the background art is
## 2.2 to 13 times chunkier. For each background sprite this swaps in a copy of its
## image that was enlarged with a pixel-art scaler (Scale2x/3x, see
## tools/pixel_upscale.py; files are named "<name>@<n>x.png" next to the original)
## and draws it at exactly one character pixel per image pixel. Each layer keeps its
## look; sizes change by at most about 12% to land on the grid, with every sprite's
## bottom edge kept where it was, and its layer's looping width adjusted to match.
## Sprites without an enlarged copy, or already close to character size, are left alone.
## Layers with lit windows, lamps or signs also get a soft additive glow on top.
## Called from Background.gd before the atmosphere is built.

const ENABLED := true
const TEXEL_WORLD := 1.125            # world units per character art pixel
const FACTORS := [2, 3, 4, 6, 8, 9, 12, 16]
const MIN_RATIO := 1.75               # sprites less than this much chunkier stay as they are


static func apply(background: Node) -> void:
	if not ENABLED or background == null:
		return
	for layer in background.get_children():
		if layer is ParallaxLayer:
			_apply_layer(layer)


static func _apply_layer(layer: ParallaxLayer) -> void:
	# Work out each sprite's swap first; a layer is only changed if all its swaps agree
	# on the size change (so sprites in one layer keep lining up with each other).
	var plans := []
	var k := -1.0
	for s in layer.get_children():
		if not (s is Sprite2D) or s.texture == null:
			continue
		var scale: float = abs(s.scale.x)
		if abs(abs(s.scale.y) - scale) > 0.001:
			continue
		var ratio := scale / TEXEL_WORLD
		if ratio < MIN_RATIO:
			continue
		var u := _best_factor(ratio)
		var path: String = s.texture.resource_path
		var crisp := path.get_basename() + "@%dx." % u + path.get_extension()
		if not ResourceLoader.exists(crisp):
			continue
		var this_k := u * TEXEL_WORLD / scale
		if k > 0.0 and abs(this_k - k) > 0.001:
			return   # mixed sizes in one layer: leave the layer as it was
		k = this_k
		plans.append([s, crisp, u])
	if plans.is_empty():
		return
	for p in plans:
		var s: Sprite2D = p[0]
		var u: int = p[2]
		var old_scale := s.scale
		var old_rect := _layer_rect(s)
		s.set_meta("source_texture", s.texture.resource_path)
		s.texture = load(p[1])
		s.offset *= u
		if s.region_enabled:
			s.region_rect = Rect2(s.region_rect.position * u, s.region_rect.size * u)
		s.scale = Vector2(sign(old_scale.x), sign(old_scale.y)) * TEXEL_WORLD
		# Keep the bottom edge in place; spread horizontally about the layer's origin so
		# side-by-side copies stay touching.
		var new_rect := _layer_rect(s)
		var want := Vector2(old_rect.position.x * k, old_rect.end.y - new_rect.size.y)
		s.position += want - new_rect.position
		_add_glow(s, p[1])
	if layer.motion_mirroring.x > 0.0:
		layer.motion_mirroring.x *= k


const GLOW_STRENGTH := 0.75   # how strongly lit windows, lamps and signs shine (0 = off)

static func _add_glow(s: Sprite2D, crisp: String) -> void:
	# Lit windows, lamps and signs shine: a soft halo image made by
	# tools/pixel_upscale.py ("<name>@<n>x.glow.png"), drawn additively on top.
	var path := crisp.get_basename() + ".glow.png"
	if not ResourceLoader.exists(path):
		return
	var g := Sprite2D.new()
	g.name = "Glow"
	g.texture = load(path)
	g.centered = s.centered
	g.offset = s.offset
	g.region_enabled = s.region_enabled
	g.region_rect = s.region_rect
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # a halo should be soft
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.self_modulate = Color(1, 1, 1, GLOW_STRENGTH)
	g.add_to_group("fx_glow")   # follows the Effects toggle (atmosphere.gd)
	s.add_child(g)


static func _layer_rect(s: Sprite2D) -> Rect2:
	# The sprite's rectangle in its layer's coordinates
	var r := s.get_rect()
	var a := s.position + r.position * s.scale
	var b := s.position + r.end * s.scale
	return Rect2(Vector2(min(a.x, b.x), min(a.y, b.y)), (b - a).abs())


static func _best_factor(ratio: float) -> int:
	var best: int = FACTORS[0]
	for f in FACTORS:
		if abs(log(float(f) / ratio)) < abs(log(float(best) / ratio)):
			best = f
	return best
