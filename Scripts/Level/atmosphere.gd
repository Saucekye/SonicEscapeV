extends Node2D
## Per-stage atmosphere, inspired by how INARI builds its mood:
##  1. Depth haze — far background layers fade into the sky colour.
##  2. Colour grade + glow + vignette — one colour mood for the whole stage.
##  3. Ambient particles — petals / embers / motes drifting through the world.
##  4. Depth of field — far background layers go slightly out of focus.
##  5. Light shafts — beams from the stage's light source through the haze.
##  6. Light and shadow — the world sits in shade, characters carry their own light.
##  7. Foreground — blurred dark silhouettes passing in front of the camera.
##  8. Floor reflections — characters mirrored in the glossy ground below them.
##  9. Character lighting — characters pick up the stage's light colour and a
##     rim highlight from its light source, so they sit in the scene.
## 10. Weather and background life — rain, snow, ash, wind, trains (weather.gd).
## Spawned by Background.gd after the stage background.

const HAZE_SHADER := preload("res://Shaders/atmosphere_haze.gdshader")
const REFLECTION_SHADER := preload("res://Shaders/floor_reflection.gdshader")
const CHARACTER_SHADER := preload("res://Shaders/character_light.gdshader")
const WEATHER := preload("res://Scripts/Level/weather.gd")

## How characters are lit on each stage: overall tint, a rim highlight colour and
## strength, and the direction the light comes FROM (x right, y down; so (1, -1)
## is top-right). Keep tints close to white so characters stay readable.
const CHARACTER_LIGHT := {
	1: {"tint": Color(0.88, 0.91, 1.0), "rim": Color(0.72, 0.86, 1.0), "rim_strength": 0.85, "from": Vector2(1, -1)},
	2: {"tint": Color(1.0, 0.96, 0.92), "rim": Color(1.0, 0.82, 0.55), "rim_strength": 0.65, "from": Vector2(0.7, -0.7)},
	4: {"tint": Color(0.93, 0.91, 1.0), "rim": Color(0.88, 0.84, 1.0), "rim_strength": 0.75, "from": Vector2(-0.6, -1)},
	5: {"tint": Color(1.0, 0.91, 0.85), "rim": Color(1.0, 0.66, 0.36), "rim_strength": 0.75, "from": Vector2(-1, -0.35)},
	6: {"tint": Color(1, 1, 1), "rim": Color(1, 1, 1), "rim_strength": 0.5, "from": Vector2(0, -1)},
}

## Floor reflections: how strong they are and how far below the floor they fade (world units)
const REFLECTION_STRENGTH := 0.42   # weather.gd raises this when it rains
const REFLECTION_FADE := 70.0
## Characters mirrored in the ground. Off; the boss arenas' water (boss_arena.gd)
## has its own reflections.
const FLOOR_REFLECTIONS := false
const POST_SHADER := preload("res://Shaders/atmosphere_post.gdshader")

## One preset per background id (see Background.gd: 1, 2, 4, 5, 6).
## Colours are plain RGB; tints multiply (1.0 = unchanged).
const PRESETS := {
	# Night with the big moon: cool moonlight, pale drifting motes
	1: {
		"haze": Color(0.12, 0.2, 0.4), "haze_far": 0.3, "haze_near": 0.05, "desat": 0.15,
		"shadow": Color(0.85, 0.9, 1.12), "highlight": Color(1.0, 1.0, 1.04),
		"saturation": 1.04, "contrast": 1.05,
		"glow": 0.16, "glow_threshold": 0.8, "glow_color": Color(0.8, 0.92, 1.0), "vignette": 0.15,
		"particles": "motes", "particle_color": Color(0.85, 0.95, 1.0), "particle_amount": 220,
	},
	# Pastel sunset clouds (the sky stage): warm light, purple shadows, no petals
	2: {
		"haze": Color(0.98, 0.74, 0.62), "haze_far": 0.22, "haze_near": 0.04, "desat": 0.1,
		"shadow": Color(0.88, 0.76, 1.0), "highlight": Color(1.04, 0.98, 0.92),
		"saturation": 1.05, "contrast": 1.05,
		"glow": 0.16, "glow_threshold": 0.8, "glow_color": Color(1.0, 0.85, 0.7), "vignette": 0.15,
		"particles": "", "particle_color": Color(1.0, 0.45, 0.6), "particle_amount": 260,   # (no petals)
	},
	# Purple stage: gentle violet tint (its background is mostly one big shape, so little haze)
	4: {
		"haze": Color(0.36, 0.26, 0.55), "haze_far": 0.12, "haze_near": 0.0, "desat": 0.05,
		"shadow": Color(0.85, 0.8, 1.1), "highlight": Color(1.04, 0.98, 1.05),
		"saturation": 1.05, "contrast": 1.06,
		"glow": 0.16, "glow_threshold": 0.8, "glow_color": Color(0.9, 0.75, 1.0), "vignette": 0.15,
		"particles": "motes", "particle_color": Color(1.0, 0.8, 1.0), "particle_amount": 220,
	},
	# Grey city: INARI-style smoky dusk: red shadows, orange light, rising embers
	5: {
		"haze": Color(0.85, 0.42, 0.26), "haze_far": 0.4, "haze_near": 0.1, "desat": 0.35,
		"shadow": Color(0.95, 0.6, 0.55), "highlight": Color(1.12, 0.92, 0.72),
		"saturation": 1.1, "contrast": 1.1,
		"glow": 0.16, "glow_threshold": 0.8, "glow_color": Color(1.0, 0.6, 0.3), "vignette": 0.15,
		"particles": "embers", "particle_color": Color(1.0, 0.7, 0.3), "particle_amount": 280,
	},
	# Every 4th floor (scrolling stage): neutral but still graded
	6: {
		"haze": Color(0.4, 0.45, 0.6), "haze_far": 0.25, "haze_near": 0.05, "desat": 0.1,
		"shadow": Color(0.88, 0.9, 1.08), "highlight": Color(1.03, 1.01, 0.98),
		"saturation": 1.04, "contrast": 1.05,
		"glow": 0.16, "glow_threshold": 0.8, "glow_color": Color(1, 1, 1), "vignette": 0.15,
		"particles": "motes", "particle_color": Color(0.9, 0.95, 1.0), "particle_amount": 200,
	},
}

## Depth and lighting settings per stage (merged into the preset above).
##  blur_far: background softness in art pixels (farthest layer)
##  rays_*: light shafts (source is a screen position, 0-1)
##  ambient: how lit the play layer is outside the character lights (1 = fully lit)
##  light: colour/energy of the light each character carries
##  foreground: "foliage", "rubble" or "" for none
const DEPTH := {
	1: {"blur_far": 0.0, "rays": 0.0, "rays_source": Vector2(0.62, 0.02), "rays_threshold": 0.8, "rays_color": Color(0.7, 0.85, 1.0),
		"ambient": Color(1, 1, 1), "light": Color(0.75, 0.88, 1.0), "light_energy": 0.0,
		"foreground": "", "fg_color": Color(0.02, 0.03, 0.07)},
	2: {"blur_far": 0.0, "rays": 0.0, "rays_source": Vector2(0.72, 0.0), "rays_threshold": 0.8, "rays_color": Color(1.0, 0.85, 0.65),
		"ambient": Color(1, 1, 1), "light": Color(1.0, 0.88, 0.75), "light_energy": 0.0,
		"foreground": "", "fg_color": Color(0.12, 0.05, 0.1)},
	4: {"blur_far": 0.0, "rays": 0.0, "rays_source": Vector2(0.3, 0.0), "rays_threshold": 0.8, "rays_color": Color(0.9, 0.7, 1.0),
		"ambient": Color(1, 1, 1), "light": Color(0.95, 0.8, 1.0), "light_energy": 0.0,
		"foreground": "", "fg_color": Color(0.05, 0.02, 0.08)},
	5: {"blur_far": 0.0, "rays": 0.0, "rays_source": Vector2(0.25, 0.0), "rays_threshold": 0.8, "rays_color": Color(1.0, 0.65, 0.35),
		"ambient": Color(1, 1, 1), "light": Color(1.0, 0.72, 0.45), "light_energy": 0.0,
		"foreground": "", "fg_color": Color(0.08, 0.02, 0.01)},
	6: {"blur_far": 0.0, "rays": 0.0, "rays_source": Vector2(0.5, 0.0), "rays_threshold": 0.8, "rays_color": Color(1, 1, 1),
		"ambient": Color(1, 1, 1), "light": Color(1.0, 1.0, 1.0), "light_energy": 0.0,
		"foreground": "", "fg_color": Color(0.03, 0.04, 0.07)},
}

## How much faster than the world the foreground scrolls (1 = same speed)
const FOREGROUND_SPEED := 1.7

## Size of one sprite pixel in world units (matches Camera2D.gd), so particles
## are drawn with the same pixel size as the characters.
const ART_PIXEL := 1.125
## Bloom: a gentle glow on only the brightest parts of the screen.
## Per stage it is "glow" (strength) and "glow_threshold" (how bright before it glows) in PRESETS.
const GLOW_RADIUS_PX := 6.0

var preset: Dictionary = {}
var post_layer: CanvasLayer
var post_material: ShaderMaterial
var particles: CPUParticles2D
var haze_materials: Array[ShaderMaterial] = []
var ambient: CanvasModulate
var character_lights := {}          # character -> PointLight2D
var light_texture: Texture2D
var foreground_layer: CanvasLayer
var foreground_sprites: Array[Sprite2D] = []
var foreground_width := 0.0
var _effects_on := true
var _other_modulates := 0           # boss chunks that bring their own CanvasModulate
var reflections := {}               # character -> Sprite2D mirror image
var reflection_strength := REFLECTION_STRENGTH
var wet_amount := 0.0               # set by weather.gd when it rains
var character_light: Dictionary = {}
var character_materials: Array[ShaderMaterial] = []
var weather: Node2D
var city_depth: Node2D


func setup(background: Node, background_id: int) -> void:
	preset = PRESETS.get(background_id, PRESETS[6]).duplicate()
	preset.merge(DEPTH.get(background_id, DEPTH[6]))
	_apply_haze(background)
	_build_post()
	_build_particles()
	_build_lighting()
	_build_foreground()
	character_light = CHARACTER_LIGHT.get(background_id, CHARACTER_LIGHT[6])
	add_child(preload("res://Scripts/Effects/character_fx.gd").new())   # speed streaks, sonic boom, sparks, hit flash
	weather = WEATHER.new()
	add_child(weather)
	weather.setup(background, background_id, self)
	# City depth layers (buildings behind, street furniture in front)
	var city = preload("res://Scripts/Level/city_depth.gd")
	if city.applies_to(background_id):
		city_depth = city.new()
		city_depth.setup(background_id)
		add_child(city_depth)
	_set_effects(Test.effects_enabled)


func _process(_delta: float) -> void:
	if Test.effects_enabled != _effects_on:
		_set_effects(Test.effects_enabled)
	# Keep the particle emitter centred on what the camera sees
	var cam := get_viewport().get_camera_2d()
	if particles and cam:
		particles.global_position = cam.get_screen_center_position()
	_update_character_lights()
	_update_foreground(cam)
	_update_reflections()
	_update_character_materials()
	_update_afterimages(_delta)


# ── 1. Depth haze ───────────────────────────────────────────────────────────
func _apply_haze(background: Node) -> void:
	var layers: Array = []
	for child in background.get_children():
		if child is ParallaxLayer:
			layers.append(child)
	if layers.is_empty():
		return
	# Smaller motion_scale = moves less = further away
	layers.sort_custom(func(a, b): return a.motion_scale.x < b.motion_scale.x)
	var n := layers.size()
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)   # 0 = farthest, 1 = nearest
		var amount: float = lerp(float(preset.haze_far), float(preset.haze_near), t)
		var desat: float = float(preset.desat) * (1.0 - t)
		var blur: float = 0.0 if Test.mobile else float(preset.blur_far) * (1.0 - t)
		for item in _canvas_items(layers[i]):
			if item.material != null:
				continue  # never replace a material you already set up
			var m := ShaderMaterial.new()
			m.shader = HAZE_SHADER
			m.set_shader_parameter("haze_color", preset.haze)
			m.set_shader_parameter("haze_amount", amount)
			m.set_shader_parameter("desaturate", desat)
			m.set_shader_parameter("blur_texels", blur)
			m.set_meta("haze_amount", amount)   # remembered for the Effects toggle
			m.set_meta("desaturate", desat)
			m.set_meta("blur_texels", blur)
			item.material = m
			haze_materials.append(m)


func _canvas_items(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is CanvasItem:
			out.append(child)
		out.append_array(_canvas_items(child))
	return out


# ── 2. Colour grade, glow, vignette ─────────────────────────────────────────
func _build_post() -> void:
	post_layer = CanvasLayer.new()
	post_layer.layer = 5   # above the world, below the HUD (layer 10)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_material = ShaderMaterial.new()
	post_material.shader = POST_SHADER
	post_material.set_shader_parameter("shadow_tint", preset.shadow)
	post_material.set_shader_parameter("highlight_tint", preset.highlight)
	post_material.set_shader_parameter("saturation", preset.saturation)
	post_material.set_shader_parameter("contrast", preset.contrast)
	# Glow is the expensive part; skip it on phones/tablets
	post_material.set_shader_parameter("glow_strength", 0.0 if Test.mobile else float(preset.glow))
	post_material.set_shader_parameter("glow_threshold", preset.glow_threshold)
	post_material.set_shader_parameter("glow_color", preset.glow_color)
	post_material.set_shader_parameter("glow_radius_px", GLOW_RADIUS_PX)
	post_material.set_shader_parameter("vignette_strength", preset.vignette)
	post_material.set_shader_parameter("rays_strength", 0.0 if Test.mobile else float(preset.rays))
	post_material.set_shader_parameter("rays_source", preset.rays_source)
	post_material.set_shader_parameter("rays_threshold", preset.rays_threshold)
	post_material.set_shader_parameter("rays_color", preset.rays_color)
	rect.material = post_material
	post_layer.add_child(rect)
	add_child(post_layer)


# ── 3. Ambient particles ────────────────────────────────────────────────────
func _build_particles() -> void:
	var kind: String = preset.particles
	if kind == "":
		return   # this stage has none
	particles = CPUParticles2D.new()
	particles.local_coords = false          # particles stay in the world, so they scroll naturally
	particles.amount = int(preset.particle_amount) / 5   # sparse, so they read as accents
	particles.lifetime = 5.0
	particles.preprocess = 5.0              # start the stage already full of particles
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(800, 450)   # about one screen, so they stay dense
	particles.z_index = 3                   # drift in front of the stage
	particles.texture = _particle_texture(kind)
	particles.scale_amount_min = ART_PIXEL * 2.0
	particles.scale_amount_max = ART_PIXEL * 3.0
	# (Normal blending: additive "glowing" particles bloom too much.)
	var ramp := Gradient.new()
	var c: Color = preset.particle_color
	ramp.set_color(0, Color(c, 0.0))
	ramp.set_color(1, Color(c, 0.0))
	ramp.add_point(0.15, Color(c, 0.9))
	ramp.add_point(0.8, Color(c, 0.7))
	particles.color_ramp = ramp
	match kind:
		"petals":
			particles.direction = Vector2(-1, 0.6)
			particles.spread = 25
			particles.gravity = Vector2(0, 12)
			particles.initial_velocity_min = 25
			particles.initial_velocity_max = 60
			particles.angular_velocity_min = -90
			particles.angular_velocity_max = 90
		"embers":
			particles.direction = Vector2(0.3, -1)
			particles.spread = 30
			particles.gravity = Vector2(0, -6)
			particles.initial_velocity_min = 20
			particles.initial_velocity_max = 55
			particles.angular_velocity_min = -30
			particles.angular_velocity_max = 30
		_:  # motes: slow, floaty
			particles.direction = Vector2(0, -1)
			particles.spread = 180
			particles.gravity = Vector2.ZERO
			particles.initial_velocity_min = 4
			particles.initial_velocity_max = 16
	add_child(particles)


func _particle_texture(kind: String) -> Texture2D:
	# Tiny original pixel shapes, drawn in white and tinted by the colour ramp
	var shape: Array
	match kind:
		"petals": shape = [".##", "###", "##."]
		"embers": shape = ["##", "##"]
		_: shape = [".#.", "###", ".#."]
	var img := Image.create(shape[0].length(), shape.size(), false, Image.FORMAT_RGBA8)
	for y in shape.size():
		for x in shape[y].length():
			img.set_pixel(x, y, Color.WHITE if shape[y][x] == "#" else Color(1, 1, 1, 0))
	return ImageTexture.create_from_image(img)


# ── On/off ──────────────────────────────────────────────────────────────────
func _set_effects(on: bool) -> void:
	_effects_on = on
	if post_layer:
		post_layer.visible = on
	if particles:
		particles.emitting = on
		particles.visible = on
	for m in haze_materials:
		m.set_shader_parameter("haze_amount", float(m.get_meta("haze_amount")) if on else 0.0)
		m.set_shader_parameter("desaturate", float(m.get_meta("desaturate")) if on else 0.0)
		m.set_shader_parameter("blur_texels", float(m.get_meta("blur_texels")) if on else 0.0)
	if ambient:
		ambient.visible = on and _other_modulates == 0 and preset.ambient != Color(1, 1, 1)
	for light in character_lights.values():
		if is_instance_valid(light):
			light.enabled = on
	if foreground_layer:
		foreground_layer.visible = on
	for r in reflections.values():
		if is_instance_valid(r):
			r.visible = on
	if weather:
		weather.set_enabled(on)
	if city_depth:
		city_depth.set_enabled(on)
	for g in get_tree().get_nodes_in_group("fx_glow"):
		g.visible = on
	for d in get_tree().get_nodes_in_group("fx_depth"):
		d.visible = on
	for m in character_materials:
		_apply_character_light(m, on)


# ── 6. Light and shadow ─────────────────────────────────────────────────────
func _build_lighting() -> void:
	# The play layer sits in shade; each character carries a pool of light,
	# so characters pop out of the scene like in INARI.
	ambient = CanvasModulate.new()
	ambient.color = preset.ambient
	add_child(ambient)
	if preset.ambient == Color(1, 1, 1):
		ambient.visible = false
	# Boss floors animate their own CanvasModulate; Godot only uses one, so step aside
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	for node in get_tree().root.find_children("*", "CanvasModulate", true, false):
		if node != ambient:
			_other_modulates += 1
	ambient.visible = _other_modulates == 0 and preset.ambient != Color(1, 1, 1)

	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	light_texture = tex


func _on_node_added(node: Node) -> void:
	if node is CanvasModulate and node != ambient:
		_other_modulates += 1
		if ambient:
			ambient.visible = false


func _on_node_removed(node: Node) -> void:
	if node is CanvasModulate and node != ambient:
		_other_modulates = max(0, _other_modulates - 1)
		if ambient:
			ambient.visible = _effects_on and _other_modulates == 0 and preset.ambient != Color(1, 1, 1)


func _update_character_lights() -> void:
	if light_texture == null or float(preset.light_energy) <= 0.0:
		return
	for character in get_tree().get_nodes_in_group("all_characters"):
		if not is_instance_valid(character) or not character is Node2D:
			continue
		var light: PointLight2D = character_lights.get(character)
		if light == null or not is_instance_valid(light):
			light = PointLight2D.new()
			light.texture = light_texture
			light.texture_scale = 3.2               # about 800 world units across
			light.color = preset.light
			# The lead character gets the full light, followers a softer one
			light.energy = float(preset.light_energy) * (0.6 if character.get("is_player") else 0.35)
			light.blend_mode = Light2D.BLEND_MODE_ADD
			light.enabled = _effects_on
			add_child(light)
			character_lights[character] = light
		light.global_position = character.global_position + Vector2(0, -20)
	# Clean up lights for characters that left
	for character in character_lights.keys():
		if not is_instance_valid(character):
			var light = character_lights[character]
			if is_instance_valid(light):
				light.queue_free()
			character_lights.erase(character)


# ── 7. Foreground silhouettes ───────────────────────────────────────────────
func _build_foreground() -> void:
	var kind: String = preset.foreground
	if kind == "":
		return
	foreground_layer = CanvasLayer.new()
	foreground_layer.layer = 4   # in front of the world, under the colour grade (5) and HUD (10)
	add_child(foreground_layer)
	# Drawn small and stretched with smooth filtering, so the shapes are out of focus
	var stretch := 5.0
	# Bottom strip, shown when you're high above the ground. Add {"top": true}
	# entries for a hanging strip along the top.
	for strip in [{"seed": 7, "top": false, "speed": FOREGROUND_SPEED}]:
		var tex := _foreground_texture(kind, preset.fg_color, strip.seed, 1.6 if strip.top else 1.0)
		foreground_width = tex.get_width() * stretch
		for i in 2:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.scale = Vector2(stretch, stretch)
			sprite.flip_v = strip.top
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.set_meta("top", strip.top)
			sprite.set_meta("speed", strip.speed)
			sprite.set_meta("index", i)
			foreground_layer.add_child(sprite)
			foreground_sprites.append(sprite)


func _update_foreground(cam: Camera2D) -> void:
	if foreground_sprites.is_empty() or cam == null:
		return
	var view := get_viewport().get_visible_rect().size
	for sprite in foreground_sprites:
		var h: float = sprite.texture.get_height() * sprite.scale.y
		# Scrolls faster than the world, so it reads as close to the camera
		var speed: float = sprite.get_meta("speed")
		var x := -fposmod(cam.get_screen_center_position().x * cam.zoom.x * speed, foreground_width)
		var y := -6.0 if sprite.get_meta("top") else view.y - h + 6.0
		sprite.position = Vector2(x + int(sprite.get_meta("index")) * foreground_width, y)


func _foreground_texture(kind: String, color: Color, seed_value: int = 7, size: float = 1.0) -> Texture2D:
	# Original generated silhouettes (not art from any game): clusters of
	# bushes or rubble with gaps between them, drawn at low resolution.
	var w := 420
	var h := int(30 * size)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(color, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value  # same shapes every time
	var x := rng.randi_range(10, 60)
	while x < w - 30:
		var cluster_w := int(rng.randi_range(40, 90) * size)
		if kind == "rubble":
			for _i in rng.randi_range(3, 6):
				var bw := int(rng.randi_range(6, 22) * size)
				var bh := int(rng.randi_range(5, 20) * size)
				var bx := x + rng.randi_range(0, cluster_w - bw)
				_fill_rect(img, bx, h - bh, bw, bh, color)
			# a pipe or girder now and then
			if rng.randf() < 0.5:
				_fill_rect(img, x - 4, h - rng.randi_range(14, 24), cluster_w + 8, 3, color)
		else:
			for _i in rng.randi_range(4, 8):
				var r := int(rng.randi_range(5, 13) * size)
				var cx := x + rng.randi_range(r, cluster_w - r)
				var cy := h - rng.randi_range(r / 2, r + 6)
				_fill_circle(img, cx, cy, r, color)
			_fill_rect(img, x, h - 6, cluster_w, 6, color)
		x += cluster_w + int(rng.randi_range(50, 140) * size * size)  # leave gaps so the view stays open
	_blur_alpha(img, color, 2)  # soften the edges: these shapes are "out of focus"
	return ImageTexture.create_from_image(img)


func _blur_alpha(img: Image, color: Color, radius: int) -> void:
	# Two passes of a box blur on the alpha channel (shapes are one colour)
	var w := img.get_width()
	var h := img.get_height()
	var a := PackedFloat32Array()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = img.get_pixel(x, y).a
	for _pass in 2:
		var tmp := PackedFloat32Array()
		tmp.resize(w * h)
		for y in h:
			for x in w:
				var sum := 0.0
				for k in range(-radius, radius + 1):
					sum += a[y * w + clampi(x + k, 0, w - 1)]
				tmp[y * w + x] = sum / (radius * 2 + 1)
		for y in h:
			for x in w:
				var sum := 0.0
				for k in range(-radius, radius + 1):
					sum += tmp[clampi(y + k, 0, h - 1) * w + x]
				a[y * w + x] = sum / (radius * 2 + 1)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(color, a[y * w + x]))


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(max(0, y), min(img.get_height(), y + h)):
		for xx in range(max(0, x), min(img.get_width(), x + w)):
			img.set_pixel(xx, yy, color)


func _fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for yy in range(max(0, cy - r), min(img.get_height(), cy + r + 1)):
		for xx in range(max(0, cx - r), min(img.get_width(), cx + r + 1)):
			if (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) <= r * r:
				img.set_pixel(xx, yy, color)


# ── 8. Floor reflections ────────────────────────────────────────────────────
func _update_reflections() -> void:
	if not FLOOR_REFLECTIONS:
		return
	if not _effects_on:
		return
	var space := get_world_2d().direct_space_state
	for character in get_tree().get_nodes_in_group("all_characters"):
		if not is_instance_valid(character) or not character is CollisionObject2D:
			continue
		var sprite := character.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null:
			continue
		var mirror: Sprite2D = reflections.get(character)
		if mirror == null or not is_instance_valid(mirror):
			mirror = Sprite2D.new()
			var m := ShaderMaterial.new()
			m.shader = REFLECTION_SHADER
			m.set_shader_parameter("fade_length", REFLECTION_FADE)
			m.set_shader_parameter("strength", reflection_strength)
			m.set_shader_parameter("tint", preset.light)
			m.set_shader_parameter("shimmer", 0.6)
			mirror.material = m
			mirror.z_index = 1   # over the ground it's reflected in
			add_child(mirror)
			reflections[character] = mirror
		# Find the floor straight below the character
		var from: Vector2 = character.global_position
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 320), character.collision_mask, [character.get_rid()])
		var hit := space.intersect_ray(query)
		# Only mirror on fairly flat ground (on walls and loops a mirror looks wrong)
		if hit.is_empty() or abs(hit.normal.x) > 0.35 or not sprite.is_visible_in_tree():
			mirror.visible = false
			continue
		var floor_y: float = hit.position.y
		mirror.visible = true
		# Copy the character's current animation frame
		mirror.texture = sprite.texture
		mirror.hframes = sprite.hframes
		mirror.vframes = sprite.vframes
		mirror.frame = sprite.frame
		mirror.flip_h = sprite.flip_h
		mirror.offset = sprite.offset
		mirror.centered = sprite.centered
		mirror.region_enabled = sprite.region_enabled
		mirror.region_rect = sprite.region_rect
		mirror.modulate = sprite.modulate
		# Mirror the sprite's transform across the floor line
		var flip := Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2(0, 2.0 * floor_y))
		mirror.global_transform = flip * sprite.global_transform
		(mirror.material as ShaderMaterial).set_shader_parameter("floor_y", floor_y)
	for character in reflections.keys():
		if not is_instance_valid(character):
			var r = reflections[character]
			if is_instance_valid(r):
				r.queue_free()
			reflections.erase(character)


# ── 9. Character lighting ───────────────────────────────────────────────────
func _update_character_materials() -> void:
	for character in get_tree().get_nodes_in_group("all_characters"):
		if not is_instance_valid(character):
			continue
		if character.has_meta("stage_lit"):
			# Keep the rim on the correct side when the character turns around
			var lit_sprite := character.get_node_or_null("Sprite2D") as Sprite2D
			if lit_sprite and lit_sprite.material is ShaderMaterial:
				(lit_sprite.material as ShaderMaterial).set_shader_parameter("flip", -1.0 if lit_sprite.flip_h else 1.0)
			continue
		var sprite := character.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null or sprite.material != null:
			continue   # never replace a material the character already uses
		var m := ShaderMaterial.new()
		m.shader = CHARACTER_SHADER
		_apply_character_light(m, _effects_on)
		sprite.material = m
		character_materials.append(m)
		character.set_meta("stage_lit", true)


func _apply_character_light(m: ShaderMaterial, on: bool) -> void:
	m.set_shader_parameter("tint", character_light.get("tint", Color.WHITE) if on else Color.WHITE)
	m.set_shader_parameter("rim_color", character_light.get("rim", Color.WHITE))
	m.set_shader_parameter("rim_strength", float(character_light.get("rim_strength", 0.0)) if on else 0.0)
	m.set_shader_parameter("light_dir", character_light.get("from", Vector2(0, -1)))
	m.set_shader_parameter("wet", wet_amount if on else 0.0)


# ── 11. Pixel afterimages ───────────────────────────────────────────────────
## During an air spin or an air-up, characters leave crisp fading copies of their sprite.
## Normal running keeps the game's own ribbon trail.
const AFTERIMAGE_INTERVAL := 0.04   # seconds between copies
const AFTERIMAGE_LIFE := 0.22       # how long each copy takes to fade
const AFTERIMAGE_ANIMS := ["airspin", "airup"]   # moves that leave afterimages
var _afterimage_timers := {}


func _update_afterimages(delta: float) -> void:
	for character in get_tree().get_nodes_in_group("all_characters"):
		if not is_instance_valid(character) or not character is CharacterBody2D:
			continue
		# The game's own ribbon trail is used for running; afterimages are kept for the air spin
		if not _effects_on:
			continue
		var sprite := character.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null or not sprite.is_visible_in_tree():
			continue
		var t: float = _afterimage_timers.get(character, 0.0) - delta
		var ap = character.get("ap")
		var spinning: bool = ap is AnimationPlayer and ap.current_animation in AFTERIMAGE_ANIMS
		if not spinning:
			_afterimage_timers[character] = 0.0
			continue
		if t > 0.0:
			_afterimage_timers[character] = t
			continue
		_afterimage_timers[character] = AFTERIMAGE_INTERVAL
		var ghost := Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.hframes = sprite.hframes
		ghost.vframes = sprite.vframes
		ghost.frame = sprite.frame
		ghost.flip_h = sprite.flip_h
		ghost.offset = sprite.offset
		ghost.centered = sprite.centered
		ghost.z_index = sprite.z_index - 1
		var tint: Color = character_light.get("rim", Color(0.6, 0.8, 1.0))
		ghost.modulate = Color(tint.r, tint.g, tint.b, 0.5)
		add_child(ghost)
		ghost.global_transform = sprite.global_transform
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_LIFE)
		tw.tween_callback(ghost.queue_free)
