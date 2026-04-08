extends Label

# === Signals ===
signal sprite_hovered(sprite)
signal sprite_unhovered(sprite)
signal tutorial

# === Hover Animation Settings ===
@export var hover_scale: float = 1.15
@export var hover_color: Color = Color.CYAN
@export var animation_duration: float = 0.15

# === Pick 3 textures in Inspector ===
@export var texture_1: Texture2D
@export var texture_2: Texture2D
@export var texture_3: Texture2D

# === Internal ===
var tween: Tween
var original_scale: Vector2
var original_modulate: Color
var is_hovered := false

func _ready():
	randomize()
	
	original_scale = scale
	original_modulate = self_modulate
	
	tween = create_tween()
	tween.kill()
	
	# ✅ CRITICAL: allow this control to receive mouse
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Enable hover signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# =========================
# INPUT (REPLACES Area2D)
# =========================
#func _gui_input(event):
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			#emit_signal("tutorial")

# =========================
# HOVER
# =========================
func _on_mouse_entered():
	set_hovered(true)

func _on_mouse_exited():
	set_hovered(false)

# =========================
# HOVER ANIMATION
# =========================
func set_hovered(hovered: bool):
	if is_hovered == hovered:
		return
	
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
	
	tween.tween_property(self, "scale", original_scale * hover_scale, animation_duration)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "self_modulate", hover_color, animation_duration * 0.3)


func animate_hover_out():
	tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", original_scale, animation_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "self_modulate", original_modulate, animation_duration * 0.5)
