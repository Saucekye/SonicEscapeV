extends CPUParticles2D
# The rest areas' pale motes, drifting slowly through the night air

const COLOR := Color(0.85, 0.95, 1.0)
const AMOUNT := 44
const ART_PIXEL := 1.125     # one sprite pixel in world units
const SHAPE := [".#.", "###", ".#."]


func _ready() -> void:
	local_coords = false          # they stay in the world and scroll past
	amount = AMOUNT
	lifetime = 5.0
	preprocess = 5.0              # already full when you arrive
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(800, 450)
	z_index = 3
	texture = _texture()
	scale_amount_min = ART_PIXEL * 2.0
	scale_amount_max = ART_PIXEL * 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(COLOR, 0.0))
	ramp.set_color(1, Color(COLOR, 0.0))
	ramp.add_point(0.15, Color(COLOR, 0.9))
	ramp.add_point(0.8, Color(COLOR, 0.7))
	color_ramp = ramp
	direction = Vector2(0, -1)
	spread = 180
	gravity = Vector2.ZERO
	initial_velocity_min = 4
	initial_velocity_max = 16


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position = cam.get_screen_center_position()


func _texture() -> Texture2D:
	var img := Image.create(SHAPE[0].length(), SHAPE.size(), false, Image.FORMAT_RGBA8)
	for y in SHAPE.size():
		for x in SHAPE[y].length():
			img.set_pixel(x, y, Color.WHITE if SHAPE[y][x] == "#" else Color(1, 1, 1, 0))
	return ImageTexture.create_from_image(img)
