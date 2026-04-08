extends CharacterBody2D

# Physics variables
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var bounce_factor = 0.0
var wall_bounce_factor = 0.8
var friction = 0.95
var min_bounce_velocity = 50
var can_stomp = false
var bounce = 0
# State
var is_being_held = false
var ground_friction_enabled = true
var has_touched_surface = false

# Spin
var is_spinning = false
var spin_speed = 0.0
var max_spin_speed = 35.0
var spin_decay_ground = 0.95

# Idle / Wave / Listen
var idle_timer = 0.0
var is_in_idle_state = false
var idle_variant := ""   # <--- ADDED

# Upright
var upright_speed = 12.0
var upright_threshold = 0.1


func _ready():
	$Arrow.visible = false
	$Attackbox.monitorable = false
	$Attackbox.monitoring = false

func _physics_process(delta):
	if is_being_held:
		$AnimationPlayer.play("ride")
		$Arrow.visible = false
		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""   # reset
		return

	# -----------------
	# SPINNING
	# -----------------
	if is_spinning:
		rotation += spin_speed * delta
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


	# -----------------
	# AUTO-UPRIGHT
	# -----------------
	if is_on_floor() and not is_spinning and has_touched_surface:
		if velocity.length() < upright_threshold * 100:
			var target_rot = 0.0
			var diff = fposmod(target_rot - rotation + PI, TAU) - PI
			rotation += diff * upright_speed * delta
			if abs(diff) < 0.1:
				rotation = 0

		$Attackbox.monitorable = false
		$Attackbox.monitoring = false


	# -----------------
	# GRAVITY & FRICTION
	# -----------------
	if not is_on_floor():
		velocity.y += gravity * delta
		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""
	else:
		if not has_touched_surface:
			has_touched_surface = true

		velocity.x = move_toward(
			velocity.x,
			0,
			abs(velocity.x) * (1.0 - friction) * delta * 60.0
		)

		if velocity.y > min_bounce_velocity:
			velocity.y = -velocity.y * bounce_factor
		else:
			velocity.y = 0


	# -----------------
	# WALL BOUNCE
	# -----------------
	if is_on_wall():
		if not has_touched_surface:
			has_touched_surface = true
		velocity.x = -velocity.x * wall_bounce_factor


	# -----------------
	# MOVE
	# -----------------
	move_and_slide()


	# -----------------
	# STOP WHEN VERY SLOW
	# -----------------
	if is_on_floor() and has_touched_surface and abs(velocity.x) < 10 and abs(velocity.y) < 10:
		velocity = Vector2.ZERO
		is_spinning = false
		spin_speed = 0


	# -----------------
	# IDLE / WAVE / LISTEN
	# -----------------
	var should_be_idle = (
		velocity == Vector2.ZERO and
		is_on_floor() and
		not is_spinning and
		has_touched_surface and
		abs(rotation) < 0.1
	)

	if should_be_idle:
		if not is_in_idle_state:
			# Enter idle
			$AnimationPlayer.play("idle")
			is_in_idle_state = true
			idle_timer = 0.0
		else:
			# Stay idle
			idle_timer += delta

			if idle_timer >= 4.0 and idle_variant == "":
				idle_variant = ["wave", "listen"].pick_random()
				$AnimationPlayer.play(idle_variant)
	else:
		# Exit idle
		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""


func _on_area_2d_area_entered(area):
	if area.is_in_group("Player"):
		$Arrow.visible = true


func _on_area_2d_area_exited(area):
	if area.is_in_group("Player"):
		$Arrow.visible = false


# -----------------------------
# PICKUP / DROP / THROW API
# -----------------------------
func disable_physics():
	is_being_held = true
	velocity = Vector2.ZERO
	is_spinning = false
	spin_speed = 0
	rotation = 0
	has_touched_surface = false
	idle_timer = 0.0
	is_in_idle_state = false
	idle_variant = ""

	# Add 25 meter when picked up
	Test.meter += 25


func enable_physics():
	is_being_held = false
	has_touched_surface = false
	velocity = Vector2.ZERO
	is_spinning = false
	spin_speed = 0
	idle_timer = 0.0
	is_in_idle_state = false
	idle_variant = ""

	# Reset meter back to 100 when dropped
	if Test.maxmeter > 100:
		Test.maxmeter = 100


func start_spinning(throw_direction: Vector2):
	is_spinning = true
	has_touched_surface = false

	var spin_x = throw_direction.x
	if abs(spin_x) < 0.05:
		spin_x = 0.25   # vertical throws fix

	var spin_direction = sign(spin_x)
	spin_speed = max_spin_speed * spin_direction

	var angle_factor = abs(throw_direction.y)
	spin_speed *= (1.0 + angle_factor)
