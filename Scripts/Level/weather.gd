extends Node2D
## Weather and background life, per stage.
##  - Night city (1):   rain with ground splashes, wet characters
##                      (its train comes from the city asset pack, see city_depth.gd)
##  - Sunset (2):       wind gusts that sweep the petals along
##  - Purple town (4):  snowfall
##  - Grey city (5):    falling ash, drifting smog (train: city_depth.gd)
##  - 4th floors (6):   light wind
## All of it is drawn in code (no extra art files) and switches off with
## Pause > Settings > Effects. Created by atmosphere.gd.

const WIND_GUSTS := false   # the wind lines sweeping across the sunset stages (turned off)

const STAGES := {
	1: {"weather": "rain", "train": false, "train_body": Color8(52, 66, 96), "train_stripe": Color8(214, 70, 70), "train_layer_motion": 0.18},
	2: {"weather": "wind"},
	4: {"weather": "snow"},
	5: {"weather": "ash", "train": false, "train_body": Color8(70, 52, 44), "train_stripe": Color8(230, 150, 60), "train_layer_motion": 0.2},
	6: {"weather": "wind_light"},
}

## Background art is drawn at about this many world units per art pixel, so the
## train matches it (the characters use 1.125; backgrounds are chunkier).
const BG_PIXEL := 2.0

var stage: Dictionary = {}
var atmosphere: Node = null          # atmosphere.gd, for wet characters
var background: Node = null
var _on := true

# Rain
var rain: CPUParticles2D
var splashes: Array[CPUParticles2D] = []
var _splash_index := 0
var _splash_timer := 0.0

# Snow / ash / smog
var flakes: CPUParticles2D
var smog: CPUParticles2D

# Wind
var _gust_timer := 4.0
var _gust_left := 0.0
var gust_layer: CanvasLayer
var gust_lines: Array[Line2D] = []

# Train
var train_layer: ParallaxLayer
var train: Node2D
var track: Sprite2D
var _train_dir := 1.0
var _train_speed := 0.0
var _train_wait := 2.0
var _train_running := false


func setup(background_node: Node, background_id: int, atmosphere_node: Node) -> void:
	background = background_node
	atmosphere = atmosphere_node
	stage = STAGES.get(background_id, {})
	match stage.get("weather", ""):
		"rain": _build_rain()
		"snow": _build_flakes(Color(1, 1, 1, 0.9), 320, Vector2(-0.35, 1), 25.0, 60.0, 9.0, 2)
		"ash":
			_build_flakes(Color(0.75, 0.7, 0.68, 0.7), 220, Vector2(0.4, 1), 15.0, 40.0, 10.0, 1)
			_build_smog()
		"wind", "wind_light":
			if WIND_GUSTS:
				_build_gusts()
	if stage.get("train", false):
		_build_train()
	_find_clouds()


func set_enabled(on: bool) -> void:
	_on = on
	for p in [rain, flakes, smog]:
		if p:
			p.emitting = on
			p.visible = on
	if gust_layer:
		gust_layer.visible = on
	if train_layer:
		train_layer.visible = on


func _process(delta: float) -> void:
	if not _on:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	for p in [rain, flakes]:
		if p:
			p.global_position = center + Vector2(0, -250)
	if smog:
		smog.global_position = center + Vector2(0, 150)
	if rain:
		_update_splashes(delta, cam)
	if gust_layer:
		_update_gusts(delta)
	if train_layer:
		_update_train(delta)
	_update_clouds(delta)


# ── Drifting clouds ─────────────────────────────────────────────────────────
## Background cloud art (by file name) that drifts sideways. Only the cloud
## sprites move; hills or buildings sharing their layer stay put.
const CLOUD_TEXTURES := ["Mountains/2.png", "Mountains/3.png", "Mountains/10.png", "City/3.png"]
## Drift speed in layer pixels per second = CLOUD_SPEED_BASE + CLOUD_SPEED_DEPTH * the layer's motion scale
## (nearer clouds drift faster, which adds depth).
const CLOUD_SPEED_BASE := 10.0
const CLOUD_SPEED_DEPTH := 80.0
var clouds: Array = []   # [sprite, base_x, wrap_width, speed]
var _cloud_time := 0.0


func _find_clouds() -> void:
	if background == null:
		return
	for layer in background.get_children():
		if not layer is ParallaxLayer:
			continue
		var wrap: float = layer.motion_mirroring.x
		if wrap <= 0.0:
			continue   # without mirroring the clouds would slide off and leave a gap
		for s in layer.get_children():
			if s is Sprite2D and s.texture:
				for name in CLOUD_TEXTURES:
					# (pixel_match.gd may have swapped in an enlarged copy; match the original file)
					if String(s.get_meta("source_texture", s.texture.resource_path)).ends_with(name):
						clouds.append([s, s.position.x, wrap, CLOUD_SPEED_BASE + CLOUD_SPEED_DEPTH * layer.motion_scale.x])


func _update_clouds(delta: float) -> void:
	_cloud_time += delta
	for c in clouds:
		if is_instance_valid(c[0]):
			# Wrapping by the layer's mirroring width keeps the loop seamless
			c[0].position.x = c[1] - fmod(_cloud_time * c[3], c[2])


# ── Rain ────────────────────────────────────────────────────────────────────
func _build_rain() -> void:
	rain = CPUParticles2D.new()
	rain.local_coords = false
	rain.amount = 520
	rain.lifetime = 0.75
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(1150, 500)
	rain.direction = Vector2(0.22, 1)
	rain.spread = 2
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 1300
	rain.initial_velocity_max = 1700
	rain.particle_flag_align_y = true
	rain.texture = _pixel_texture(1, 7)
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.6
	rain.color = Color(0.78, 0.88, 1.0, 0.6)
	rain.z_index = 4
	add_child(rain)
	# A pool of splash bursts that get re-used where drops hit the ground
	for i in 10:
		var s := CPUParticles2D.new()
		s.local_coords = false
		s.one_shot = true
		s.emitting = false
		s.explosiveness = 1.0
		s.amount = 5
		s.lifetime = 0.28
		s.direction = Vector2(0, -1)
		s.spread = 70
		s.gravity = Vector2(0, 900)
		s.initial_velocity_min = 60
		s.initial_velocity_max = 140
		s.texture = _pixel_texture(1, 1)
		s.scale_amount_min = 1.2
		s.scale_amount_max = 2.0
		s.color = Color(0.8, 0.9, 1.0, 0.7)
		s.z_index = 4
		add_child(s)
		splashes.append(s)
	if atmosphere:
		atmosphere.set("wet_amount", 0.6)
		atmosphere.set("reflection_strength", 0.6)  # wet ground reflects more


func _update_splashes(delta: float, cam: Camera2D) -> void:
	_splash_timer -= delta
	if _splash_timer > 0.0:
		return
	_splash_timer = 0.035
	var view := get_viewport().get_visible_rect().size / cam.zoom
	var center := cam.get_screen_center_position()
	var x := center.x + randf_range(-0.5, 0.5) * view.x
	var from := Vector2(x, center.y - view.y * 0.5)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, view.y * 1.2), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y > -0.5:
		return
	var s := splashes[_splash_index]
	_splash_index = (_splash_index + 1) % splashes.size()
	s.global_position = hit.position
	s.restart()


# ── Snow / ash / smog ───────────────────────────────────────────────────────
func _build_flakes(color: Color, amount: int, dir: Vector2, vmin: float, vmax: float, life: float, size: int) -> void:
	flakes = CPUParticles2D.new()
	flakes.local_coords = false
	flakes.amount = amount
	flakes.lifetime = life
	flakes.preprocess = life
	flakes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flakes.emission_rect_extents = Vector2(1150, 650)
	flakes.direction = dir
	flakes.spread = 20
	flakes.gravity = Vector2(0, 8)
	flakes.initial_velocity_min = vmin
	flakes.initial_velocity_max = vmax
	# Gentle side-to-side drift
	flakes.tangential_accel_min = -6
	flakes.tangential_accel_max = 6
	flakes.texture = _pixel_texture(size, size)
	flakes.scale_amount_min = 1.125
	flakes.scale_amount_max = 2.25
	flakes.color = color
	flakes.z_index = 4
	add_child(flakes)


func _build_smog() -> void:
	# Big soft smoke puffs drifting low across the scene
	smog = CPUParticles2D.new()
	smog.local_coords = false
	smog.amount = 14
	smog.lifetime = 14.0
	smog.preprocess = 14.0
	smog.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smog.emission_rect_extents = Vector2(1300, 250)
	smog.direction = Vector2(1, -0.1)
	smog.spread = 10
	smog.gravity = Vector2.ZERO
	smog.initial_velocity_min = 12
	smog.initial_velocity_max = 30
	smog.texture = _soft_texture(64)
	smog.scale_amount_min = 4.0
	smog.scale_amount_max = 7.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.32, 0.28, 0.0))
	ramp.set_color(1, Color(0.45, 0.32, 0.28, 0.0))
	ramp.add_point(0.3, Color(0.45, 0.32, 0.28, 0.22))
	ramp.add_point(0.7, Color(0.45, 0.32, 0.28, 0.18))
	smog.color_ramp = ramp
	smog.z_index = 3
	add_child(smog)


# ── Wind gusts ──────────────────────────────────────────────────────────────
func _build_gusts() -> void:
	gust_layer = CanvasLayer.new()
	gust_layer.layer = 4
	add_child(gust_layer)
	for i in 7:
		var l := Line2D.new()
		l.width = 3.0
		l.default_color = Color(1, 1, 1, 0.0)
		l.points = PackedVector2Array([Vector2.ZERO, Vector2(140, 0)])
		gust_layer.add_child(l)
		gust_lines.append(l)


func _update_gusts(delta: float) -> void:
	var light: bool = stage.get("weather", "") == "wind_light"
	_gust_timer -= delta
	if _gust_timer <= 0.0 and _gust_left <= 0.0:
		_gust_left = 1.6
		_gust_timer = randf_range(5.0, 9.0) * (1.6 if light else 1.0)
		var view := get_viewport().get_visible_rect().size
		for l in gust_lines:
			l.position = Vector2(randf_range(-400, view.x * 0.3), randf_range(0.1, 0.85) * view.y)
			l.set_meta("speed", randf_range(1400, 2200))
			var length := randf_range(60, 200)
			l.points = PackedVector2Array([Vector2.ZERO, Vector2(length * 0.4, -4), Vector2(length, 0)])
	if _gust_left > 0.0:
		_gust_left -= delta
		var t: float = 1.0 - absf(_gust_left / 1.6 - 0.5) * 2.0   # fade in, then out
		for l in gust_lines:
			l.position.x += float(l.get_meta("speed", 1600)) * delta
			l.default_color = Color(1, 1, 1, (0.18 if light else 0.32) * t)
		# Push the stage's drifting particles along with the gust
		var p = atmosphere.get("particles") if atmosphere else null
		if p:
			if not p.has_meta("calm_gravity"):
				p.set_meta("calm_gravity", p.gravity)
			var calm: Vector2 = p.get_meta("calm_gravity")
			p.gravity = calm + Vector2(lerp(0.0, 260.0 if not light else 120.0, t), 0)
			if _gust_left <= 0.0:
				p.gravity = calm


# ── Train ───────────────────────────────────────────────────────────────────
func _build_train() -> void:
	if background == null:
		return
	var motion: float = stage.get("train_layer_motion", 0.18)
	train_layer = ParallaxLayer.new()
	train_layer.motion_scale = Vector2(motion, motion * 0.8)
	train_layer.name = "TrainLayer"
	# Slot it in by depth: behind layers that move more, in front of ones that move less
	var index := background.get_child_count()
	for i in background.get_child_count():
		var c := background.get_child(i)
		if c is ParallaxLayer and c.motion_scale.x > motion:
			index = i
			break
	background.add_child(train_layer)
	background.move_child(train_layer, index)
	# The night city already has a static row of train windows at this depth;
	# hide it so the moving train replaces it.
	for c in background.get_children():
		if c is ParallaxLayer and c != train_layer:
			for s in c.get_children():
				if s is Sprite2D and s.texture and String(s.get_meta("source_texture", s.texture.resource_path)).ends_with("6-backround-train.png"):
					s.visible = false

	# Elevated track: rail, deck and supports, tiled across the view
	track = Sprite2D.new()
	track.texture = _track_texture()
	track.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	track.region_enabled = true
	track.region_rect = Rect2(0, 0, 2400, track.texture.get_height())
	track.centered = false
	track.scale = Vector2(BG_PIXEL, BG_PIXEL)
	train_layer.add_child(track)

	train = Node2D.new()
	var body := Sprite2D.new()
	body.texture = _train_texture(stage.train_body, stage.train_stripe)
	body.centered = false
	body.scale = Vector2(BG_PIXEL, BG_PIXEL)
	body.name = "Body"
	train.add_child(body)
	# Headlight beam (soft cone ahead of the nose; not additive, so no bloom)
	var beam := Polygon2D.new()
	beam.name = "Beam"
	beam.color = Color(1.0, 0.95, 0.75, 0.16)
	train.add_child(beam)
	train.visible = false
	train_layer.add_child(train)
	_haze(body, 0.38)
	_haze(track, 0.45)
	beam.color = Color(1.0, 0.95, 0.75, 0.1)


func _haze(item: CanvasItem, amount: float) -> void:
	# Push the train back into the distance with the stage's haze colour
	if atmosphere == null or not ("preset" in atmosphere):
		return
	var m := ShaderMaterial.new()
	m.shader = preload("res://Shaders/atmosphere_haze.gdshader")
	m.set_shader_parameter("haze_color", atmosphere.preset.get("haze", Color(0.5, 0.5, 0.6)))
	m.set_shader_parameter("haze_amount", amount)
	m.set_shader_parameter("desaturate", 0.25)
	item.material = m


func _visible_x_range() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var inv := train_layer.get_global_transform_with_canvas().affine_inverse()
	var a: Vector2 = inv * Vector2(0, 0)
	var b: Vector2 = inv * Vector2(view.x, view.y)
	return Vector2(min(a.x, b.x), max(a.x, b.x))


func _track_y() -> float:
	# Run along the skyline, above the play area, in layer space
	var view := get_viewport().get_visible_rect().size
	var inv := train_layer.get_global_transform_with_canvas().affine_inverse()
	return (inv * Vector2(0, view.y * 0.3)).y


func _update_train(delta: float) -> void:
	var range_x := _visible_x_range()
	var y := _track_y()
	# Keep the track spanning the view, snapped to its pattern so it doesn't swim
	var period := 32.0 * BG_PIXEL
	track.position = Vector2(floor((range_x.x - period) / period) * period, y + 26.0 * BG_PIXEL)
	track.region_rect.size.x = (range_x.y - range_x.x) / BG_PIXEL + 96.0

	var body: Sprite2D = train.get_node("Body")
	var w: float = body.texture.get_width() * BG_PIXEL
	if not _train_running:
		_train_wait -= delta
		if _train_wait > 0.0:
			return
		_train_running = true
		_train_dir = 1.0 if randf() < 0.5 else -1.0
		_train_speed = randf_range(700.0, 1000.0)
		train.position.x = range_x.x - w - 50.0 if _train_dir > 0 else range_x.y + 50.0
		body.flip_h = _train_dir < 0
		train.visible = true
	train.position.x += _train_dir * _train_speed * delta
	# A little ride bounce
	train.position.y = y + (1.0 if fmod(Time.get_ticks_msec() / 90.0, 2.0) < 1.0 else 0.0) * BG_PIXEL * 0.5
	_update_beam(body, w)
	var gone: bool = (_train_dir > 0 and train.position.x > range_x.y + 50.0) or (_train_dir < 0 and train.position.x + w < range_x.x - 50.0)
	if gone:
		_train_running = false
		train.visible = false
		_train_wait = randf_range(4.0, 9.0)


func _update_beam(body: Sprite2D, w: float) -> void:
	var beam: Polygon2D = train.get_node("Beam")
	var h: float = body.texture.get_height() * BG_PIXEL
	var lamp_y := h * 0.55
	if _train_dir > 0:
		var x := w
		beam.polygon = PackedVector2Array([Vector2(x, lamp_y - 3), Vector2(x + 520, lamp_y - 60), Vector2(x + 520, lamp_y + 50), Vector2(x, lamp_y + 3)])
	else:
		beam.polygon = PackedVector2Array([Vector2(0, lamp_y - 3), Vector2(-520, lamp_y - 60), Vector2(-520, lamp_y + 50), Vector2(0, lamp_y + 3)])


# ── Generated art (original pixel shapes) ───────────────────────────────────
func _train_texture(body: Color, stripe: Color) -> Texture2D:
	var cars := 5
	var car_w := 96
	var gap := 3
	var h := 26
	var w := cars * car_w + (cars - 1) * gap + 14  # + nose
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := body.darkened(0.45)
	var roof := body.lightened(0.18)
	var window_on := Color8(255, 214, 120)
	var window_off := body.darkened(0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for c in cars:
		var x0 := c * (car_w + gap)
		_rect(img, x0, 3, car_w, 18, body)                 # body
		_rect(img, x0 + 2, 1, car_w - 4, 2, roof)          # roof
		_rect(img, x0, 3, car_w, 1, roof)
		_rect(img, x0, 16, car_w, 2, stripe)               # livery stripe
		_rect(img, x0, 20, car_w, 1, dark)                 # underframe
		# windows, some dark
		var wx := x0 + 6
		while wx < x0 + car_w - 10:
			_rect(img, wx, 7, 7, 6, window_on if rng.randf() < 0.8 else window_off)
			wx += 11
		# doors
		_rect(img, x0 + car_w / 2 - 3, 6, 6, 10, dark)
		# bogies and wheels
		for bx in [x0 + 10, x0 + car_w - 22]:
			_rect(img, bx, 21, 12, 2, dark)
			_rect(img, bx + 1, 23, 3, 3, Color8(30, 30, 36))
			_rect(img, bx + 8, 23, 3, 3, Color8(30, 30, 36))
		if c < cars - 1:
			_rect(img, x0 + car_w, 11, gap, 6, dark)       # gangway
	# Locomotive nose on the right, with headlight
	var nx := cars * car_w + (cars - 1) * gap
	for i in 14:
		var top := 3 + int(i * 0.9)
		_rect(img, nx + i, top, 1, 21 - top, body)
	_rect(img, nx, 16, 12, 2, stripe)
	_rect(img, nx + 8, 13, 3, 2, Color8(255, 246, 200))   # headlight
	_rect(img, nx + 2, 7, 6, 5, Color8(120, 170, 200))    # cab window
	return ImageTexture.create_from_image(img)


func _track_texture() -> Texture2D:
	# 32 px repeating span: rail, deck, a support pillar
	var img := Image.create(32, 60, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rail := Color8(70, 72, 84)
	var deck := Color8(46, 48, 60)
	var pillar := Color8(38, 40, 52)
	_rect(img, 0, 0, 32, 1, rail)
	_rect(img, 0, 1, 32, 5, deck)
	_rect(img, 0, 6, 32, 1, rail)
	for x in range(0, 32, 4):
		_rect(img, x, 2, 1, 3, pillar)
	_rect(img, 12, 7, 8, 53, pillar)          # pillar
	_rect(img, 10, 7, 12, 2, deck)            # pillar cap
	return ImageTexture.create_from_image(img)


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(max(0, y), min(img.get_height(), y + h)):
		for xx in range(max(0, x), min(img.get_width(), x + w)):
			img.set_pixel(xx, yy, color)


func _pixel_texture(w: int, h: int) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _soft_texture(size: int) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t
