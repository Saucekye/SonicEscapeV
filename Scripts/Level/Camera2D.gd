extends Camera2D

# SHAKE
var shake_amount: float = 0.0
var default_offset: Vector2 = Vector2.ZERO
# Looking up and down, like the classic games
@export var look_up_after := 4.0      ## seconds holding up
@export var look_up_distance := 110.0 ## how far it pans
@export var look_up_speed := 4.0      ## how quickly it pans there and back
var _look_held := 0.0
var _look_way := 0                    # -1 = up, 1 = down, 0 = neither
var _look := 0.0                      # how far it's panned right now


# LOOK AHEAD SETTINGS
@export var look_ahead_distance: float = 0.9
@export var look_ahead_smoothness: float = 1.0
@export var velocity_threshold: float = 300.0


# ATTRACT CAMERA SETTINGS
@export var attract_speed: float = 3.0

var velocity: Vector2 = Vector2.ZERO
var attract_mode := false
var attract_target: Node2D = null


# PIXEL-PERFECT ZOOM # Size of one sprite pixel in world units
@export var art_pixel_world_size: float = 1.125
## Base zoom
@export var reference_zoom: float = 1.5

var _applied_zoom_key := ""


func _ready() -> void:
	# The copy made by the Camera2d autoload stays off
	enabled = Test.level % 4 != 0 and get_parent() != get_tree().root
	_apply_pixel_zoom()
	GlobalSignals.connect("camerashake", _on_camerashake)
	default_offset = offset


func _screen_stretch() -> float:
	# How much the 1600x720 game canvas is scaled up to fit the window/screen
	var w := get_window()
	if w == null or w.content_scale_size.x <= 0 or w.content_scale_size.y <= 0:
		return 1.0
	var sx := float(w.size.x) / w.content_scale_size.x
	var sy := float(w.size.y) / w.content_scale_size.y
	return max(0.01, min(sx, sy) * w.content_scale_factor)


func _apply_pixel_zoom() -> void:
	# Picks a zoom where every sprite pixel covers a whole number of screen pixels
	var stretch := _screen_stretch()
	var key := "%s|%s" % [stretch, Test.zoom_level]
	if key == _applied_zoom_key:
		return
	_applied_zoom_key = key
	var wide_px: float = max(1.0, round(art_pixel_world_size * reference_zoom * stretch))
	var px := wide_px               # Close
	match Test.zoom_level:
		0: px = max(1.0, wide_px - 1.0)   # Wide: pulled further back
		2: px = wide_px + 1.0             # Closest
	var z := px / (art_pixel_world_size * stretch)
	zoom = Vector2(z, z)


func _process(delta: float) -> void:
	_apply_pixel_zoom()  # Cheap; only does work when the window size or zoom setting changes

	# LOOK UP / DOWN
	var who := get_parent() as Player
	var way := 0
	if who != null and who.is_player and who.is_on_floor() and who.direction == 0 and absf(who.motion.x) < 1.0 \
			and not who.inp_pressed("ui_accept") and not who.is_spinningdash and int(who.get("spin_charge")) == 0:
		if who.inp_pressed("ui_up") and not who.inp_pressed("ui_down"):
			way = -1
		elif who.inp_pressed("ui_down") and not who.inp_pressed("ui_up"):
			way = 1
	if way != _look_way:
		_look_way = way
		_look_held = 0.0
	_look_held = _look_held + delta if way != 0 else 0.0
	var want := look_up_distance * way if _look_held >= look_up_after else 0.0
	_look = move_toward(_look, want, look_up_distance * look_up_speed * delta)
	var look_offset := Vector2(0, _look)

	# CAMERA SHAKE
	if _kick_left > 0.0:
		_kick_left -= delta
		if _kick_left <= 0.0:
			shake_amount = 0.0
	if shake_amount > 0.0:
		var amount: float = shake_amount * (Test.display.screen_shake if Test.display else 1.0)   # Settings: Screen Shake
		offset = default_offset + look_offset + Vector2(
			randf_range(-amount, amount),
			randf_range(-amount, amount)
		)
	else:
		offset = default_offset + look_offset


	# ATTRACT CAMERA MODE
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


	# NORMAL PLAYER FOLLOW
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


# A quick little shake
var _kick_left := 0.0
func kick(amount: float, time: float) -> void:
	if shake_amount > amount and _kick_left <= 0.0:
		return
	shake_amount = maxf(shake_amount, amount)
	_kick_left = maxf(_kick_left, time)


# SHAKE FUNCTION
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

# ENTER ATTRACT CAMERA
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("AttractCam"):
		attract_mode = true
		attract_target = body


# EXIT ATTRACT CAMERA
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == attract_target:
		attract_mode = false
		attract_target = null
