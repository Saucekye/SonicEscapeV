extends Camera2D

# =========================
# SHAKE
# =========================
var shake_amount = 0
var default_offset : Vector2 = Vector2.ZERO

# =========================
# LOOK AHEAD SETTINGS
# =========================
@export var look_ahead_distance: float = 0.9
@export var look_ahead_smoothness: float = 1
@export var velocity_threshold: float = 300.0

# =========================
# ATTRACT CAMERA SETTINGS
# =========================
@export var attract_speed : float = 3.0

var velocity: Vector2 = Vector2.ZERO
var attract_mode := false
var attract_target : Node2D = null


func _ready() -> void:
	enabled = Test.level % 4 != 0
	
	# 🔒 LOCKED ZOOM (Never changes)
	zoom = Vector2(1.5, 1.5)


func _process(delta):

	# =========================
	# CAMERA SHAKE
	# =========================
	if shake_amount > 0:
		offset = default_offset + Vector2(
			randf_range(-1, 1) * shake_amount,
			randf_range(-1, 1) * shake_amount
		)
	else:
		offset = default_offset


	# =========================
	# ATTRACT CAMERA MODE
	# =========================
	if attract_mode and attract_target:
		var parent = get_parent()
		if parent:
			var local_target = parent.to_local(attract_target.global_position)

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

		rotation = lerp_angle(rotation, 0, 8 * delta)

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
func shake(time: float, amount: float):
	shake_amount = amount
	await get_tree().create_timer(time).timeout
	shake_amount = 0
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
