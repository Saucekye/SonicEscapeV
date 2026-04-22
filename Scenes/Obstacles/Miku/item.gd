extends CharacterBody2D

# Physics variables
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var bounce_factor = 0.0
var wall_bounce_factor = 0.8

var friction = 0.99
var min_bounce_velocity = 50

# Speed control
var speed_multiplier = 1.8

# State
var is_being_held = false
var has_touched_surface = false

# Spin
var is_spinning = false
var spin_speed = 0.0
var max_spin_speed = 35.0
var spin_decay_ground = 0.95

# Idle
var idle_timer = 0.0
var is_in_idle_state = false
var idle_variant := ""

# Upright
var upright_speed = 12.0
var upright_threshold = 0.1

# --------------------------------------------------

func _ready():
	$Arrow.visible = false
	$Attackbox.monitorable = false
	$Attackbox.monitoring = false

# --------------------------------------------------
# GROUP CONTROL (ITEM ONLY WHEN THROWN)
# --------------------------------------------------

func set_item_group(active: bool) -> void:

	if active:
		if not is_in_group("item"):
			add_to_group("item")
	else:
		if is_in_group("item"):
			remove_from_group("item")

# --------------------------------------------------

func _physics_process(delta):

	if is_being_held:
		$AnimationPlayer.play("ride")
		$Arrow.visible = false

		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""
		return

	# --------------------------------------------------
	# SPINNING (ITEM MODE ON)
	# --------------------------------------------------
	if is_spinning:

		set_item_group(true)

		rotation += spin_speed * delta * 1.5

		$Attackbox.monitorable = true
		$Attackbox.monitoring = true

		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""

		if has_touched_surface and (is_on_floor() or is_on_wall()):
			spin_speed *= spin_decay_ground

			if abs(spin_speed) < 0.5:
				is_spinning = false
				spin_speed = 0
				set_item_group(false)

	# --------------------------------------------------
	# AUTO-UPRIGHT
	# --------------------------------------------------
	if is_on_floor() and not is_spinning and has_touched_surface:
		if velocity.length() < upright_threshold * 100:
			var target_rot = 0.0
			var diff = fposmod(target_rot - rotation + PI, TAU) - PI
			rotation += diff * upright_speed * delta

			if abs(diff) < 0.1:
				rotation = 0

		$Attackbox.monitorable = false
		$Attackbox.monitoring = false

	# --------------------------------------------------
	# GRAVITY
	# --------------------------------------------------
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if not has_touched_surface:
			has_touched_surface = true

		velocity.x = move_toward(
			velocity.x,
			0,
			abs(velocity.x) * (1.0 - friction) * delta * 120.0
		)

		if velocity.y > min_bounce_velocity:
			velocity.y = -velocity.y * bounce_factor
		else:
			velocity.y = 0

	# --------------------------------------------------
	# WALL BOUNCE
	# --------------------------------------------------
	if is_on_wall():
		if not has_touched_surface:
			has_touched_surface = true

		velocity.x = -velocity.x * wall_bounce_factor

	# --------------------------------------------------
	# MOVE
	# --------------------------------------------------
	move_and_slide()

	# --------------------------------------------------
	# STOP CONDITION
	# --------------------------------------------------
	if is_on_floor() and has_touched_surface and abs(velocity.x) < 10 and abs(velocity.y) < 10:
		velocity = Vector2.ZERO
		is_spinning = false
		spin_speed = 0
		set_item_group(false)

	# --------------------------------------------------
	# IDLE SYSTEM
	# --------------------------------------------------
	var should_be_idle = (
		velocity == Vector2.ZERO and
		is_on_floor() and
		not is_spinning and
		has_touched_surface and
		abs(rotation) < 0.1
	)

	if should_be_idle:
		if not is_in_idle_state:
			$AnimationPlayer.play("idle")
			is_in_idle_state = true
			idle_timer = 0.0
		else:
			idle_timer += delta

			if idle_timer >= 4.0 and idle_variant == "":
				idle_variant = ["wave", "listen"].pick_random()
				$AnimationPlayer.play(idle_variant)
	else:
		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""

# --------------------------------------------------
# THROW (BECOMES ITEM HERE)
# --------------------------------------------------

func start_spinning(throw_direction: Vector2):

	is_spinning = true
	has_touched_surface = false

	set_item_group(true) # 🔥 ITEM MODE ON

	var spin_x = throw_direction.x
	if abs(spin_x) < 0.05:
		spin_x = 0.25

	var spin_direction = sign(spin_x)

	spin_speed = max_spin_speed * spin_direction * speed_multiplier

	var angle_factor = abs(throw_direction.y)

	spin_speed *= (1.0 + angle_factor)

	velocity = throw_direction * 900 * speed_multiplier

# --------------------------------------------------
# PICKUP
# --------------------------------------------------

func disable_physics():

	is_being_held = true
	velocity = Vector2.ZERO
	is_spinning = false
	spin_speed = 0
	rotation = 0
	has_touched_surface = false

	set_item_group(false)

	Test.meter += 25

# --------------------------------------------------
# DROP
# --------------------------------------------------

func enable_physics():

	is_being_held = false
	has_touched_surface = false
	velocity = Vector2.ZERO
	is_spinning = false
	spin_speed = 0

	set_item_group(false)

	if Test.maxmeter > 100:
		Test.maxmeter = 100

# --------------------------------------------------
# UI
# --------------------------------------------------

func _on_area_2d_area_entered(area):
	if area.is_in_group("Player"):
		$Arrow.visible = true

func _on_area_2d_area_exited(area):
	if area.is_in_group("Player"):
		$Arrow.visible = false
