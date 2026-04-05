extends Sprite2D

# === Signals ===
signal sprite_hovered(sprite: Sprite2D)
signal sprite_unhovered(sprite: Sprite2D)
signal sprite_clicked(sprite: Sprite2D)

# === Hover Animation Settings ===
@export var hover_scale: float = 1.15
@export var hover_color: Color = Color.CYAN
@export var animation_duration: float = 0.15

# === Pick 3 textures in Inspector ===
@export var texture_1: Texture2D
@export var texture_2: Texture2D
@export var texture_3: Texture2D

# === Nodes ===
var area_2d: Area2D
var collision_shape: CollisionShape2D
var tween: Tween
var original_scale: Vector2
var original_modulate: Color
var is_hovered := false

func _ready():
	randomize()
	
	set_random_texture()
	
	original_scale = scale
	original_modulate = self_modulate
	tween = create_tween()
	tween.kill()
	
	setup_input_area()

# =========================
# RANDOM PICK FROM 3
# =========================
func set_random_texture():
	var options: Array[Texture2D] = []
	
	if texture_1: options.append(texture_1)
	if texture_2: options.append(texture_2)
	if texture_3: options.append(texture_3)
	
	if options.size() == 0:
		push_error("No textures assigned!")
		return
	
	texture = options[randi() % options.size()]

# =========================
# INPUT SETUP (UNCHANGED)
# =========================
func setup_input_area():
	area_2d = Area2D.new()
	add_child(area_2d)
	
	collision_shape = CollisionShape2D.new()
	area_2d.add_child(collision_shape)
	
	if texture:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = texture.get_size()
		collision_shape.shape = rect_shape
	else:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(100, 100)
		collision_shape.shape = rect_shape
	
	area_2d.input_event.connect(_on_input_event)
	area_2d.mouse_entered.connect(_on_mouse_entered)
	area_2d.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	set_hovered(true)

func _on_mouse_exited():
	set_hovered(false)

func _on_input_event(viewport: Viewport, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_selection_allowed():
			sprite_clicked.emit(self)

func is_selection_allowed() -> bool:
	if Test.characterone == "":
		print("characterone is null")
		return false
	return true

# =========================
# HOVER ANIMATION (UNCHANGED)
# =========================
func set_hovered(hovered: bool):
	if is_hovered == hovered: return
	is_hovered = hovered
	
	if hovered:
		animate_hover_in()
		sprite_hovered.emit(self)
	else:
		animate_hover_out()
		sprite_unhovered.emit(self)

func animate_hover_in():
	tween.kill()
	tween = create_tween().set_parallel(true)
	
	if is_selection_allowed():
		tween.tween_property(self, "scale", original_scale * hover_scale, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "self_modulate", hover_color, animation_duration * 0.3)
	else:
		tween.tween_property(self, "scale", original_scale * 1.05, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "self_modulate", Color.RED * 0.5 + original_modulate * 0.5, animation_duration * 0.3)

func animate_hover_out():
	tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", original_scale, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "self_modulate", original_modulate, animation_duration * 0.5)
