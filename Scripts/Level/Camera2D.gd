extends Camera2D

# =========================
# SHAKE
# =========================
var shake_amount: float = 0.0
var default_offset: Vector2 = Vector2.ZERO


# =========================
# LOOK AHEAD SETTINGS
# =========================
@export var look_ahead_distance: float = 0.9
@export var look_ahead_smoothness: float = 1.0
@export var velocity_threshold: float = 300.0


# =========================
# ATTRACT CAMERA SETTINGS
# =========================
@export var attract_speed: float = 3.0

var velocity: Vector2 = Vector2.ZERO
var attract_mode := false
var attract_target: Node2D = null


# =========================
# PIXEL-PERFECT ZOOM
# =========================
## Size of one sprite pixel in world units: character scale (125) x sprite scale (0.009).
@export var art_pixel_world_size: float = 1.125
## Base zoom. "Wide" uses the nearest whole-pixel zoom to this.
@export var reference_zoom: float = 1.5

var _applied_zoom_key := ""


func _ready() -> void:
	enabled = Test.level % 4 != 0
	_apply_pixel_zoom()
	GlobalSignals.connect("camerashake", _on_camerashake)
	default_offset = offset


func _screen_stretch() -> float:
	# How much the 1600x720 game canvas is scaled up to fit the window/screen.
	var w := get_window()
	if w == null or w.content_scale_size.x <= 0 or w.content_scale_size.y <= 0:
		return 1.0
	var sx := float(w.size.x) / w.content_scale_size.x
	var sy := float(w.size.y) / w.content_scale_size.y
	return max(0.01, min(sx, sy) * w.content_scale_factor)


func _apply_pixel_zoom() -> void:
	# Picks a zoom where every sprite pixel covers a whole number of screen pixels.
	# Otherwise nearest filtering draws some pixels wider than others, and outlines
	# look lumpy and shimmer while scrolling.
	var stretch := _screen_stretch()
	var key := "%s|%s" % [stretch, Test.zoom_level]
	if key == _applied_zoom_key:
		return
	_applied_zoom_key = key
	var wide_px: float = max(1.0, round(art_pixel_world_size * reference_zoom * stretch))
	var px := wide_px               # Close (the original view)
	match Test.zoom_level:
		0: px = max(1.0, wide_px - 1.0)   # Wide: pulled further back
		2: px = wide_px + 1.0             # Closest
	var z := px / (art_pixel_world_size * stretch)
	zoom = Vector2(z, z)


func _process(delta: float) -> void:
	_apply_pixel_zoom()  # Cheap; only does work when the window size or zoom setting changes

	# =========================
	# CAMERA SHAKE
	# =========================
	if shake_amount > 0.0:
		offset = default_offset + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	else:
		offset = default_offset


	# =========================
	# ATTRACT CAMERA MODE
	# =========================
	if attract_mode and attract_target:
		var parent = get_parent()

		if parent:
			var local_target = parent.to_local(
				attract_target.global_position
			)

			position = position.lerp(
				local_target,
				attract_speed * delta
			)

		return


	# =========================
	# NORMAL PLAYER FOLLOW
	# =========================
	var parent = get_parent()

	if parent:
		rotation = lerp_angle(
			rotation,
			0,
			8 * delta
		)

		if parent.has_method("get_velocity") and parent.has_method("is_on_floor"):

			var on_ground = parent.is_on_floor()
			velocity = parent.get_velocity()

			var look_ahead_offset = Vector2.ZERO
			var target_y_offset = -0.4

			# Horizontal look ahead
			if velocity.length() >= velocity_threshold:
				look_ahead_offset = velocity.normalized() * look_ahead_distance
				look_ahead_offset.y = 0

			# Air offset
			if not on_ground:
				target_y_offset = 0.45

			var target_position = Vector2(
				look_ahead_offset.x,
				target_y_offset
			)

			position = position.lerp(
				target_position,
				look_ahead_smoothness * delta
			)


# =========================
# SHAKE FUNCTION
# =========================
func shake(time: float, amount: float) -> void:
	shake_amount = amount

	await get_tree().create_timer(time).timeout

	shake_amount = 0.0
	offset = default_offset


func _on_camerashake():
	shake_amount = 3

	await get_tree().create_timer(0.4).timeout

	shake_amount = 0.0
	offset = default_offset

# =========================
# ENTER ATTRACT CAMERA
# =========================
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("AttractCam"):
		attract_mode = true
		attract_target = body


# =========================
# EXIT ATTRACT CAMERA
# =========================
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == attract_target:
		attract_mode = false
		attract_target = null
