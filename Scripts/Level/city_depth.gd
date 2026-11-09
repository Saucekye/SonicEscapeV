extends Node2D
## Depth layers for the city stages, so it feels like you're running
## THROUGH a city rather than past a painted backdrop.
##
## All art comes from the same city asset pack the stage backgrounds already use
## (Sprites/Background/CityPack/):
##   Night city (1, also the training stage): the pack's "close - night" set
##   Grey city (5):                           the pack's "cars" (sunset) set
##
## Layers behind the play area (far towers, viaduct with a passing train, lit
## apartment blocks, the street with moving traffic) and layers IN FRONT of the
## camera (see-through tower blocks sweeping past faster than you).
## Pixel-perfect: every art pixel is a whole number of screen pixels.
## Created by atmosphere.gd for the city backgrounds. Follows the Effects toggle.

const ART := "res://Sprites/Background/CityPack/"

## Each layer:
##   parts:  images drawn together at that depth. A part can drift on its own
##           ("drift", art pixels per second, + = rightward: traffic; each strip's
##           vehicles have headlights on the end they drive towards. Speeds follow
##           the pack's preview: brisk, and faster in nearer lanes) or be an animation strip
##           ("frames", "fps": billboards). "spacing" adds that many empty art pixels
##           between repeats, so big pieces only come by now and then.
##   speed:  horizontal scroll relative to the world (1 = moves with the ground)
##   vspeed: vertical parallax
##   px:     size: how many character pixels one of the pack's pixels covers (1, 2, 3, 4...).
##           Everything is drawn on the characters' own pixel grid, so there are no
##           mixels: the pack's art is pre-enlarged with a pixel-art scaler
##           (tools/pixel_upscale.py, files "<name>@<px>x.png") and drawn at exactly
##           one character pixel per image pixel.
##   street: where the bottom of the image sits on screen (0 top, 1 bottom), or instead
##   anchor + at: art row "anchor" (a road surface, a rooftop line) sits at screen height "at"
##   haze:   how far it fades into the sky colour (distance)
##   z:      canvas layer. Below 0 is behind the world, above 0 is in front of it.
##   sink:   (front layers) art pixels pushed below the bottom edge of the screen
##   train:  a part that runs along this layer now and then (a train on the viaduct)
##   "fade" on a part: it turns see-through wherever it passes over a character,
##           so big foreground pieces never hide the action.
## Sizes follow distance, so the characters fit the city: the further back a layer
## scrolls, the smaller it is drawn ("px"), and things at or in front of the play
## area are drawn big (nearby cars stand taller than the characters, nearby
## buildings rise far above them).
const STAGES := {
	1: { # night city: "close - night" set
		"haze_color": Color8(28, 40, 80),
		"glow": 0.85,   # how strongly lit windows, lamps and signs shine
		# Bands of drifting mist between layers: canvas layer, height on screen,
		# band height (share of the screen), density, scroll speed, drift (px/s)
		"mist": [
			{"z": -60, "at": 0.50, "height": 0.30, "strength": 0.55, "speed": 0.42, "drift": 14.0, "color": Color8(70, 92, 150)},
			{"z": -51, "at": 0.62, "height": 0.22, "strength": 0.30, "speed": 0.68, "drift": 24.0, "color": Color8(90, 110, 165)},
		],
		"layers": [
			{"z": -70, "speed": 0.18, "vspeed": 0.10, "px": 2, "street": 0.80, "haze": 0.45,
				"parts": [{"img": "Night/3-background.png"}]},
			{"z": -66, "speed": 0.28, "vspeed": 0.16, "px": 2, "street": 0.84, "haze": 0.30,
				"parts": [{"img": "Night/4-middleground.png"}]},
			{"z": -62, "speed": 0.38, "vspeed": 0.22, "px": 2, "street": 0.76, "haze": 0.18,
				"parts": [{"img": "Night/5-middleground.png"}],
				"train": {"img": "Night/5-middleground-train.png", "speed": 150.0, "gap": [5.0, 11.0]}},
			{"z": -56, "speed": 0.50, "vspeed": 0.30, "px": 3, "anchor": 107, "at": 0.24, "haze": 0.10,
				"parts": [{"img": "Night/6-middleground-buildings.png"}]},
			{"z": -53, "speed": 0.60, "vspeed": 0.36, "px": 3, "anchor": 24, "at": 0.14, "haze": 0.18,
				"parts": [{"img": "Night/10-foreground-buildings.png"}]},
			{"z": -50, "speed": 0.72, "vspeed": 0.44, "px": 3, "anchor": 234, "at": 0.66, "haze": 0.0,
				"parts": [{"img": "Night/7-foreground-lane.png"},
					{"img": "Night/8-foreground-cars.png", "drift": -115.0},
					{"img": "Night/8b-foreground-cars.png", "drift": 130.0},
					{"img": "Night/7-lights.png"}]},
			# In front of the camera, back to front:
			# tower blocks passing now and then as dark silhouettes (faint lit windows),
			{"z": 4, "speed": 2.1, "vspeed": 1.3, "px": 4, "front": true, "offset": 300, "sink": 40,
				"tint": Color(0.17, 0.19, 0.32), "parts": [{"img": "Night/10-foreground-buildings.png", "spacing": 1300, "fade": true}]},
		],
	},
	5: { # grey city at dusk: "cars" set (plus the viaduct, train and poles from "close")
		"haze_color": Color8(150, 76, 52),
		"glow": 0.55,
		"mist": [
			{"z": -60, "at": 0.46, "height": 0.34, "strength": 0.50, "speed": 0.44, "drift": -10.0, "color": Color8(196, 112, 70)},
			{"z": -50, "at": 0.60, "height": 0.24, "strength": 0.32, "speed": 0.66, "drift": -20.0, "color": Color8(170, 86, 58)},
		],
		"layers": [
			{"z": -70, "speed": 0.18, "vspeed": 0.10, "px": 2, "street": 0.80, "haze": 0.45,
				"parts": [{"img": "Sunset/3-middleground.png"}]},
			{"z": -66, "speed": 0.30, "vspeed": 0.18, "px": 2, "street": 0.86, "haze": 0.32,
				"parts": [{"img": "Sunset/4-middleground.png"}]},
			{"z": -62, "speed": 0.40, "vspeed": 0.24, "px": 2, "street": 0.76, "haze": 0.22,
				"parts": [{"img": "Sunset/viaduct.png"}],
				"train": {"img": "Sunset/viaduct-train.png", "speed": -150.0, "gap": [5.0, 11.0]}},
			{"z": -56, "speed": 0.52, "vspeed": 0.30, "px": 3, "anchor": 90, "at": 0.22, "haze": 0.12,
				"parts": [{"img": "Sunset/5-middleground-buildings.png"}]},
			{"z": -52, "speed": 0.60, "vspeed": 0.36, "px": 2, "anchor": 219, "at": 0.55, "haze": 0.06,
				"parts": [{"img": "Sunset/7-foreground-lane.png"},
					{"img": "Sunset/6-foreground-cars.png", "drift": 120.0},
					{"img": "Sunset/6b-foreground-cars.png", "drift": -130.0}]},
			{"z": -48, "speed": 0.70, "vspeed": 0.42, "px": 2, "anchor": 127, "at": 0.12, "haze": 0.08,
				"parts": [{"img": "Sunset/8-foreground.png"},
					{"img": "Sunset/8-foreground-billboard.png", "frames": 15, "fps": 6.0}]},
			{"z": -44, "speed": 0.80, "vspeed": 0.48, "px": 2, "anchor": 234, "at": 0.78, "haze": 0.22,
				"parts": [{"img": "Sunset/9-foreground-lane.png"},
					{"img": "Sunset/10-foreground-cars.png", "drift": -140.0},
					{"img": "Sunset/10b-foreground-cars.png", "drift": 150.0}]},
			# In front of the camera, back to front: tower blocks passing now and then,
			{"z": 4, "speed": 2.1, "vspeed": 1.3, "px": 4, "front": true, "offset": 300, "sink": 40,
				"tint": Color(0.24, 0.13, 0.11), "parts": [{"img": "Sunset/front-buildings.png", "spacing": 1300, "fade": true}]},
		],
	},
}

const FRONT_ALPHA := 0.4  # foreground buildings are always this see-through
const FADE_ALPHA := 0.18  # and fade further to this when one passes over a character
const TEXEL_WORLD := 1.125  # world units per character art pixel (the camera keeps this on whole screen pixels)

var stage: Dictionary
var layers := []          # runtime: {canvas, cfg, parts: [{sprites, drift, frames, fps, w}], train}
var _cam_y0 = null
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func setup(background_id: int) -> void:
	stage = STAGES[background_id]
	_rng.seed = 2000 + background_id
	for cfg in stage.layers:
		_add_layer(cfg)
	for m in stage.get("mist", []):
		_add_mist(m)


static func applies_to(background_id: int) -> bool:
	return STAGES.has(background_id)


func set_enabled(on: bool) -> void:
	for l in layers:
		l.canvas.visible = on
	for m in mists:
		m.canvas.visible = on


# ── Mist ────────────────────────────────────────────────────────────────────
var mists := []   # {canvas, rect, material, cfg}
var _noise: NoiseTexture2D

func _add_mist(cfg: Dictionary) -> void:
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.012
		fn.fractal_octaves = 3
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.noise = fn
	var canvas := CanvasLayer.new()
	canvas.layer = int(cfg.z)
	add_child(canvas)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Shaders/mist_band.gdshader")
	mat.set_shader_parameter("noise_tex", _noise)
	mat.set_shader_parameter("mist_color", cfg.color)
	mat.set_shader_parameter("strength", cfg.strength)
	rect.material = mat
	canvas.add_child(rect)
	mists.append({"canvas": canvas, "rect": rect, "material": mat, "cfg": cfg})


func _update_mist(center: Vector2, zoom: float, view: Vector2, stretch: float, texel: float) -> void:
	for m in mists:
		var cfg: Dictionary = m.cfg
		var h: float = view.y * float(cfg.height)
		var dy: float = (center.y - _cam_y0) * zoom * float(cfg.speed) * 0.6
		m.rect.position = Vector2(0, view.y * float(cfg.at) - h * 0.5 - dy)
		m.rect.size = Vector2(view.x, h)
		var scroll: float = center.x * zoom * float(cfg.speed) - _time * float(cfg.drift)
		m.material.set_shader_parameter("offset_px", Vector2(scroll * stretch, -dy * stretch))
		m.material.set_shader_parameter("texel_px", texel * stretch)
		m.material.set_shader_parameter("time_s", _time)


func _add_layer(cfg: Dictionary) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = int(cfg.z)
	add_child(canvas)
	var mat: ShaderMaterial = null
	var haze := float(cfg.get("haze", 0.0))
	if haze > 0.0:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://Shaders/atmosphere_haze.gdshader")
		mat.set_shader_parameter("haze_color", stage.haze_color)
		mat.set_shader_parameter("haze_amount", haze)
		mat.set_shader_parameter("desaturate", haze * 0.3)
	var l := {"canvas": canvas, "cfg": cfg, "parts": [], "train": null}
	var u := int(cfg.get("px", 1))
	for p in cfg.parts:
		var tex: Texture2D = _load_px(p.img, u)
		if tex == null:
			continue
		var frames := int(p.get("frames", 1))
		var h := tex.get_height() / u
		# Ground everything: upright pieces carry on down past the bottom of the screen,
		# so nothing is ever seen ending in mid-air when the ground dips or the camera
		# rises. Not for things that sit ON something: traffic, animated billboards, light glows.
		if frames == 1 and float(p.get("drift", 0.0)) == 0.0 and not String(p.img).contains("lights"):
			tex = _grounded(tex, GROUND_EXTEND * u)
		var part := {"sprites": [], "drift": float(p.get("drift", 0.0)), "frames": frames,
			"fps": float(p.get("fps", 0.0)), "w": tex.get_width() / frames / u, "h": h,
			"period": tex.get_width() / frames / u + int(p.get("spacing", 0)),
			"img": tex.get_image() if p.get("fade", false) else null}
		# Enough copies to cover the widest screens at the smallest scale
		var glow_tex := _load_glow(p.img, u)
		part["glows"] = []
		for i in 4:
			var s := _sprite(tex, mat, cfg)
			s.hframes = frames
			canvas.add_child(s)
			part.sprites.append(s)
			if glow_tex:
				# Lit windows, lamps, headlights and signs shine (additive halo on top)
				var g := Sprite2D.new()
				g.texture = glow_tex
				g.centered = false
				g.hframes = frames
				g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				var gm := CanvasItemMaterial.new()
				gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				g.material = gm
				g.self_modulate = Color(1, 1, 1, float(stage.get("glow", 0.7)) * float(cfg.get("glow", 1.0)))
				s.add_child(g)
				part.glows.append(g)
		l.parts.append(part)
	if cfg.has("train"):
		var t: Dictionary = cfg.train
		var ttex: Texture2D = _load_px(t.img, u)
		if ttex:
			var s := _sprite(ttex, mat, cfg)
			s.visible = false
			canvas.add_child(s)
			l.train = {"sprite": s, "speed": float(t.speed), "gap": t.gap,
				"wait": _rng.randf_range(1.0, 3.0), "x": 0.0, "running": false,
					"w": ttex.get_width() / u, "h": ttex.get_height() / u}
	l["u"] = u
	layers.append(l)


func _load_glow(img: String, u: int) -> Texture2D:
	var path := ART + img.get_basename() + ("@%dx" % u if u > 1 else "") + ".glow.png"
	return load(path) if ResourceLoader.exists(path) else null


func _load_px(img: String, u: int) -> Texture2D:
	# The pack image enlarged u times with the pixel-art scaler (falls back to the original)
	if u > 1:
		var path := ART + img.get_basename() + "@%dx." % u + img.get_extension()
		if ResourceLoader.exists(path):
			return load(path)
	return load(ART + img)


const GROUND_EXTEND := 240   # pack pixels added below each image

func _grounded(tex: Texture2D, extend: int) -> Texture2D:
	# Copies the image with every solid vertical structure that reaches its bottom edge
	# (walls, pillars, tower legs, poles) continued straight down. A column only
	# continues if its last 3 rows are solid, so sagging cables and the like don't.
	var src := tex.get_image()
	if src == null:
		return tex
	src = src.duplicate()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h + extend, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i.ZERO)
	for x in w:
		if src.get_pixel(x, h - 1).a > 0.5 and src.get_pixel(x, h - 2).a > 0.5 and src.get_pixel(x, h - 3).a > 0.5:
			out.fill_rect(Rect2i(x, h, 1, extend), src.get_pixel(x, h - 1))
	return ImageTexture.create_from_image(out)


func _sprite(tex: Texture2D, mat: Material, cfg: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = mat
	if cfg.has("tint"):
		s.modulate = cfg.tint
	return s


func _process(delta: float) -> void:
	_time += delta
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	if _cam_y0 == null:
		_cam_y0 = center.y
	var view := get_viewport().get_visible_rect().size
	# Window pixels per canvas unit, so art pixels land on whole screen pixels
	var stretch: float = max(0.01, get_viewport().get_final_transform().get_scale().x)
	var zoom := cam.zoom.x
	# One character pixel, in canvas units (a whole number of screen pixels)
	var texel: float = max(1.0, round(TEXEL_WORLD * zoom * stretch)) / stretch
	# Characters' positions on screen, for fading big foreground pieces over them
	var chars: Array[Vector2] = []
	for c in get_tree().get_nodes_in_group("all_characters"):
		if c is CanvasItem and c.visible:
			chars.append((c as CanvasItem).get_global_transform_with_canvas().origin)
	for l in layers:
		var cfg: Dictionary = l.cfg
		var px: float = texel * float(l.u)                 # canvas units per pack pixel
		var scroll: float = center.x * zoom * float(cfg.speed) + float(cfg.get("offset", 0)) * px
		var dy: float = (center.y - _cam_y0) * zoom * float(cfg.vspeed)
		var bottom: float
		if cfg.get("front", false):
			# Foreground hugs the bottom of the screen with a little vertical sway
			bottom = view.y + clamp(-dy * 0.12, -30.0, 30.0) + (2.0 + float(cfg.get("sink", 0))) * px
		else:
			if cfg.has("anchor") and not l.parts.is_empty():
				bottom = view.y * float(cfg.at) + (float(l.parts[0].h) - float(cfg.anchor)) * px - dy
			else:
				bottom = view.y * float(cfg.street) - dy
		for part in l.parts:
			var w: float = part.period * px
			var h: float = part.h * px
			var x := -fposmod(scroll - part.drift * _time * px, w)
			var frame := 0
			if part.frames > 1:
				frame = int(_time * part.fps) % part.frames
			for i in part.sprites.size():
				var s: Sprite2D = part.sprites[i]
				s.scale = Vector2(texel, texel)
				s.frame = frame
				if i < part.glows.size():
					part.glows[i].frame = frame
				s.position = Vector2(_snap(x + i * w, stretch), _snap(bottom - h, stretch))
				s.visible = x + i * w < view.x and x + i * w + part.w * px > 0.0
				if part.img and s.visible:
					var target := FADE_ALPHA if _covers_character(part.img, s.position, texel, chars) else (FRONT_ALPHA if cfg.get("front", false) else 1.0)
					s.self_modulate.a = move_toward(s.self_modulate.a, target, delta * 5.0)
					if i < part.glows.size():
						part.glows[i].modulate.a = s.self_modulate.a
		if l.train:
			_update_train(l.train, scroll, bottom, px, texel, view, stretch, delta)
	_update_mist(center, zoom, view, stretch, texel)


func _update_train(t: Dictionary, scroll: float, bottom: float, px: float, texel: float, view: Vector2, stretch: float, delta: float) -> void:
	# The train runs across the screen along its layer now and then, in art pixels
	# relative to the layer, so it also scrolls with the viaduct it's riding on.
	var s: Sprite2D = t.sprite
	if not t.running:
		t.wait -= delta
		if t.wait > 0.0:
			s.visible = false
			return
		# Enter from just off-screen on the side it's heading away from
		var w_art: float = t.w
		var left_art := scroll / px
		var right_art := (scroll + view.x) / px
		t.x = left_art - w_art if t.speed > 0.0 else right_art
		t.running = true
	t.x += t.speed * delta
	var sx: float = t.x * px - scroll
	s.scale = Vector2(texel, texel)
	s.flip_h = t.speed < 0.0
	s.position = Vector2(_snap(sx, stretch), _snap(bottom - t.h * px, stretch))
	s.visible = true
	if (t.speed > 0.0 and sx > view.x + 20.0) or (t.speed < 0.0 and sx + t.w * px < -20.0):
		t.running = false
		s.visible = false
		t.wait = _rng.randf_range(t.gap[0], t.gap[1])


func _covers_character(img: Image, pos: Vector2, texel: float, chars: Array[Vector2]) -> bool:
	# True if solid art lies over or around any character (checks a few points on their body)
	for c in chars:
		for o: Vector2 in [Vector2(0, -10), Vector2(0, -45), Vector2(-30, -30), Vector2(30, -30), Vector2(0, -80)]:
			var a: Vector2 = ((c + o) - pos) / texel
			var ix := int(a.x)
			var iy := int(a.y)
			if ix >= 0 and iy >= 0 and ix < img.get_width() and iy < img.get_height():
				if img.get_pixel(ix, iy).a > 0.5:
					return true
	return false


func _snap(v: float, stretch: float) -> float:
	return round(v * stretch) / stretch
