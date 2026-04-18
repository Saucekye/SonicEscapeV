extends CharacterBody2D

# ─────────────────────────────────────────────
# Node References
# ─────────────────────────────────────────────
@onready var ap = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var timer = $Timer          # Resets max_speed after leaving a wall
@onready var trail = $Trail2D
@onready var sfx = $Sfx
@onready var voice = $Voice

@export var is_player := true        # False = AI follower controlled by player_path

# Stored before entering loops; restored on exit to preserve correct collision behaviour
@export var stored_layer: int
@export var stored_mask: int
var in_loop = false

#health  # TODO: health system not yet implemented

# ─────────────────────────────────────────────
# Signals (trick rating broadcast)
# ─────────────────────────────────────────────
signal good
signal great
signal awesome
signal outstanding
signal amazing

# ─────────────────────────────────────────────
# State Variables
# ─────────────────────────────────────────────
var hang = false        # True while hanging from a flying player
var hangable = false    # Whether a hang can be initiated right now
var flying = false      # True while the fly/hover ability is active
var flymeter = 85       # Remaining fly energy (drains per flutter, resets on ground/rail)
var swipe = false       # True during the swipe attack animation window

var is_jumping = false
var jump_pressed = false
var wait = false
var max_speed = 400             # Lower default than Sonic — this character is slower on the ground
const SPEED = 10.0              # Unused legacy constant
const JUMP_VELOCITY = -500.0    # Unused legacy constant
var acc = 15
const fric = 60
const DASHSPEED = 10000         # Unused legacy constant
var can_dash = true
var dashx = false               # Delays friction re-application after a dash
var dashed = false              # True while a special air action is in progress
var crouch = false
var spin = 0                    # Unused
var ball = false                # True in spin-ball mode
var falling = false
var time_elapsed = 0            # Momentum accumulator (typo preserved from original)
var saveddir = 0                # Unused
var last_trick = ""             # Tracks last trick for sequential cycling
var can_stomp = true
var bounce = 0                  # Consecutive stomp counter (affects bounce height)
var next_bounce = false         # Queues a bounce on next floor contact

var motion := Vector2(0,0)
var rot := 0.0
var slopeangle := 0.0
var slopefactor := 0.0
var grounded := false
var falloffwall = false         # Unused
var control_lock = false
var stuck = false               # Unused
var canjump = false             # Legacy; replaced by is_coyote_time_active()
var ouch = false
var invincible = false

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# ─────────────────────────────────────────────
# Jump Arc — formula-driven, tunable in Inspector
# ─────────────────────────────────────────────
@export var jump_height : float = 260
@export var jump_time_to_peak : float = 0.5
@export var jump_time_to_descent : float = 0.45

var default = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0  # Baseline fall gravity for restoring after special moves
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

# ─────────────────────────────────────────────
# Attachment / Carry System
# ─────────────────────────────────────────────
var attached_to_entity: Node2D = null
var entity_attachment_offset: Vector2 = Vector2.ZERO

var held_item: Node2D = null
var item_hold_offset: Vector2 = Vector2(0, -30)

# ─────────────────────────────────────────────
# Direction & Wall Jump
# ─────────────────────────────────────────────
var reverse_to_right = false    # Unused
var reverse_to_left = true      # Unused
var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
var direction = 0
var just_wall_jumped = false
var has_jumped = false

# ─────────────────────────────────────────────
# Preloaded Scenes
# ─────────────────────────────────────────────
var smoke = preload("res://Scenes/Effect/Smoke Attack.tscn")
var sparkle = preload("res://Scenes/Effect/Sparkle.tscn")
var smokeground = preload("res://misc/runsmoke.tscn")
var ring_scene = preload("res://Scenes/Obstacles/Rings/Rings.tscn")

# ─────────────────────────────────────────────
# Spin Dash
# ─────────────────────────────────────────────
var spin_charge = 0
var spin_dash_speed = 0
var is_spinning = false
var max_spin_charge = 20        # Unused cap
var spin_dash_acceleration = 600

# ─────────────────────────────────────────────
# Coyote Time
# ─────────────────────────────────────────────
var coyote_time := 0.25
var last_grounded_time := 0.0
var was_on_floor := false
var prev_grounded = false
var grinding = false

var stickdir = Vector2(0,0)         # Virtual joystick input (mobile)
@export var player_path: NodePath   # Path to the player node this AI should follow
var player: CharacterBody2D


func _ready():
	$Trail2D.visible = false
	timer.wait_time = 12
	$Sprite2D.visible = true
	$Sprite2D2.visible = false

func _process(delta):
	$Flymeter.value = flymeter  # Sync the fly meter UI bar every frame
	if Test.mobile == true:
		handle_stick_input()

func handle_stick_input():
	# Convert virtual joystick Y into ui_up / ui_down action events each frame
	if stickdir.y < 0:
		var ev = InputEventAction.new()
		ev.action = "ui_up"
		ev.pressed = true
		Input.parse_input_event(ev)
	elif stickdir.y > 0.5:
		var ev = InputEventAction.new()
		ev.action = "ui_down"
		ev.pressed = true
		Input.parse_input_event(ev)
	else:
		# Release both when stick is neutral
		var ev = InputEventAction.new()
		ev.action = "ui_down"
		ev.pressed = false
		Input.parse_input_event(ev)
		ev = InputEventAction.new()
		ev.action = "ui_up"
		ev.pressed = false
		Input.parse_input_event(ev)

func _on_launch_finished():
	# TODO: restore full player control after a path-launch ends
	print("Spring path finished! Movement restored.")

func _physics_process(delta):
	# ── Floor State Tracking ───────────────────────────────────────────
	var is_grounded = is_on_floor()
	if is_grounded:
		last_grounded_time = Time.get_ticks_msec() / 1000.0  # Stamp for coyote time
	was_on_floor = is_grounded

	if is_grounded and not prev_grounded:
		# Just landed — reset flying state and hide the fly arrow indicator
		$Arrow.visible = false
		flying = false
		fall_gravity = default
		has_jumped = false

	prev_grounded = is_grounded

	if Test.meter > Test.maxmeter:
		Test.meter = Test.maxmeter

	# Passively recharge meter only when solidly on the ground (not on a wall)
	if is_on_floor_only():
		Test.meter += 1 * delta

	# ── Slope Calculation ──────────────────────────────────────────────
	if is_on_floor():
		if is_player == true:
			tricknumber()
			GlobalCanvasLayer.tricks = 0
		slopeangle = get_floor_normal().angle() + (PI/2)
		slopefactor = get_floor_normal().x
	else:
		slopefactor = 0

	# ── Rotation & Sprite Alignment ────────────────────────────────────
	$CollisionShape2D.rotation = rot
	$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, rot, 0.25)

	if is_on_floor():
		# Momentum conversion on landing (vertical speed → horizontal on slopes)
		if not grounded:
			if abs(slopeangle) >= 0.5 and abs(motion.y) > abs(motion.x):
				var downhill_direction = -sign(slopefactor)
				if sign(motion.x) == downhill_direction or motion.x == 0:
					motion.x += motion.y * slopefactor
			grounded = true
		rot = slopeangle
	else:
		# Momentum conversion when leaving the floor — capture real velocity for air carry
		if (not $CollisionShape2D/Raycast.is_colliding() and grounded):
			grounded = false
			motion = get_real_velocity()
			rot = 0
			up_direction = Vector2(0, -1)

	# ── Bounce Logic ───────────────────────────────────────────────────
	if is_on_floor():
		if falling == false and next_bounce == false:
			bounce = 0

		if Input.is_action_pressed("airspin"):
			# Holding airspin cancels the pending bounce
			next_bounce = false
			can_stomp = true

		# This character has a single fixed bounce height (unlike Sonic's tiered system)
		# slopefactor < 0.3 prevents bouncing on steep slopes
		if next_bounce == true and falling == true and slopefactor < 0.3:
			motion.y = -750
			can_stomp = true

	# ── Dynamic Speed / Acceleration ───────────────────────────────────
	var slope_influence = abs(slopefactor)
	var slope_acceleration = sign(-slopefactor * direction)

	if abs(motion.x) > 1250:
		max_speed = abs(motion.x)
		acc = 5 + 10 * slope_influence
	else:
		if time_elapsed > 50:
			if max_speed == 500 && is_on_floor():
				# Crossed the momentum threshold — play break-speed effects
				$Trail2D.visible = true
				$Sfx.pitch_scale = 2
				$Sfx.stream = load("res://Sounds/SonicSFX/Break Speed.wav")
				$Sfx.play()
				smokeemit()

			if abs(slopefactor) > 0:
				if slope_acceleration > 0:
					max_speed = 1000
					acc = 5 + 10 * slope_influence
				else:
					if ball == true:
						max_speed = 1800
						acc = 5 + 10 * slope_influence
					else:
						max_speed = 1200
						acc = 5 + 10 * slope_influence
			else:
				if max_speed <= 900:
					max_speed = 900
					acc = 5
		else:
			max_speed = 500
			acc = 25

	# ── AI Follow Logic ────────────────────────────────────────────────
	# Only runs when not flying — flying state is handled by the player directly
	if is_player == false and flying == false:
		player = get_node(player_path) as CharacterBody2D

		if in_loop:
			pass  # Keep current heading inside a loop
		elif player and ((not is_on_floor() and ball == true) or ball == false):
			var to_player = player.global_position - global_position
			var actual_distance = to_player.length()
			var stop_range = 40           # Tighter stop range than Sonic's AI (40 vs 60)
			var max_possible_speed = 2000
			var speed_ramp_distance = 200
			var speed_change_rate = 10500

			if actual_distance > stop_range:
				direction = sign(to_player.x)
				var distance_factor = clamp((actual_distance - stop_range) / speed_ramp_distance, 0.0, 1.0)
				var target_speed = max_possible_speed * distance_factor
				max_speed = move_toward(max_speed, target_speed, speed_change_rate * delta)
			else:
				direction = 0
				max_speed = move_toward(max_speed, 0, speed_change_rate * delta)
	else:
		# ── Player Input ───────────────────────────────────────────────
		if ((not is_on_floor() and ball == true) or ball == false):
			if abs(stickdir.x) > 0.5 and Test.mobile == true:
				direction = stickdir.x
				if spin_charge == 0:
					control_lock = false
				direction = sign(direction)
			else:
				if abs(Input.get_joy_axis(0,0)) > 0.5:
					direction = Input.get_axis("ui_left", "ui_right") + Input.get_joy_axis(0,0)
					if spin_charge == 0:
						control_lock = false
					direction = sign(direction)
				else:
					direction = Input.get_axis("ui_left", "ui_right")
					if direction > 0 or direction < 0:
						if spin_charge == 0:
							control_lock = false

	handle_movement_input(delta)

	# ── Apply Velocity ─────────────────────────────────────────────────
	if abs(time_elapsed) > 60 or abs(motion.x) > 500:
		up_direction = get_floor_normal()
		velocity = Vector2(motion.x, motion.y).rotated(rot)
	else:
		up_direction = Vector2(0,-1)
		velocity = Vector2(motion.x, motion.y)

	# ── Ceiling Bounce ─────────────────────────────────────────────────
	if is_on_ceiling() and not grounded:
		if motion.y < 0:
			motion.y = 100

	# ── Wall Stop ──────────────────────────────────────────────────────
	if is_on_wall() and ($CollisionShape2D/WallCast.is_colliding() or $CollisionShape2D/WallCast2.is_colliding()):
		time_elapsed = 0
		motion.x = 0
		rot = 0

	if abs(motion.x) == 0 and abs(slopeangle) >= 1:
		rot = 0
		time_elapsed = 0

	if direction != 0:
		switch_direction(direction)
		if direction > 0:
			reverse_to_left = true

	# Start the wall-leave timer when the character exits a wall
	var was_on_wall = is_on_wall()
	var just_left_wall = was_on_wall and not is_on_wall() and motion.x >= 0.0
	if just_left_wall:
		timer.start()

	# ── Gravity ────────────────────────────────────────────────────────
	if (not is_on_floor() and rot == 0):
		motion.y += get_gravityy() * delta
	else:
		if abs(slopefactor) == 1:
			motion.y = 0  # Prevent drift on vertical walls
		else:
			motion.y = 50  # Small constant to keep character pressed to floor

	if is_spinning:
		direction = 0  # Lock direction during spindash charge

	# ── Per-Frame Sub-Systems ──────────────────────────────────────────
	handle_floor_logic(delta)
	handle_air_logic(delta, is_grounded)
	handle_jump_input(is_grounded)
	handle_wall_mechanics()
	update_animations()
	handle_hitbox()
	handle_item(delta)
	handle_attachment(delta)

	if not hang:
		move_and_slide()
		just_wall_jumped = false

	update_attachment_position()
	update_held_item_position()

func update_attachment_position():
	if hang and attached_to_entity and is_instance_valid(attached_to_entity):
		if follow_target and is_instance_valid(follow_target):
			global_position = follow_target.global_position
		else:
			global_position = attached_to_entity.global_position + entity_attachment_offset
		velocity = Vector2.ZERO
		motion = Vector2.ZERO

var attached_player = null
var hang_transform = null
var hang_cooldown = 0.0
var item_pickup_cooldown = 0.0
var follow_target: Node2D = null

func handle_attachment(delta):
	if hang_cooldown > 0:
		hang_cooldown -= delta

	var flying_player = find_flying_player_nearby()

	if not hang and hangable and hang_cooldown <= 0:
		if flying_player and flying_player.get("flying") and not is_on_floor():
			attach_to_flying_player(flying_player)
			return

	if hang and attached_to_entity:
		var should_detach = false
		var detach_reason = ""

		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 50))
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		var near_ground = result != null and result.has("position")

		if near_ground:
			should_detach = true
			detach_reason = "near ground"
		elif not is_instance_valid(attached_to_entity):
			should_detach = true
			detach_reason = "player invalid"
		elif not attached_to_entity.get("flying"):
			should_detach = true
			detach_reason = "player stopped flying"
		elif Input.is_action_just_pressed("airspin") or Input.is_action_just_pressed("trick"):
			should_detach = true
			detach_reason = "player input"

		if should_detach:
			print("DETACHING: ", detach_reason)
			detach_from_flying_player()

func handle_item(delta):
	if item_pickup_cooldown > 0:
		item_pickup_cooldown -= delta

	if held_item and Input.is_action_just_pressed("trick"):
		drop_item()
		return

	if not held_item and Input.is_action_pressed("ui_up") and item_pickup_cooldown <= 0:
		var item = find_item_nearby()
		if item and not hang:
			pick_up_item(item)

func update_held_item_position():
	if held_item and is_instance_valid(held_item):
		var offset = item_hold_offset
		if sprite.flip_h:
			offset.x = -abs(offset.x)
		else:
			offset.x = abs(offset.x)

		held_item.global_position = global_position + offset

		if held_item.has_node("Sprite2D"):
			var item_sprite = held_item.get_node("Sprite2D")
			item_sprite.rotation = sprite.rotation
			item_sprite.flip_h = sprite.flip_h

		if held_item.has_method("set") and held_item.get("velocity") != null:
			held_item.velocity = Vector2.ZERO
		if held_item.has_method("set") and held_item.get("motion") != null:
			held_item.motion = Vector2.ZERO

		held_item.rotation = 0

func attach_to_flying_player(flying_player):
	print("ATTACHING to flying player")
	hang = true
	hangable = true
	attached_to_entity = flying_player
	z_index = -1
	motion = Vector2.ZERO
	time_elapsed = 0
	velocity = Vector2.ZERO
	control_lock = true

	if flying_player.has_node("Marker2D"):
		follow_target = flying_player.get_node("Marker2D")
		entity_attachment_offset = global_position - follow_target.global_position
	else:
		follow_target = flying_player
		entity_attachment_offset = global_position - flying_player.global_position

	if ap.has_animation("hang"):
		ap.play("hang")

func detach_from_flying_player():
	if not hang:
		return
	print("DETACHING from player")
	hang = false
	z_index = 1
	control_lock = false
	attached_to_entity = null
	follow_target = null
	entity_attachment_offset = Vector2.ZERO
	motion.y = -500
	grounded = false
	has_jumped = true
	is_jumping = true
	floor_snap_length = 0
	can_dash = true
	hang_cooldown = 0.5
	hangable = false
	await get_tree().process_frame

func pick_up_item(item: Node2D):
	print("PICKING UP ITEM")
	held_item = item
	if item.has_method("disable_physics"):
		item.disable_physics()
	else:
		if item.has_method("set_physics_process"):
			item.set_physics_process(false)
		if item.has_node("CollisionShape2D"):
			item.get_node("CollisionShape2D").set_deferred("disabled", true)
		if item.has_method("set_collision_layer"):
			item.set_collision_layer(0)
		if item.has_method("set_collision_mask"):
			item.set_collision_mask(0)

func throw_item():
	if not held_item or not is_instance_valid(held_item):
		return

	print("THROW BUTTON PRESSED")

	# ── 1. Determine throw direction ───────────────────────────────────
	var throw_direction := Vector2.ZERO
	var has_input := false

	if Test.mobile == true and stickdir != Vector2.ZERO:
		throw_direction = stickdir.normalized()
		has_input = true
	elif abs(Input.get_joy_axis(0, 0)) > 0.5 or abs(Input.get_joy_axis(0, 1)) > 0.5:
		throw_direction = Vector2(Input.get_joy_axis(0, 0), Input.get_joy_axis(0, 1)).normalized()
		has_input = true
	else:
		throw_direction = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_down", "ui_up"))
		if throw_direction != Vector2.ZERO:
			throw_direction = throw_direction.normalized()
			has_input = true

	if not has_input:
		return

	if throw_direction == Vector2.ZERO:
		return

	# ── 2. Ensure spin direction has a horizontal component ────────────
	var spin_dir = throw_direction
	if abs(spin_dir.x) < 0.05:
		spin_dir.x = 0.25
	spin_dir = spin_dir.normalized()

	# ── 3. Re-enable item physics ──────────────────────────────────────
	if held_item.has_method("enable_physics"):
		held_item.enable_physics()
	else:
		if held_item.has_node("CollisionShape2D"):
			held_item.get_node("CollisionShape2D").set_deferred("disabled", false)
		if held_item.has_method("set_physics_process"):
			held_item.set_physics_process(true)
		if held_item.has_method("set_collision_layer"):
			held_item.set_collision_layer(5)
		if held_item.has_method("set_collision_mask"):
			held_item.set_collision_mask(5)

	# ── 4. Apply throw force ───────────────────────────────────────────
	var throw_power = 400 + abs(velocity.x)
	if abs(throw_direction.x) > 0:
		throw_power = throw_power * 1.5
	if not is_on_floor():
		motion.y += jump_velocity/1.5

	held_item.velocity = Vector2.ZERO
	throw_direction.y = -throw_direction.y  # Flip Y so "up" input = upward throw
	held_item.velocity = throw_direction * throw_power

	# ── 5. Spinning visual ─────────────────────────────────────────────
	if held_item.has_method("start_spinning"):
		held_item.start_spinning(spin_dir)

	# ── 6. Sound and cooldown ─────────────────────────────────────────
	if sfx:
		sfx.pitch_scale = 1.2
		sfx.stream = load("res://Sounds/SonicSFX/SA_113.wav")
		sfx.play()

	item_pickup_cooldown = 0.5
	held_item = null

func drop_item():
	throw_item()

func find_flying_player_nearby():
	var areas = $Hitbox.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("Player") and Input.is_action_pressed("ui_up"):
			var player_node = area.get_parent()
			if player_node != self and player_node.has_method("get") and player_node.get("flying"):
				return player_node
	return null

func find_item_nearby():
	var areas = $Hitbox.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("item"):
			return area.get_parent()
	return null

func tricknumber():
	if GlobalCanvasLayer.tricks > 5:
		Test.trick = "good"
	if GlobalCanvasLayer.tricks > 10:
		Test.trick = "great"
	if GlobalCanvasLayer.tricks > 15:
		Test.trick = "awesome"
	if GlobalCanvasLayer.tricks > 20:
		Test.trick = "outstanding"
	if GlobalCanvasLayer.tricks > 30:
		Test.trick = "amazing"

func handle_movement_input(delta):
	if direction and not control_lock:
		if ball == false or !is_on_floor():
			var target_speed = max_speed * direction
			var current_acc = acc

			# High deceleration when reversing direction for a skid feel
			if sign(motion.x) != sign(target_speed) and motion.x != 0:
				current_acc = 2500 * delta

			motion.x = approach(motion.x, target_speed, current_acc)

		if is_on_floor():
			if sign(motion.x) != sign(max_speed * direction) and motion.x != 0 and ball == false:
				motion.x = move_toward(motion.x, 0, fric/3)

			if dashx == true:
				await(get_tree().create_timer(0.01)).timeout
				dashx = false

			# Build momentum over time while running (no boost check — this character doesn't have ground boost)
			if abs(motion.x) > 200 and ball == false:
				var slope_acceleration = sign(-slopefactor * direction)
				if abs(slopefactor) < 0.5 or slope_acceleration < 0:
					time_elapsed += 1.5

			elif ball == true and abs(slopefactor) > 0.1:
				var slope_acceleration = sign(-slopefactor * direction)
				if slope_acceleration > 0:
					time_elapsed += 2

		if (motion.x/direction) < 1:
			time_elapsed = 30

	else:
		apply_friction(delta)

func apply_friction(delta):
	if ball == false:
		if time_elapsed > 50 or not is_on_floor():
			motion.x = move_toward(motion.x, 0, 500 * delta)
			time_elapsed = approach(time_elapsed, 0, 1000 * delta)
		else:
			motion.x = move_toward(motion.x, 0, 5000 * delta)
			time_elapsed = 0
	elif !is_on_floor() and ball == true:
		control_lock = false
		motion.x = move_toward(motion.x, 0, fric/4 * delta)
	else:
		if abs(slopefactor) < 0.1:
			motion.x = move_toward(motion.x, 0, 300 * delta)
			if motion.x == 0:
				time_elapsed = 0
		else:
			var floor_normal = get_floor_normal()
			var slopefactor = floor_normal.x
			var slope_accel = gravity * slopefactor
			if ball == true and slope_accel > 0 and time_elapsed > 60:
				slope_accel *= 2
			if abs(motion.x) < 10:
				motion.x += slope_accel * delta
			elif sign(motion.x) != sign(slope_accel):
				motion.x = move_toward(motion.x, 0, abs(slope_accel) * delta * 1/3)
			else:
				motion.x += slope_accel * delta

func calculate_dynamic_speed():
	# Unused — speed logic is handled inline in _physics_process
	var slope_influence = abs(slopefactor)
	var slope_acceleration = sign(-slopefactor * direction)

	if abs(motion.x) > 1250:
		max_speed = abs(motion.x)
		acc = 5 + 10 * slope_influence
	else:
		if time_elapsed > 50:
			if max_speed == 500 && is_on_floor():
				$Trail2D.visible = true
				$Sfx.pitch_scale = 2
				$Sfx.stream = load("res://Sounds/SonicSFX/Break Speed.wav")
				$Sfx.play()
				smokeemit()

			if abs(slopefactor) > 0:
				if slope_acceleration > 0:
					if ball == true:
						var small_bonus = min(time_elapsed / 50.0, 200)
						max_speed = 1800 + small_bonus
						acc = 5 + 10 * slope_influence
					else:
						max_speed = 1000
						acc = 5 + 10 * slope_influence
				else:
					if ball == true:
						max_speed = 1800
						acc = 5 + 10 * slope_influence
					else:
						max_speed = 1800
						acc = 5 + 10 * slope_influence
			else:
				if time_elapsed > 100:
					max_speed = min(900 + (time_elapsed - 100) * 2, 1800)
					acc = 5 + 10
				else:
					max_speed = 900
					acc = 5
		else:
			max_speed = 500
			acc = 25

func preserve_ball_momentum():
	if ((velocity.x != 0 or velocity.y != 0) and Input.is_action_just_pressed("ui_down")) or ((rot != 0) and Input.is_action_just_pressed("ui_down")) and next_bounce == false:
		crouch = true
		ball = true

func update_momentum_effects():
	if ball == true and time_elapsed > 100 and abs(motion.x) > 1000:
		if not $Trail2D.visible:
			$Trail2D.visible = true

func handle_floor_logic(delta):
	if is_on_floor():
		# Landing resets fly meter and hides the meter bar
		flymeter = 85
		$Flymeter.visible = false

		if time_elapsed <= 50:
			floor_snap_length = 10
		else:
			floor_snap_length = 30

		falling = false
		dashed = false
		can_dash = true
		can_stomp = true

		trail.visible = abs(motion.x) > 400  # Lower threshold than Sonic (400 vs 500)

		if ball == true:
			apply_friction(delta)

		if abs(motion.x) > 0 and ball == false:
			crouch = false
			control_lock = false

		if Input.is_action_pressed("ui_down") and motion.x == 0 and is_spinning == false and next_bounce == false:
			crouch = true
			ap.play("Crouch")

		if Input.is_action_just_released("crouch") or Input.is_action_just_released("ui_up") and motion.x == 0:
			control_lock = false
			crouch = false

		if ((velocity.x != 0 or velocity.y != 0) and Input.is_action_just_pressed("ui_down")) or ((rot != 0) and Input.is_action_just_pressed("ui_down")) and next_bounce == false:
			crouch = true
			ball = true

		if motion.x == 0 and abs(slopefactor) < 0.4:
			crouch = false
			ball = false
			spindash()

		if motion.x == 0:
			peelout()

		# Ground swipe attack — only triggers if not already mid-swipe or mid-dash
		if Input.is_action_just_pressed("airspin") and dashed == false and swipe == false:
			airspin()

	# Exit ball mode on action press
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("trick")) and ball == true and is_on_floor():
		control_lock = false
		ball = false
		crouch = false
		roll()

func reset_dash_after_delay() -> void:
	# Unused coroutine
	await get_tree().create_timer(0.5).timeout
	can_dash = true
	can_stomp = true

func handle_air_logic(delta, is_grounded):
	if not is_on_floor():
		rot = 0
		floor_snap_length = 0
		control_lock = false
		crouch = false

		if next_bounce == true and falling == false:
			next_bounce = false

		# Enter ball from air (pressing down while moving/rotated)
		if ((velocity.x != 0 or velocity.y != 0) and Input.is_action_just_pressed("ui_down")) or ((rot != 0) and Input.is_action_just_pressed("ui_down")) and next_bounce == false:
			crouch = true
			ball = true

		if dashed == false:
			# Play jump animation when freely airborne (not flying, not on wall)
			if (falling == false or (falling == true and not ball)) and ball == false and grinding == false and flying == false and not is_on_wall() and not is_on_floor():
				ap.play("jump")

			if time_elapsed < 50 and ball == false:
				motion.x = clamp(motion.x, -1000, 1000)
				time_elapsed = 0
			elif time_elapsed >= 70:  # Slightly higher threshold than Sonic (70 vs 60)
				if slopefactor == 0:
					motion.x = clamp(motion.x, -1200, 1200)  # Lower air speed cap than Sonic

		handle_air_actions(is_grounded)

func handle_air_actions(is_grounded):
	if grinding == false:
		# ── Fly (hold jump while airborne) ────────────────────────────
		# Two separate conditions: sustained fly while holding, and initial press
		if can_dash == true and flying == true and flymeter >= 1 and Input.is_action_pressed("ui_accept") and (not Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_down")):
			dash(direction)           # dash() here is the fly flutter, not a Sonic-style dash
			$Flymeter.visible = true  # Show meter only while actively flying

		if Input.is_action_just_pressed("ui_accept") and (not Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_down")) and can_dash == true and not is_coyote_time_active():
			dash(direction)
			can_stomp = true
			ap.play("fly")

		# ── Swipe Attack (air) ─────────────────────────────────────────
		# Only triggers when not already swiping
		if Input.is_action_just_pressed("airspin") and not Input.is_action_pressed("ui_down") and dashed == false and swipe == false:
			airspin()

		# ── Stomp ──────────────────────────────────────────────────────
		if Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_down") and can_stomp == true and not is_on_wall():
			airdown()
			can_dash = true
			can_stomp = false

		# ── Trick — blocked during flight ─────────────────────────────
		if Input.is_action_just_pressed("trick") and not (is_on_wall_only() and (not $CollisionShape2D/Raycast.is_colliding()) and rot == 0) and flying == false:
			$Parry/AnimationPlayer.play("play")
			perform_trick()

func handle_jump_input(is_grounded):
	var slope_influence = abs(slopefactor)
	var slope_acceleration = sign(-slopefactor * direction)

	# Variable jump height — cut upward velocity on early release
	if is_jumping and !Input.is_action_pressed("ui_accept") and motion.y < 0:
		motion.y *= 0.8
		is_jumping = false

	if Input.is_action_just_pressed("ui_accept") and (grinding or is_grounded or is_coyote_time_active()) and (ball or (!crouch and !ball)) and not just_wall_jumped and not is_spinning:
		floor_snap_length = 0

		var can_jump_with_down = Input.is_action_pressed("ui_down") and direction != 0

		if !Input.is_action_pressed("ui_down") or can_jump_with_down:
			if slope_acceleration < 0:
				if time_elapsed >= 50:
					rot = 0
					position += Vector2(0, -(5)).rotated(rot)
			elif abs(slopefactor) > 0.1 and time_elapsed < 60:
				motion.x = 0
				position += Vector2(0, -(6)).rotated(rot)

			grinding = false

			if is_coyote_time_active() == true:
				motion.y += jump_velocity * 1.3
			else:
				motion.y += jump_velocity

			has_jumped = true
			is_jumping = true
			jump_pressed = true

			if ball == false and grinding == false:
				ap.play("jump")
				sfx.pitch_scale = 1
				sfx.stream = load("res://Sounds/SonicSFX/Jump.wav")
				sfx.play()

func is_coyote_time_active():
	if has_jumped:
		return false
	var time_since_grounded = Time.get_ticks_msec() / 1000.0 - last_grounded_time
	return time_since_grounded < coyote_time and motion.y >= 0 and not was_on_floor

func handle_wall_mechanics():
	pass  # This character has no wall-slide or wall-jump — intentionally empty

# ─────────────────────────────────────────────
# Animation
# ─────────────────────────────────────────────
func update_animations():
	# Note: no abs() on doturn here — differs from Sonic's version; can produce negative values
	var doturn = abs(((motion.x/max_speed)*2))
	if ouch == false:
		if is_on_floor():
			if ball == true and grinding == false:
				ap.speed_scale = 1
				ap.play("ball")
			if direction == 0 and grinding == false:
				handle_idle_animations()
			else:
				handle_movement_animations(doturn)
		else:
			ap.speed_scale = 1
	else:
		ap.play("hurt")

func handle_idle_animations():
	# swipe flag blocks idle animations during the attack window
	if ball != true and crouch != true and is_spinning == false and wait == false and swipe == false:
		if direction == 0 and abs(motion.x) > 0:
			ap.play("skid")  # Skid even at low speed (abs > 0, vs Sonic's > 500)
		else:
			ap.play("stance")
		ap.speed_scale = 1
		if Input.is_action_pressed("ui_down") and is_spinning == false and next_bounce == false and grinding == false and swipe == false:
			ap.play("Crouch")

func handle_movement_animations(doturn):
	# swipe flag suppresses movement animations during the attack
	if doturn < 1 and doturn > -1 and doturn == abs(doturn) and grinding == false and swipe == false:
		ap.speed_scale = 0.75
		if ball != true and (time_elapsed < 10):
			ap.play("turn")
	else:
		ap.speed_scale = doturn  # No *1.1 multiplier here (unlike Sonic)
		if ball != true and grinding == false and swipe == false:
			ap.play("Dash max" if abs(motion.x) > 1100 else "Dash" if time_elapsed > 50 or abs(motion.x) > 500 else "run")
			if abs(motion.x) > 400:
				runsmoke()

func runsmoke():
	var runsmoke = smokeground.instantiate()
	runsmoke.position = position
	get_parent().add_child(runsmoke)
	runsmoke.rotation_degrees = rot
	runsmoke.flip_h = velocity.x < 0
	await get_tree().create_timer(0.13).timeout

func smokeemit():
	var instantsmoke = smoke.instantiate()
	instantsmoke.position = position
	if velocity.y < 0:
		instantsmoke.rotation_degrees = 270
	instantsmoke.flip_h = velocity.x < 0
	get_parent().add_child(instantsmoke)

func sparkemit():
	var instantsmoke = sparkle.instantiate()
	instantsmoke.position = position
	get_parent().add_child(instantsmoke)

# ─────────────────────────────────────────────
# Movement Utilities
# ─────────────────────────────────────────────
func approach(current, target, speed):
	if current < target:
		return min(current + speed, target)
	elif current > target:
		return max(current - speed, target)
	return current

func get_gravityy() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity

func roll():
	if motion.x == 0 and next_bounce == false:
		ball = false
	else:
		ball = crouch == true

func switch_direction(direction):
	ap.speed_scale *= -1
	sprite.flip_h = direction == -1

# ─────────────────────────────────────────────
# Special Moves
# ─────────────────────────────────────────────
func dash(direction):
	# For this character, "dash" is actually the fly flutter —
	# each call flaps once, drains flymeter by 1, and applies a gentle upward push.
	# It's called repeatedly each frame while ui_accept is held.
	falling = true
	ball = false
	crouch = false
	flying = true
	flymeter -= 1              # Drain one unit of fly energy per flutter call
	ap.play("fly")
	motion.y = -450            # Small upward push per flutter
	sfx.pitch_scale = 2
	fall_gravity = 700         # Reduced gravity while hovering (vs default ~1700+)

	# Disable further dashing if meter is depleted
	if flymeter >= 1:
		can_dash = true
	else:
		can_dash = false

func airdown():
	# Stomp — same as Sonic's version
	bounce += 1
	next_bounce = true
	falling = true
	dashed = true
	can_dash = true
	flying = false             # Cancel flying state on stomp
	time_elapsed = 0
	motion.y = 1000
	ap.play("stomp")
	fall_gravity = 10500
	sfx.pitch_scale = 2
	sfx.stream = load("res://Sounds/SonicSFX/Spiked.wav")
	sfx.play()
	motion.x = 0
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default
	dashx = true
	dashed = false

func airspin():
	# Swipe attack — short animation window that damages enemies on contact.
	# Sets swipe = true so the attackbox and animations know an attack is active.
	swipe = true
	dashed = true
	flying = false   # Cancel flight during the attack
	ball = false
	crouch = false
	ap.play("swipe")
	await get_tree().create_timer(0.25).timeout  # Attack active window
	dashed = false
	falling = false
	swipe = false
	fall_gravity = default

func airup():
	# Unused in this character's current move set (no meter cost defined here)
	dashed = true
	ball = false
	if is_player == true:
		Test.meter -= 50
	ap.play("airup")
	motion.y = -1100
	spinaudio()
	smokeemit()
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default
	await get_tree().create_timer(0.3).timeout
	falling = true
	ap.play("falling")

func perform_trick():
	# Slightly higher meter gain per trick than Sonic (1.5 vs 1.0)
	dashed = true
	falling = true
	if is_player == true:
		Test.meter += 1.5
		GlobalCanvasLayer.tricks += 1

	var tricks = ["trick1", "trick2", "trick3", "trick4"]
	var last_index = tricks.find(last_trick)
	var next_index = (last_index + 1) % tricks.size()
	var new_trick = tricks[next_index]
	last_trick = new_trick
	sparkemit()
	sfx.pitch_scale = 1
	sfx.stream = load("res://Sonic Sfx/sparklesfx.MP3")
	sfx.play()
	ap.play(new_trick)
	await get_tree().create_timer(0.3).timeout
	if not Input.is_action_pressed("trick"):
		dashed = false

func spinaudio():
	var audio_files = [
		"res://Sonic VoiceLines/spin1.MP3",
		"res://Sonic VoiceLines/spin2.MP3",
		"res://Sonic VoiceLines/spin3.MP3"
	]
	var random_index = randi() % audio_files.size()
	var random_audio = audio_files[random_index]
	if random_audio:
		voice.stream = load(random_audio)
		sfx.stream = load("res://Sounds/SonicSFX/Trick.wav")
		sfx.pitch_scale = 2
		sfx.play()
		voice.play()

# ─────────────────────────────────────────────
# Signal Handlers
# ─────────────────────────────────────────────
func _on_timer_timeout():
	max_speed = 1000

func _on_spin_timer_timeout():
	# Note: no is_spinningdash guard here — simpler than Sonic's version
	is_spinning = false
	sfx.pitch_scale = 1
	control_lock = false

func _on_wait_timer_timeout():
	wait = true
	ap.play("wait")

func _on_animation_player_current_animation_changed(name: String):
	if name == "stance":
		$WaitTimer.start()
	elif name != "wait":
		wait = false
		$WaitTimer.stop()

func spindash():
	# Simplified vs Sonic — no is_spinningdash flag, no peelout guard
	if is_on_floor() and Input.is_action_pressed("ui_down") and ball == false and next_bounce == false and motion.x == 0 and direction == 0:
		control_lock = true
		if Input.is_action_just_pressed("ui_accept"):
			ap.play("revcharge")
			await(get_tree().create_timer(0.05)).timeout
			$SpinTimer.start()
			spin_charge += 1
			is_spinning = true
			crouch = true
			ap.speed_scale = 1
			ap.play("revup")
			$Sfx.pitch_scale = clamp(spin_charge/2, 0, 2)
			$Sfx.stream = load("res://Sounds/SonicSFX/rev.MP3")
			$Sfx.play()

	elif is_on_floor() and Input.is_action_just_released("ui_down") and is_spinning:
		$Sfx.pitch_scale = 1.5
		$Sfx.stream = load("res://Sounds/SonicSFX/spindash.MP3")
		$Sfx.play()
		is_spinning = false
		crouch = true
		ball = true

		spin_dash_speed = clamp(spin_charge * spin_dash_acceleration, 0, 1550)
		motion.x = spin_dash_speed * sign(motion.x) if motion.x != 0 else spin_dash_speed * (1 if sprite.flip_h == false else -1)
		time_elapsed = abs(motion.x)
		acc = spin_dash_speed

		if spin_charge >= 3:
			max_speed = 1550
			acc = 5000
			time_elapsed = 200

		spin_charge = 0
		smokeemit()

	if ap.current_animation == "revup" and $SpinTimer.time_left < 0.5:
		ap.play("revdown")
		spin_charge = 1

func peelout():
	# Simplified vs Sonic — only charges, no release logic implemented here
	if is_on_floor() and Input.is_action_pressed("ui_up") and ball == false and next_bounce == false and motion.x == 0 and direction == 0:
		control_lock = true
		crouch = true
		if is_spinning == false:
			$AnimationPlayer.play("ready")
		# TODO: add release logic to match Sonic's peelout

func _on_control_lock_timer_timeout() -> void:
	control_lock = false

func _on_coyote_timer_timeout() -> void:
	canjump = false  # Legacy timer — coyote logic uses timestamps now

# ─────────────────────────────────────────────
# Mobile Button Handlers
# These simulate button presses for the on-screen touch controls.
# ─────────────────────────────────────────────
func _on_touch_screen_button_joystick_change(new_pos: Vector2) -> void:
	stickdir = new_pos  # Update virtual joystick direction from on-screen control

func _on_button_pressed() -> void:
	# Jump button — press and immediately release to trigger a single jump frame
	Input.action_press("ui_accept")
	Input.action_press("dash")
	Input.action_release("ui_accept")
	Input.action_release("dash")

func _on_dash_pressed() -> void:
	# Airspin / swipe button
	Input.action_press("airspin")
	Input.action_release("airspin")

func _on_trick_pressed() -> void:
	Input.action_press("trick")
	Input.action_release("trick")

func _on_dash_2_pressed() -> void:
	# Combined ui_up + airup — used for the upward boost move on mobile
	Input.action_press("ui_up")
	Input.action_press("airup")
	Input.action_release("ui_up")
	Input.action_release("airup")

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Rings"):
		if ouch == false:
			$Sfx.stream = load("res://Sounds/Obstacles/Rings/ringsfx.MP3")
			$Sfx.pitch_scale = 1
			$Sfx.play()

	if area.is_in_group("Spring"):
		if is_player == true:
			tricknumber()
			GlobalCanvasLayer.tricks = 0
			Test.meter += 50

	if area.is_in_group("Rail"):
		# Grinding resets fly state and meter
		$Flymeter.visible = false
		flymeter = 85
		grinding = true
		bounce = 0
		can_dash = true
		dashed = false
		flying = false
		motion.y = 0
		fall_gravity = default

	if area.is_in_group("Player"):
		# Show the directional arrow when near a player while flying
		# (signals to the other player that this character can carry them)
		if flying == true:
			$Arrow.visible = true

	if area.is_in_group("enemyattack"):
		hurt()

func apply_spring_boost(velocity_boost: Vector2):
	if bounce > 0:
		motion = velocity_boost * 1.5
	else:
		motion = velocity_boost

func pick_upward_angle() -> float:
	var valid_ranges = [
		Vector2(deg_to_rad(-45), deg_to_rad(45)),
		Vector2(deg_to_rad(45), deg_to_rad(135))
	]
	var selected_range = valid_ranges[randi() % valid_ranges.size()]
	return randf_range(selected_range.x, selected_range.y)

func emit_rings():
	if Test.rings <= 0:
		return

	var loss : int
	var spawn_count : int

	if Test.rings < 6:
		Test.rings = 0
	else:
		loss = int(Test.rings / 2)
		Test.rings -= loss

	match Test.rings + loss:
		1:  spawn_count = 0
		2:  spawn_count = 1
		3:  spawn_count = 2
		4:  spawn_count = 2
		5:  spawn_count = 2
		6:  spawn_count = 3
		7:  spawn_count = 3
		8:  spawn_count = 3
		9:  spawn_count = 4
		10: spawn_count = 4
		11: spawn_count = 4
		12: spawn_count = 5
		13: spawn_count = 5
		14: spawn_count = 5
		15: spawn_count = 6
		16: spawn_count = 6
		17: spawn_count = 6
		18: spawn_count = 7
		19: spawn_count = 7
		_:
			spawn_count = clamp(int(loss / 2), 1, 10)

	for i in range(spawn_count):
		var ring = ring_scene.instantiate()
		var angle = randf_range(0, TAU)
		var speed = randf_range(500, 1000)
		ring.scale = Vector2(1.25, 1.25)
		ring.global_position = position
		ring.velocity = Vector2.RIGHT.rotated(angle) * speed
		ring.loss = true
		get_parent().add_child(ring)

func hurt():
	if is_player == true:
		emit_rings()
		Test.meter -= 50
		if Test.meter <= 0:
			Test.meter = 0
	$Sfx.pitch_scale = 1
	$Sfx.stream = load("res://Sounds/SonicSFX/sonic-rings-drop.MP3")
	$Sfx.play()
	ouch = true
	motion = Vector2(0, 0)
	time_elapsed = 0
	await get_tree().create_timer(0.375, false).timeout
	ouch = false
	$invincibity.start()
	invincible = true

func handle_hitbox():
	if invincible == true:
		$Sprite2D.modulate.a = 0.5

func _on_invincibity_timeout() -> void:
	invincible = false
	$Sprite2D.modulate.a = 1

func _on_attackbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Enemy"):
		if not is_on_floor() and swipe == false:
			# Bounce off enemy; no bounce during swipe (swipe doesn't interrupt trajectory)
			if time_elapsed >= 50:
				motion.y = -1000
			else:
				motion.y = -750
		Test.meter += 10  # Higher meter gain per enemy than Sonic (10 vs 5)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	$onscreentimer.start()

func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	$onscreentimer.stop()

func _on_onscreentimer_timeout() -> void:
	# Teleport off-screen AI back to just above the camera
	global_position.x = get_viewport().get_camera_2d().global_position.x
	global_position.y = get_viewport().get_camera_2d().global_position.y - 500
