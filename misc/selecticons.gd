extends Node2D
class_name SelectableCharacter

static var currently_hovered_character: SelectableCharacter = null

# === Signals ===
signal sprite_hovered(sprite: SelectableCharacter)
signal sprite_unhovered(sprite: SelectableCharacter)
signal sprite_selected(sprite: SelectableCharacter)
signal sprite_deselected(sprite: SelectableCharacter)

# === Character Info ===
@export var character_name: String = "Character"
@export var character_description: String = "A mysterious fighter"

# === Texture Handling ===
@export_group("Sprite Textures")
@export var sprite2_texture: Texture2D : set = set_sprite2_texture

@export_group("Texture Sets")
@export var texture_sets: Array[TextureSet] = []

class TextureSet extends Resource:
	@export var name: String = "Set"
	@export var sprite2_tex: Texture2D

# === Hover / Select Animation Settings ===
@export var hover_scale: float = 1.15
@export var select_scale: float = 1.1
@export var hover_color: Color = Color.CYAN
@export var select_color: Color = Color.YELLOW
@export var animation_duration: float = 0.15
@export var lightning_color: Color = Color.WHITE
@export var lightning_intensity: float = 2.0

# === Nodes ===
@onready var sprite1: Sprite2D = $Sprite2D
@onready var sprite2: Sprite2D = $Sprite2D2
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var selection_indicator: Node2D = $SelectionIndicator if has_node("SelectionIndicator") else null
@onready var hover_outline: Node2D = $HoverOutline if has_node("HoverOutline") else null

# === Interaction Setup ===
var tween: Tween
var area_2d: Area2D
var collision_shape: CollisionShape2D
var original_scale: Vector2
var original_modulate: Color
var is_hovered := false
var is_selected := false

func _ready():
	$AnimationPlayer.play("play")
	original_scale = scale
	original_modulate = modulate
	tween = create_tween()
	tween.kill()

	if sprite2_texture:
		set_sprite2_texture(sprite2_texture)

	setup_input_area()

func _input(event):
	if event.is_action_pressed("ui_cancel") and is_selected:
		deselect_sprite()

func set_sprite2_texture(texture: Texture2D):
	sprite2_texture = texture
	if sprite2:
		sprite2.texture = texture

func apply_texture_set(index: int):
	if index >= 0 and index < texture_sets.size():
		var set = texture_sets[index]
		set_sprite2_texture(set.sprite2_tex)

func apply_texture_set_by_name(set_name: String):
	for i in texture_sets.size():
		if texture_sets[i].name == set_name:
			apply_texture_set(i)
			return

# === Selection + Hover ===

func setup_input_area():
	area_2d = Area2D.new()
	add_child(area_2d)

	collision_shape = CollisionShape2D.new()
	area_2d.add_child(collision_shape)

	var tex = sprite1.texture if sprite1 else null
	if tex:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = tex.get_size()
		collision_shape.shape = rect_shape
	else:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(45, 25)
		collision_shape.shape = rect_shape

	area_2d.input_event.connect(_on_input_event)
	area_2d.mouse_entered.connect(_on_mouse_entered)
	area_2d.mouse_exited.connect(_on_mouse_exited)

# === Modified hover functions ===

func _on_mouse_entered():
	if not is_selected:
		# Check if another character is already hovered
		if SelectableCharacter.currently_hovered_character != null and SelectableCharacter.currently_hovered_character != self:
			SelectableCharacter.currently_hovered_character.force_unhover()
		
		$AudioStreamPlayer.play()
		set_hovered(true)
		SelectableCharacter.currently_hovered_character = self

func _on_mouse_exited():
	if not is_selected:
		set_hovered(false)
		if SelectableCharacter.currently_hovered_character == self:
			SelectableCharacter.currently_hovered_character = null
			
# Add this new function to force unhover from external calls:
func force_unhover():
	if is_hovered and not is_selected:
		set_hovered(false)


func _on_input_event(viewport: Viewport, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_sprite()
		$AudioStreamPlayer2.play()

func set_hovered(hovered: bool):
	if is_hovered == hovered: return
	is_hovered = hovered
	if hovered:
		animate_hover_in()
		sprite_hovered.emit(self)
	else:
		animate_hover_out()
		sprite_unhovered.emit(self)

func select_sprite():
	if is_selected:
		deselect_sprite()
		return
	sprite_selected.emit(self)
	set_selected(true)

func deselect_sprite():
	if not is_selected:
		return
	sprite_deselected.emit(self)
	set_selected(false)

func set_selected(selected: bool):
	if is_selected == selected: return
	is_selected = selected
	if selected:
		animate_select()
	else:
		animate_deselect()

# === Animations ===

func animate_hover_in():
	tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", original_scale * hover_scale, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate", hover_color, animation_duration * 0.3)
	create_lightning_flash()
	if hover_outline:
		hover_outline.visible = true
		tween.tween_property(hover_outline, "modulate:a", 1.0, animation_duration)

func animate_hover_out():
	if is_selected: return
	tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", original_scale, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "modulate", original_modulate, animation_duration * 0.5)
	if hover_outline:
		tween.tween_property(hover_outline, "modulate:a", 0.0, animation_duration * 0.5)
		tween.tween_callback(func(): hover_outline.visible = false).set_delay(animation_duration * 0.5)

func animate_select():
	tween.kill()
	tween = create_tween().set_parallel(true)
	var pop_scale = original_scale * select_scale * 1.2
	tween.tween_property(self, "scale", pop_scale, animation_duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", original_scale * select_scale, animation_duration * 0.6).set_delay(animation_duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "modulate", lightning_color, animation_duration * 0.2)
	tween.tween_property(self, "modulate", select_color, animation_duration * 0.3).set_delay(animation_duration * 0.2)
	if selection_indicator:
		selection_indicator.visible = true
		selection_indicator.modulate.a = 0.0
		tween.tween_property(selection_indicator, "modulate:a", 1.0, animation_duration)
	if hover_outline:
		hover_outline.visible = false

func animate_deselect():
	tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", original_scale, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "modulate", original_modulate, animation_duration)
	if selection_indicator:
		tween.tween_property(selection_indicator, "modulate:a", 0.0, animation_duration * 0.5)
		tween.tween_callback(func(): selection_indicator.visible = false).set_delay(animation_duration * 0.5)

func create_lightning_flash():
	var flash = create_tween()
	flash.tween_property(self, "modulate", lightning_color * lightning_intensity, 0.05)
	flash.tween_property(self, "modulate", hover_color, 0.1)

func create_lightning_burst():
	var burst_tween = create_tween().set_parallel(true)
	for i in range(3):
		var delay = i * 0.03
		burst_tween.tween_callback(func():
			var flash = create_tween()
			flash.tween_property(self, "modulate", lightning_color * lightning_intensity, 0.02)
			flash.tween_property(self, "modulate", select_color, 0.08)
		).set_delay(delay)

# === Utilities ===
func swap_textures():
	if sprite1 and sprite2:
		var temp = sprite1.texture
		sprite1.texture = sprite2.texture
		set_sprite2_texture(temp)

func clear_texture():
	set_sprite2_texture(null)

func get_current_textures() -> Dictionary:
	return {
		"sprite1": sprite1.texture if sprite1 else null,
		"sprite2": sprite2.texture if sprite2 else null
	}

func get_character_data() -> Dictionary:
	return {
		"name": character_name,
		"description": character_description,
		"sprite": self
	}

func set_character_data(data: Dictionary):
	if data.has("name"):
		character_name = data.name
	if data.has("description"):
		character_description = data.description

func force_deselect():
	# Just call deselect_sprite to ensure animations and signals run properly
	deselect_sprite()
