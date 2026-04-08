extends CharacterBody2D

const MAX_SPEED = 1000.0
const TURN_SPEED = 6.0  # Controls how fast Tails turns
const FLY_ACCELERATION = 600.0

# Start flying to the right
func _ready() -> void:
	velocity = Vector2.RIGHT * MAX_SPEED

func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO

	# Get input
	if Input.is_action_pressed("ui_right"):
		input_vector.x += 1
	if Input.is_action_pressed("ui_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_down"):
		input_vector.y += 1
	if Input.is_action_pressed("ui_up"):
		input_vector.y -= 1

	# If the player is pressing a direction, steer toward it
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		var target_velocity = input_vector * MAX_SPEED
		velocity = velocity.move_toward(target_velocity, FLY_ACCELERATION * delta)

	# Smoothly rotate to face the current velocity
	if velocity.length() > 1:
		var target_angle = velocity.angle()
		rotation = lerp_angle(rotation, target_angle, TURN_SPEED * delta)

	# Move the Tornado
	move_and_slide()
