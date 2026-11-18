class_name FlowerPlatform
extends AnimatableBody2D

@export var sprite: AnimatedSprite2D
@export var shape: CollisionShape2D
@export var platform_scale: float = 4.0     # sprite scale; use whole numbers for crisp pixel art
@export var surface_ratio: float = 0      # where the player stands on the visible flower: 0 = top edge, 0.5 = middle, 1 = bottom edge
@export var surface_offset: float = -60.0     # extra px nudge (negative = higher, positive = lower)
@export var spacing_padding: float = -2.0   # added to the visible width for spacing; negative = slight overlap, no hairline seams
@export var collision_thickness: float = 16.0

# Cache so each flower type measures its pixels only once
static var _bounds_cache: Dictionary = {}

var _visible_width: float = 100.0


func _ready() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	sprite.scale *= platform_scale
	var s := absf(sprite.scale.x)

	# Visible (non-transparent) rectangle of the flower, in the sprite's local, unscaled pixels
	var vis := _visible_rect()

	# Put the point "surface_ratio" of the way down the visible flower, at its horizontal centre, on the node's origin.
	# After this, the node origin = the surface the player stands on, and the flower is centred on x = 0.
	var anchor := Vector2(vis.position.x + vis.size.x * 0.5, vis.position.y + vis.size.y * surface_ratio)
	sprite.position = -anchor * s

	_visible_width = vis.size.x * s

	if shape:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(_visible_width, collision_thickness)
		shape.shape = rect
		shape.one_way_collision = true
		# Top edge of the collision sits on the origin (plus any nudge), so the player stands there
		shape.position = Vector2(0.0, surface_offset + collision_thickness * 0.5)

	# Random start frame and speed so flowers don't all animate in sync
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	sprite.frame = randi() % maxi(count, 1)
	sprite.speed_scale = randf_range(0.85, 1.15)
	sprite.play()


# Width used by the spawner: the visible flower, so neighbours touch with no gap
func get_width() -> float:
	return _visible_width + spacing_padding


# Union of the opaque pixels of every frame, in sprite-local coordinates (before any scaling)
func _visible_rect() -> Rect2:
	var frames := sprite.sprite_frames
	var key := [frames, sprite.animation, sprite.centered, sprite.offset]
	if _bounds_cache.has(key):
		return _bounds_cache[key]

	var union := Rect2()
	var have_any := false
	var tex_size := Vector2.ZERO

	for i in frames.get_frame_count(sprite.animation):
		var tex := frames.get_frame_texture(sprite.animation, i)
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var used := Rect2(img.get_used_rect())
		tex_size = Vector2(img.get_width(), img.get_height())
		var top_left := (-tex_size * 0.5 if sprite.centered else Vector2.ZERO) + sprite.offset
		var r := Rect2(top_left + used.position, used.size)
		union = r if not have_any else union.merge(r)
		have_any = true

	if not have_any:
		union = Rect2(Vector2(-50, -25), Vector2(100, 50))

	_bounds_cache[key] = union
	return union
