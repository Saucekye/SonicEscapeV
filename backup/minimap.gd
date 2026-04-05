extends Node2D

@export var map_scale := 0.05
@export var map_offset := Vector2(20, 20)

@export var fade_speed := 5.0
@export var overlay_alpha := 0.6

@onready var overlay := $"../DarkOverlay"
@onready var overlay2 := $"../DarkOverlay2"

var fade := 0.0

func _ready():
	fade = 0.0
	visible = false

	overlay.visible = false
	overlay2.visible = false

	overlay.modulate.a = 0.0
	overlay2.modulate.a = 0.0


func _process(delta):
	var holding = Input.is_action_pressed("toggle_map")

	# 🕒 Slow down game when holding map
	if holding:
		Engine.time_scale = 0.25   # 30% speed (adjust as you like)
	else:
		Engine.time_scale = 1.0   # Normal speed

	# Smooth fade target
	var target = 1.0 if holding else 0.0
	fade = move_toward(fade, target, fade_speed * delta)

	var show = fade > 0.0

	# Visibility
	visible = show
	overlay.visible = show
	overlay2.visible = show

	# Fade values
	overlay.modulate.a = fade * overlay_alpha
	overlay2.modulate.a = fade * overlay_alpha
	modulate.a = fade

	
# Called by LevelGenerator
func build_map(chunks: Array[Node2D]):
	# Clear old map
	for child in get_children():
		child.queue_free()

	for chunk in chunks:
		if not is_instance_valid(chunk):
			continue

		var mini_chunk := chunk.duplicate()
		mini_chunk.name = "Mini_" + chunk.name

		# Position + scale
		mini_chunk.global_position = chunk.global_position * map_scale + map_offset
		mini_chunk.scale = Vector2.ONE * map_scale

		# Strip physics & logic
		_strip_node(mini_chunk)

		add_child(mini_chunk)

func _strip_node(node: Node):
	# Remove scripts
	if node.get_script():
		node.set_script(null)

	# Disable collisions
	if node is CollisionObject2D:
		node.collision_layer = 0
		node.collision_mask = 0

	for child in node.get_children():
		_strip_node(child)
