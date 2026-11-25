extends Node2D

@export var map_scale := 0.05
@export var map_offset := Vector2(20, 20)
## Space kept clear round the edge of the screen
@export var map_margin := 40.0
## Panel behind the map
@export var backing_color := Color(0.62, 0.78, 0.95, 0.85)
## Dot for each player on the map
@export var player_dot_color := Color(1.0, 0.25, 0.2)
@export var player_dot_size := 10.0

var _world: Node2D
var _dots := {}

@export var fade_speed := 5.0
@export var overlay_alpha := 0.6

@onready var overlay := $"../DarkOverlay"
@onready var overlay2 := $"../DarkOverlay2"

var fade := 0.0

func _ready():
	# Above the dark overlays
	z_index = 10
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
	if show:
		_update_dots()

	
# Called by LevelGenerator
func build_map(chunks: Array[Node2D]):
	# Clear old map
	for child in get_children():
		child.queue_free()

	var world := Node2D.new()
	world.name = "World"
	var bounds := Rect2()
	var first := true
	for chunk in chunks:
		if not is_instance_valid(chunk):
			continue
		# Only the ground and rails go on the map
		for layer in chunk.find_children("*", "TileMapLayer", true, false):
			if not layer.is_visible_in_tree() or layer.get_used_cells().is_empty():
				continue
			var copy := TileMapLayer.new()
			copy.tile_set = layer.tile_set
			copy.tile_map_data = layer.tile_map_data
			copy.collision_enabled = false
			copy.transform = layer.global_transform
			copy.modulate = layer.modulate
			copy.z_index = layer.z_index
			world.add_child(copy)
			var used: Rect2i = layer.get_used_rect()
			var size: Vector2 = layer.tile_set.tile_size
			var r: Rect2 = layer.global_transform * Rect2(Vector2(used.position) * size, Vector2(used.size) * size)
			bounds = r if first else bounds.merge(r)
			first = false
		for rail in chunk.find_children("*", "Path2D", true, false):
			if rail.curve == null or rail.curve.point_count < 2:
				continue
			var line := Line2D.new()
			line.default_color = Color(0.85, 0.85, 0.9)
			for pt in rail.curve.get_baked_points():
				line.add_point(rail.global_transform * pt)
			world.add_child(line)
	if first:
		add_child(world)
		return
	# Panel behind it all
	var back := ColorRect.new()
	back.color = backing_color
	world.add_child(back)
	world.move_child(back, 0)
	add_child(world)
	_world = world
	_dots.clear()
	# Fit it all on screen
	var screen := get_viewport_rect().size - Vector2.ONE * map_margin * 2.0
	var s := minf(map_scale, minf(screen.x / bounds.size.x, screen.y / bounds.size.y))
	world.scale = Vector2.ONE * s
	var at := Vector2.ONE * map_margin + map_offset - bounds.position * s
	at.y += (screen.y - bounds.size.y * s) * 0.5   # in the middle, top to bottom
	world.global_position = at
	for line in world.get_children():
		if line is Line2D:
			line.width = 3.0 / s
	back.position = bounds.position - Vector2.ONE * 12.0 / s
	back.size = bounds.size + Vector2.ONE * 24.0 / s


# Where the players are
func _update_dots() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	for c in get_tree().get_nodes_in_group("all_characters"):
		if not (c is Node2D):
			continue
		var dot: ColorRect = _dots.get(c)
		if dot == null or not is_instance_valid(dot):
			dot = ColorRect.new()
			dot.color = player_dot_color
			add_child(dot)
			_dots[c] = dot
		dot.size = Vector2.ONE * player_dot_size
		dot.global_position = _world.global_position + c.global_position * _world.scale - dot.size * 0.5
		dot.visible = c.is_visible_in_tree()

func _strip_node(node: Node):
	# Screen UI isn't part of the map
	for child in node.get_children():
		if child is CanvasLayer:
			node.remove_child(child)
			child.free()
	# Remove scripts
	if node.get_script():
		node.set_script(null)

	# Disable collisions
	if node is CollisionObject2D:
		node.collision_layer = 0
		node.collision_mask = 0

	for child in node.get_children():
		_strip_node(child)
