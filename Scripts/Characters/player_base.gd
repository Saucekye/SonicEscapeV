@abstract
class_name Player extends CharacterBody2D

# ─────────────────────────────────────────────
# Node References
# ─────────────────────────────────────────────
@onready var ap = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var timer = $Timer          # Used to reset max_speed after leaving a wall
@onready var trail = $Trail2D
@onready var sfx = $Sfx
@onready var voice = $Voice

@export_group("Node References")
@export var is_player := true        ## If false, this character is AI-controlled and will follow a player node
# Collision layers stored before entering special zones (e.g. loops), restored on exit
@export var stored_layer: int
@export var stored_mask: int

var in_loop = false  # True while the character is inside a loop section

# Fly meter - even only a few characters use it, the base still always needs reference to one
@onready var flymeter: TextureProgressBar = $Flymeter

# Raycasts nodes
@onready var wall_cast: RayCast2D = $CollisionShape2D/WallCast
@onready var wall_cast_2: RayCast2D = $CollisionShape2D/WallCast2
@onready var raycast: RayCast2D = $CollisionShape2D/Raycast

# ─────────────────────────────────────────────
# Signals (used to report trick rating to UI/score system)
# ─────────────────────────────────────────────
signal good
signal great
signal awesome
signal outstanding
signal amazing

# ─────────────────────────────────────────────
# Movement State Variables
# ─────────────────────────────────────────────
@export_group("Movement Variables")
@export var max_speed = 500             ## Current speed cap — increases with momentum
@export var acc = 15                    ## Horizontal acceleration — increases with slope/momentum
@export var skid_min_speed : float = 500	## The minimum speed needed to maintain a skid after letting go of a direction while running
@export var MIN_ROT_BALL : float = 0.79		## The minimum rotation where crouching will force the player straight into a ball
@export var  ABOSLUTE_MAX_SPEED : float = 1400	## Factoring in slopes, this is the absolute max motion.x a player can travel
@export var  BASE_MAX_SPEDD : float = 1000	## The max speed a player can attain on flat ground
@export var  MAX_SPEED : float = 1800	## The max speed the player can achieve throug
@export var  MAX_LOW_SPEED : float = 500	## The maximum motion.x when player is traveling at low speed
var is_boosting = false         ## True while the ground boost is active (drains meter)
var stomp_no_bounce = false     ## Unused/reserved: prevent bounce after stomp
var is_jumping = false          ## True between pressing jump and releasing it
var jump_pressed = false        ## Tracks whether jump was pressed this frame
var wait = false                ## True when the idle "wait" animation is playing
const SPEED = 10.0              ## Unused base speed constant (legacy)
const JUMP_VELOCITY = -500.0    ## Unused constant (jump uses the formula-based jump_velocity instead)
const fric = 60.0                 ## Base friction constant used in several friction calculations
const DASHSPEED = 10000         ## Unused dash speed constant (legacy)
var can_dash = true             ## Whether the aerial dash is available
var dashx = false               ## True after a dash; used to delay friction re-application
var dashed = false              ## Flags that a special air action has been used this airtime
var crouch = false              ## True when crouching or about to roll
var spin = 0                    ## Unused spin variable (legacy)
var ball = false                ## True when rolling (spin ball mode)
var falling = false             ## True when in a falling/stomp/airspin state
var time_elapsed = 0            ## Momentum accumulator — higher = more speed/less friction
var saveddir = 0                ## Unused saved direction variable
var last_trick = ""             ## Tracks the last trick performed, to cycle through them in order
var can_stomp = true            ## Whether the downward air stomp is currently allowed
var bounce = 0                  ## How many consecutive stomps have been performed (affects bounce height)
var next_bounce = false         ## True when the character should bounce on the next floor contact
var is_ready = false            ## True when the peel-out charge is active
var is_spinningdash = false     ## True when the spin dash charge is active
var is_player_dead : bool = false		## Indicates that the player character has died, remove all playability
# ─────────────────────────────────────────────
# Flying State Variables
# ─────────────────────────────────────────────
@export_group("Flying Variables")
@export var flymeter_amount = 85	## Max amount of flying energy
var flymeter_current_amount : float = 85	## Remaining fly energy (drains per flutter, resets on ground/rail)
var flying = false      ## True while the fly/hover ability is active
var swipe = false       ## True during the swipe attack animation window

# ─────────────────────────────────────────────
# Drilling State Variables
# ─────────────────────────────────────────────
var is_drilling = false             ## True while the wall-drill ability is active
var drill_start_time = 0.0          ## Timestamp when drilling started (currently unused)
var original_collision_mask = collision_mask  ## Saved mask — restored when drilling ends

# ─────────────────────────────────────────────
# Drop Dash Variables
# ─────────────────────────────────────────────
var is_drop_dashing = false         ## True once the drop dash is fully charged in the air
var drop_dash_charge = 0.0          ## Timer tracking how long jump has been held in air
var drop_dash_charge_time = 0.3     ## Seconds required to fully charge a drop dash
var drop_dash_speed = 1400          ## Speed applied when the drop dash triggers on landing

# ─────────────────────────────────────────────
# Physics & Rotation State
# ─────────────────────────────────────────────
var motion := Vector2(0,0)      ## Internal velocity — applied to CharacterBody2D.velocity each frame
var rot := 0.0                  ## Current rotation (snapped to floor angle)
var slopeangle := 0.0           ## Angle of the surface the character is standing on
var slopefactor := 0.0          ## X component of the floor normal; used to scale slope effects
var grounded := false           ## Tracks the previous grounded state for momentum conversion on landing
var falloffwall = false         ## Unused wall-fall flag (legacy)
var control_lock = false        ## When true, player input cannot change direction (e.g. during spindash charge)
var stuck = false               ## Unused stuck flag
var canjump = false             ## Legacy coyote jump flag (replaced by is_coyote_time_active())
var ouch = false                ## True while the hurt animation/invincibility is playing
var invincible = false          ## True during invincibility frames after taking damage

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# ─────────────────────────────────────────────
# Jump Arc (formula-based — avoids magic numbers)
# These exports allow tuning jump feel from the Inspector.
# ─────────────────────────────────────────────
@export_group("Jump Arc Variables")
@export var jump_height : float = 260           ## Peak height in pixels
@export var jump_time_to_peak : float = 0.5     ## Seconds to reach peak
@export var jump_time_to_descent : float = 0.45 ## Seconds to fall back down

## Fall gravity used as a baseline reference for restoring gravity after special moves
var default = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

## Gravity during the upward arc (weaker = floatier rise)
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0

## Gravity during the downward arc (stronger = snappier fall)
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

# ─────────────────────────────────────────────
# Attachment System (grabbing onto a flying player)
# ─────────────────────────────────────────────
var attached_to_entity: Node2D = null       ## The flying player this character is holding onto
var entity_attachment_offset: Vector2 = Vector2.ZERO  ## Offset from the entity's position at time of attach

# ─────────────────────────────────────────────
# Item Holding System
# ─────────────────────────────────────────────
var held_item: Node2D = null                        ## Reference to the item currently being carried
var item_hold_offset: Vector2 = Vector2(0, -30)     ## Where the item appears relative to the character

# ─────────────────────────────────────────────
# Direction & Wall Jump State
# ─────────────────────────────────────────────
var reverse_to_right = false    ## Unused reverse direction flag
var reverse_to_left = true      ## Unused reverse direction flag
var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0  ## Initial upward velocity on jump
var direction = 0               ## Current horizontal input: -1, 0, or 1
var just_wall_jumped = false    ## Prevents double-triggering wall jump logic
var has_jumped = false          ## Prevents coyote jump after a real jump

# ─────────────────────────────────────────────
# Preloaded Scenes
# ─────────────────────────────────────────────
var smoke = preload("res://Scenes/Effect/Smoke Attack.tscn")          ## Air dash / burst smoke
var sparkle = preload("res://Scenes/Effect/Sparkle.tscn")             ## Trick sparkle effect
var smokeground = preload("res://misc/runsmoke.tscn")   ## Foot dust when running fast
var ring_scene = preload("res://Scenes/Obstacles/Rings/Rings.tscn")  ## Rings scattered on damage

# ─────────────────────────────────────────────
# Spin Dash Variables
# ─────────────────────────────────────────────
var spin_charge = 0                 ## Number of times the charge button was pressed during spindash
var spin_dash_speed = 0             ## Calculated release speed for spindash/peelout
var is_spinning = false             ## True while any spinning charge is held
var max_spin_charge = 20            ## Unused cap on spin charge level
var spin_dash_acceleration = 600    ## Speed added per charge press

# ─────────────────────────────────────────────
# Coyote Time Variables
# ─────────────────────────────────────────────
var coyote_time := 0.25             ## Seconds after leaving a ledge where you can still jump
var last_grounded_time := 0.0       ## Timestamp of the last frame on the ground
var was_on_floor := false           ## Whether the character was on the floor last frame
var prev_grounded = false           ## Previous grounded state (for landing detection)
var grinding = false                ## True while grinding on a rail

# ─────────────────────────────────────────────
# Player Signals
# ─────────────────────────────────────────────


# Misc
@export_group("Misc")
var texture = "res://Sprites/Characters/Sonic/sonicsheetsonic-sheetmakeup2-sheet.png"  ## Unused texture path
var stickdir = Vector2(0,0)         ## Virtual joystick input direction (mobile only)
@export var player_path: NodePath   ## Path to the player node this AI character should follow
var player: CharacterBody2D         ## Reference to the followed player, resolved from player_path

# ─────────────────────────────────────────────
# Hanging / Rail State
# ─────────────────────────────────────────────
var hang = false        ## True while attached to a flying player (disables move_and_slide)
var hangable = false    ## Whether attachment is currently allowed (cleared on ground contact)


func _ready():
	$Trail2D.visible = false    # #Trail starts hidden; shown when speed is high enough
	timer.wait_time = 12        # Wall-exit speed reset delay
	$Sprite2D.visible = true
	$Sprite2D2.visible = false  # Secondary sprite hidden by default (alternate costume/state)
	
func _process(_delta):
	# Handle virtual joystick on mobile — converts stick input into action events
	if Test.mobile == true:
		handle_stick_input()	
	
func handle_stick_input():
	# Translate the Y axis of the virtual stick into ui_up / ui_down action events
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
		# Neither up nor down — release both
		var ev = InputEventAction.new()
		ev.action = "ui_down"
		ev.pressed = false
		Input.parse_input_event(ev)
		ev = InputEventAction.new()
		ev.action = "ui_up"
		ev.pressed = false
		Input.parse_input_event(ev)

func _on_launch_finished():
	# Called when a spring path finishes; currently just prints a message
	# TODO: restore full player control here if needed
	print("Spring path finished! Movement restored.")

func _physics_process(delta):
	
	# Evil functionality that prevent all input if player is dead
	if is_player_dead:
		return
	
	# Release boost if the airspin button is let go
	if Input.is_action_just_released("airspin"):
		is_boosting = false

	# ── Track floor state ──────────────────────────────────────────────
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
		if not Input.is_action_pressed("crouch"):
			ball = false
	
	# Reset has_jumped on fresh landing (allows coyote jump on next edge)
	if is_grounded and not prev_grounded:
		has_jumped = false
		
	prev_grounded = is_grounded
	
	# Cap the boost meter so it never exceeds maximum
	if Test.meter > Test.maxmeter:
		Test.meter = Test.maxmeter
		
	# ── Ground Boost Logic ─────────────────────────────────────────────
	if is_on_floor_only():
		if is_boosting:
			# Drain meter while boosting; cancel if depleted
			Test.meter -= 10 * delta
			if Test.meter <= 0:
				Test.meter = 0
				is_boosting = false
			else:
				# Allow steering during boost — use current direction input
				var boost_dir = direction if direction != 0 else (1 if not sprite.flip_h else -1)
				motion.x = move_toward(motion.x, 1800 * boost_dir, 5000 * delta)
				max_speed = 1800
		else:
			# Passively recharge meter when not boosting
			Test.meter += 1 * delta
			
	# ── Slope Calculation ──────────────────────────────────────────────
	if is_on_floor():
		if is_player == true:	
			tricknumber()                   # Check if trick count warrants a rating label
			GlobalCanvasLayer.tricks = 0   # Reset trick counter on landing
			
		# Floor normal angle offset by 90° gives the surface's "forward" angle
		slopeangle = get_floor_normal().angle() + (PI/2)
		
		# slopefactor = how much of the slope is horizontal (1 = vertical wall, 0 = flat ground)
		slopefactor = get_floor_normal().x
	else:
		slopefactor = 0  # No slope influence while airborne

	# ── Rotation & Sprite Alignment ────────────────────────────────────
	$CollisionShape2D.rotation = rot           # Collision shape snaps to floor angle immediately
	$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, rot, 0.25)  # Sprite smoothly follows

	if is_on_floor():
		# ── Momentum Conversion on Landing ────────────────────────────
		if not grounded:
			# If landing on a steep slope while falling faster than moving horizontally,
			# convert some vertical speed into horizontal speed (like Sonic's slope physics)
			if abs(slopeangle) >= 0.5 and abs(motion.y) > abs(motion.x):
				var downhill_direction = sign(slopefactor)
				print(sign(motion.x))
				print(downhill_direction)
				if sign(motion.x) == downhill_direction or motion.x == 0:
					print(motion.y * slopefactor)
					const SLOPE_FACTOR_MULTIPLIER : float = 0.8
					motion.x += motion.y * slopefactor * SLOPE_FACTOR_MULTIPLIER
			grounded = true
		
		rot = slopeangle  # Snap rotation to the floor angle
		
	else:
		# ── Momentum Conversion on Leaving Floor ──────────────────────
		if (not $CollisionShape2D/Raycast.is_colliding() and grounded):
			grounded = false
			motion = get_real_velocity()  # Capture actual velocity so slope momentum carries into air
			rot = 0
			up_direction = Vector2(0, -1)  # Reset up direction to world-up
	
	# ── Dynamic Speed / Acceleration ───────────────────────────────────
	var slope_influence = abs(slopefactor)
	var slope_acceleration = sign(-slopefactor * direction)
	
	#print("------MAX SPEED---------")
	#print(max_speed)
	#print("---- CURRENT SPEED -------")
	#print(motion.x)
	
	# Old implementation
	#if abs(motion.x) > 1200:
		## Moving very fast — let speed self-govern and reduce acceleration
		#max_speed = abs(motion.x)
		#acc = 5 + 10 * slope_influence
	#
	if abs(motion.x) >= ABOSLUTE_MAX_SPEED:
		max_speed = ABOSLUTE_MAX_SPEED
		acc = 5 + 10 * slope_influence
	else:
		# Normal speed range — passive momentum system
		if time_elapsed > 50 or motion.x > MAX_LOW_SPEED:
			if max_speed == MAX_LOW_SPEED && is_on_floor():
				# Just crossed the momentum threshold — play break-speed effects
				$Trail2D.visible = true
				$Sfx.pitch_scale = 2
				$Sfx.stream = load("res://Sounds/SonicSFX/Break Speed.wav")
				$Sfx.play()
				smokeemit()
			if abs(slopefactor) > 0:
				# On a slope — adjust max speed by direction (downhill vs uphill)
				if slope_acceleration > 0:
					max_speed = BASE_MAX_SPEDD - (BASE_MAX_SPEDD/5)
					acc = 10 + 2 * slope_influence
				else:
					if ball == true:
						max_speed = ABOSLUTE_MAX_SPEED
						acc = 5 + 10 * slope_influence
						print(acc)
					else:
						max_speed = MAX_SPEED
						acc = 12.5 + 5 * slope_influence
			else:
				# Flat ground — minimum speed boost after gaining momentum
				if max_speed <= BASE_MAX_SPEDD:
					max_speed = BASE_MAX_SPEDD
					acc = 5
		else:
			# Low momentum — standard starting speed and acceleration
			max_speed = MAX_LOW_SPEED
			acc = 25 + 10 * slope_influence
			
	# ── AI Follow Logic ────────────────────────────────────────────────
	if not is_player and not flying:
		player = get_node(player_path) as CharacterBody2D
		
		if in_loop:
			# Inside a loop: keep current heading, don't recalculate from player position
			pass
		elif player and ((not is_on_floor() and ball == true) or ball == false):
			var to_player = player.global_position - global_position
			var actual_distance = to_player.length()
			var stop_range = 60           # Within this distance, the AI stops
			var max_possible_speed = 2000
			var speed_ramp_distance = 200 # Distance over which speed ramps up
			var speed_change_rate = 10500
			
			if actual_distance > stop_range:
				direction = sign(to_player.x)  # Chase player horizontally
				var distance_factor = clamp((actual_distance - stop_range) / speed_ramp_distance, 0.0, 1.0)
				var target_speed = max_possible_speed * distance_factor
				max_speed = move_toward(max_speed, target_speed, speed_change_rate * delta)
			else:
				# Close enough — decelerate to stop
				direction = 0
				max_speed = move_toward(max_speed, 0, speed_change_rate * delta)
	else:
		# ── Player Input ───────────────────────────────────────────────
		if ((not is_on_floor() and ball == true) or ball == false):
			if abs(stickdir.x) > 0.5 and Test.mobile == true:
				# Mobile virtual joystick input
				direction = stickdir.x
				if spin_charge == 0:
					control_lock = false
				direction = sign(direction)  # Normalize to -1 or 1
			else:
				if abs(Input.get_joy_axis(0,JOY_AXIS_LEFT_X)) > 0.5:
					# Controller analog stick — combine with digital input
					direction = Input.get_axis("ui_left", "ui_right") + Input.get_joy_axis(0,JOY_AXIS_LEFT_X)
					if spin_charge == 0:
						control_lock = false
					direction = sign(direction)
				else:
					# Keyboard / digital input
					direction = Input.get_axis("ui_left", "ui_right")
					if direction > 0 or direction < 0:
						if spin_charge == 0:
							control_lock = false

	handle_movement_input(delta)

	# ── Apply Velocity (rotated to match slope) ────────────────────────
	if is_grounded and (abs(time_elapsed) > 60 or abs(motion.x) > 500):
		# At high speed or high momentum, and whlie grounded, rotate the velocity vector to stick to slopes
		up_direction = get_floor_normal()
		velocity = Vector2(motion.x, motion.y).rotated(rot)
	else:
		# At low speed, or  ariborn, use flat velocity (avoids sliding on gentle slopes)
		up_direction = Vector2(0,-1)
		velocity = Vector2(motion.x, motion.y)
		
	# ── Ceiling Bounce ─────────────────────────────────────────────────
	if is_on_ceiling() and not grounded:
		if motion.y < 0:
			motion.y = 100  # Push back down after hitting the ceiling

	# ── Wall Stop ──────────────────────────────────────────────────────
	if is_on_wall() and ($CollisionShape2D/WallCast.is_colliding() or $CollisionShape2D/WallCast2.is_colliding()):
		# Stop horizontal movement and reset momentum when hitting a wall
		time_elapsed = 0
		motion.x = 0
		rot = 0
		
	# Stop rotation on a near-vertical slope if not moving
	if abs(motion.x) == 0 and abs(slopeangle) >= 1:
		rot = 0
		time_elapsed = 0
		
	if direction != 0:
		switch_direction(direction)
		if direction > 0:
			reverse_to_left = true	
		
	# ── Wall-Leave Timer ───────────────────────────────────────────────
	var was_on_wall = is_on_wall()
	var just_left_wall = was_on_wall and not is_on_wall() and motion.x >= 0.0
	if just_left_wall:
		timer.start()  # Briefly limit max_speed after leaving a wall
	
	# ── Gravity ────────────────────────────────────────────────────────
	if (not is_on_floor() and rot == 0):
		motion.y += get_gravityy() * delta  # Apply variable gravity (lighter rising, heavier falling)
	else:
		if abs(slopefactor) == 1:
			# On a perfectly vertical wall — zero out vertical to avoid drifting
			motion.y = 0
		else:
			# Small constant downward force keeps the character pressed to the floor
			motion.y = 50
	
	# Disable directional input during spinning charge (spin dash charges in place)
	if is_spinning:
		direction = 0

	# ── Per-Frame Sub-Systems ──────────────────────────────────────────
	handle_floor_logic(delta)
	handle_air_logic(delta, is_grounded)	## Abstract Method
	handle_jump_input(is_grounded)
	handle_wall_mechanics()		## Abstract Method
	update_animations()
	handle_hitbox()
	handle_item(delta)
	handle_attachment(delta)
	
	if not hang:
		move_and_slide()  # Skip physics movement while hanging (position is set manually)
		just_wall_jumped = false
		
	update_attachment_position()  # Keep attached player snapped to this character
	update_held_item_position()   # Keep held item snapped to this character
		
func update_attachment_position():
	# If currently hanging onto a flying player, manually snap position to their marker
	if hang and attached_to_entity and is_instance_valid(attached_to_entity):
		if follow_target and is_instance_valid(follow_target):
			global_position = follow_target.global_position
		else:
			global_position = attached_to_entity.global_position + entity_attachment_offset
		
		# Kill all momentum while hanging
		velocity = Vector2.ZERO
		motion = Vector2.ZERO
	
var attached_player = null
var hang_transform = null
var hang_cooldown = 0.0         # Prevents immediately re-attaching right after detaching
var item_pickup_cooldown = 0.0  # Prevents immediately picking up an item just thrown/dropped
var follow_target: Node2D = null  # The specific node to follow when hanging (usually a Marker2D)

func handle_attachment(delta):
	if hang_cooldown > 0:
		hang_cooldown -= delta
	
	var flying_player = find_flying_player_nearby()
	
	# ── Attach to a nearby flying player ──────────────────────────────
	if not hang and hangable and hang_cooldown <= 0:
		if flying_player and flying_player.get("flying") and not is_on_floor():
			attach_to_flying_player(flying_player)
			return
	
	# ── Detach checks ──────────────────────────────────────────────────
	if hang and attached_to_entity:
		var should_detach = false
		var detach_reason = ""
		
		# Raycast downward to check if close to the ground
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(
			global_position, 
			global_position + Vector2(0, 50)
		)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		var near_ground = result != null and result.has("position")
		
		# Any of these conditions trigger detachment
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

func ground_boost():
	# Activate the ground-level speed burst (costs meter)
	is_boosting = true
	var boost_direction = direction if direction != 0 else (1 if not sprite.flip_h else -1)
	
	time_elapsed = 300
	max_speed = 1800
	acc = 5000
	motion.x = 1800 * boost_direction
	
	smokeemit()
	sfx.pitch_scale = 1.8
	sfx.stream = load("res://Sounds/SonicSFX/spindash.MP3")
	sfx.play()
	ap.play("Dash max")

func handle_item(delta):
	if item_pickup_cooldown > 0:
		item_pickup_cooldown -= delta
	
	# Drop / throw item on trick button
	if held_item and Input.is_action_just_pressed("trick"):
		drop_item()
		return
	
	# Pick up a nearby item when holding up (and not already carrying something)
	if not held_item and Input.is_action_pressed("ui_up") and item_pickup_cooldown <= 0:
		var item = find_item_nearby()
		if item and not hang:  # Can't pick up while hanging on a flying player
			pick_up_item(item)

func update_held_item_position():
	# Called every frame after move_and_slide to snap the held item to the carry position
	if held_item and is_instance_valid(held_item):
		var offset = item_hold_offset
		# Mirror X offset when facing left
		if sprite.flip_h:
			offset.x = -abs(offset.x)
		else:
			offset.x = abs(offset.x)
		
		held_item.global_position = global_position + offset
		
		# Match item's visual rotation and facing to the player
		if held_item.has_node("Sprite2D"):
			var item_sprite = held_item.get_node("Sprite2D")
			item_sprite.rotation = sprite.rotation
			item_sprite.flip_h = sprite.flip_h
		
		# Kill item velocity so it doesn't drift
		if held_item.has_method("set") and held_item.get("velocity") != null:
			held_item.velocity = Vector2.ZERO
		if held_item.has_method("set") and held_item.get("motion") != null:
			held_item.motion = Vector2.ZERO
		
		# Keep the item's root node unrotated — only the sprite rotates with the player
		held_item.rotation = 0

func attach_to_flying_player(flying_player):
	print("ATTACHING to flying player")
	
	hang = true
	hangable = true
	attached_to_entity = flying_player
	z_index = -1  # Render behind the flying player
	
	# Stop all movement
	motion = Vector2.ZERO
	time_elapsed = 0
	velocity = Vector2.ZERO
	control_lock = true
	
	# Follow the player's Marker2D if available (better attach point), else follow the player itself
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
	
	# Give a small upward pop so the character doesn't immediately fall
	motion.y = -500
	grounded = false
	has_jumped = true
	is_jumping = true
	floor_snap_length = 0
	can_dash = true
	
	hang_cooldown = 0.5   # Brief window before re-attachment is possible
	hangable = false
	
	await get_tree().process_frame

func pick_up_item(item: Node2D):
	print("PICKING UP ITEM")
	
	held_item = item
	
	# Prefer the item's own disable function; fall back to manual disabling
	if item.has_method("disable_physics"):
		item.disable_physics()
	else:
		if item.has_method("set_physics_process"):
			item.set_physics_process(false)
		if item.has_node("CollisionShape2D"):
			item.get_node("CollisionShape2D").set_deferred("disabled", true)
		# Remove from all collision layers while held
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
		print("Mobile throw:", throw_direction)

	elif abs(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) > 0.5 or abs(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)) > 0.5:
		throw_direction = Vector2(
			Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		).normalized()
		has_input = true
		print("Controller raw:", throw_direction)

	else:
		throw_direction = Vector2(
			Input.get_axis("ui_left", "ui_right"),
			Input.get_axis("ui_down", "ui_up")
		)
		if throw_direction != Vector2.ZERO:
			throw_direction = throw_direction.normalized()
			has_input = true
			print("Keyboard throw:", throw_direction)

	if not has_input:
		print("No direction input - keeping item held")
		return

	print("Corrected dir:", throw_direction)

	if throw_direction == Vector2.ZERO:
		print("ERROR: direction zero after correction")
		return

	# ── 2. Ensure spin direction has a horizontal component ────────────
	# Purely vertical throws would cause spinning to look odd
	var spin_dir = throw_direction
	if abs(spin_dir.x) < 0.05:
		spin_dir.x = 0.25
	spin_dir = spin_dir.normalized()

	# ── 3. Re-enable physics on the item ──────────────────────────────
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

	# ── 4. Calculate and apply throw force ────────────────────────────
	var throw_power = 400 + abs(velocity.x)  # Faster movement = harder throw

	# Boost throw power for horizontal throws
	if abs(throw_direction.x) > 0:
		throw_power = throw_power * 1.5
		
	# Give the character a slight upward boost when throwing in the air
	if not is_on_floor():
		motion.y += jump_velocity/1.5
		
	held_item.velocity = Vector2.ZERO
	throw_direction.y = -throw_direction.y  # Flip Y so "up" input = upward throw
	held_item.velocity = throw_direction * throw_power 
	print("Final velocity:", held_item.velocity)

	# ── 5. Apply spinning visual to the item ──────────────────────────
	if held_item.has_method("start_spinning"):
		held_item.start_spinning(spin_dir)
		print("Spin dir:", spin_dir)

	# ── 6. Sound and cooldown ─────────────────────────────────────────
	if sfx:
		sfx.pitch_scale = 1.2
		sfx.stream = load("res://Sounds/SonicSFX/SA_113.wav")
		sfx.play()

	item_pickup_cooldown = 0.5  # Prevent instantly picking the thrown item back up
	held_item = null


func drop_item():
	# Dropping an item calls throw_item — requires directional input to actually throw
	throw_item()


func find_flying_player_nearby():
	# Search overlapping hitbox areas for a flying player while holding ui_up
	var areas = $Hitbox.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("Player") and Input.is_action_pressed("ui_up"):
			var player_node = area.get_parent()
			if player_node != self and player_node.has_method("get") and player_node.get("flying"):
				return player_node
	return null

func find_item_nearby():
	# Search overlapping hitbox areas for a carriable item
	var areas = $Hitbox.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("item"):
			return area.get_parent()
	return null


func tricknumber():
	# Update the global trick rating label based on how many tricks have been chained
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
			
			# Reversing direction — use high deceleration for a "skidding" feel
			if sign(motion.x) != sign(target_speed) and motion.x != 0:
				current_acc = 2500 * delta
				
			motion.x = approach(motion.x, target_speed, current_acc)
			
		if is_on_floor():
			# Extra friction when turning — only when not in ball mode
			if sign(motion.x) != sign(max_speed * direction) and motion.x != 0 and ball == false:
				motion.x = move_toward(motion.x, 0, fric/3)
			
			if dashx == true:
				# Brief pause before re-applying dash friction
				await(get_tree().create_timer(0.01)).timeout
				dashx = false
			
			# Build passive momentum over time (not in ball mode, not boosting)
			if abs(motion.x) > 200 and ball == false and is_boosting == false:
				var slope_acceleration = sign(-slopefactor * direction)
				# Only gain momentum on flat ground or when going downhill
				if abs(slopefactor) < 0.5 or slope_acceleration < 0:
					time_elapsed += 1.5
			
			# Ball rolling: gentle momentum gain only on steeper downhill slopes
			elif ball == true and abs(slopefactor) > 0.1:
				var slope_acceleration = sign(-slopefactor * direction)
				if slope_acceleration > 0:
					time_elapsed += 2
		
		# If barely moving in the intended direction, reset momentum to a walking baseline
		if (motion.x/direction) < 1:
			time_elapsed = 30

	else:
		if not is_boosting:
			apply_friction(delta)

func apply_friction(delta):
	if ball == false:
		if time_elapsed > 50 or not is_on_floor():
			# High-speed or airborne friction — gradual slowdown
			motion.x = move_toward(motion.x, 0, 500 * delta)
			time_elapsed = approach(time_elapsed, 0, 1000 * delta)
		else:
			# Stationary friction — snap to stop quickly
			motion.x = move_toward(motion.x, 0, 5000 * delta)
			time_elapsed = 0
	elif !is_on_floor() and ball == true:
		# Airborne ball: very little drag
		control_lock = false
		motion.x = move_toward(motion.x, 0, fric/4 * delta)
	else:
		# Ball on floor
		if abs(slopefactor) < 0.1:
			# Flat ground: gentle roll-down friction
			motion.x = move_toward(motion.x, 0, 300 * delta)
			if motion.x == 0:
				time_elapsed = 0
		else:
			# Slope physics: gravity component along the surface drives acceleration/deceleration
			var floor_normal = get_floor_normal()
			var slope_accel = gravity * slopefactor
			
			# Minor speed multiplier when rolling fast downhill
			if ball == true and slope_accel > 0 and time_elapsed > 60:
				slope_accel *= 2
			
			if abs(motion.x) < 10:
				# Nearly stopped — let slope gravity get it moving again
				motion.x += slope_accel * delta
			elif sign(motion.x) != sign(slope_accel):
				# Moving uphill — resist with slope gravity
				motion.x = move_toward(motion.x, 0, abs(slope_accel) * delta * 1/3)
			else:
				# Moving downhill — add slope acceleration
				motion.x += slope_accel * delta
				
func calculate_dynamic_speed():
	# Standalone speed calculation (currently unused in _physics_process — logic is inline instead)
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
	# Optional helper — call in handle_floor_logic to enter ball mode naturally without forcing speed
	if ((velocity.x != 0 or velocity.y != 0) and Input.is_action_just_pressed("ui_down")) or ((rot != 0) and Input.is_action_just_pressed("ui_down")) and next_bounce == false:
		crouch = true
		ball = true

func update_momentum_effects():
	# Optional visual feedback — show trail only when already fast in ball mode
	if ball == true and time_elapsed > 100 and abs(motion.x) > 1000:
		if not $Trail2D.visible:
			$Trail2D.visible = true

func handle_floor_logic(delta):	
	if is_on_floor():
		# Landing resets fly meter and hides the meter bar
		flymeter_current_amount = flymeter_amount
		flymeter.visible = false
		
		if not hang:
			hangable = false  # Can't initiate a hang while grounded
		
		# Shorter snap at low speed; longer snap at high speed to hug slopes better
		if time_elapsed <= 50:
			floor_snap_length = 10
		else:
			floor_snap_length = 30

		falling = false
		dashed = false
		can_dash = true
		can_stomp = true

		trail.visible = abs(motion.x) > 500
		
		if ball:
			trail.offset.y = 15
			apply_friction(delta)
		else:
			trail.offset.y = 0
			
		# Reset crouching if now moving forward while not in ball mode
		if abs(motion.x) > 0 and ball == false:
			crouch = false
			control_lock = false
		
		# Enter crouch from still
		if Input.is_action_pressed("ui_down") and motion.x == 0 and is_spinning == false and next_bounce == false:
			crouch = true
			ap.play("Crouch")
			
		# Stand up from crouch on release
		if Input.is_action_just_released("crouch") or Input.is_action_just_released("ui_up") and motion.x == 0:
			control_lock = false
			crouch = false
			
		# Enter ball mode when pressing down while moving or on a slope
		if (velocity.x != 0 or rot > MIN_ROT_BALL) and Input.is_action_just_pressed("ui_down") and next_bounce == false:
			crouch = true
			ball = true
			
		# Auto-stand from ball when fully stopped on flat ground
		if motion.x == 0 and abs(slopefactor) <  MIN_ROT_BALL:
			crouch = false
			ball = false
			spindash()
			
		if motion.x == 0:
			peelout()
			
		# Ground attack/action — only triggers if not already mid-aciton
		handle_ground_action()	## Abstract method

	# Exit ball mode when any action button is pressed
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("trick") or Input.is_action_just_pressed("airspin") or Input.is_action_just_pressed("airup")) and ball == true and is_on_floor():
		control_lock = false
		ball = false
		crouch = false
		roll()
		
	# Boost input check (currently returns early without doing anything — boost is handled in _physics_process)
	if Input.is_action_just_pressed("airspin") and ball == false and not crouch and not is_spinning and not is_spinningdash and Test.meter >= 50 and abs(motion.x) > 0:
		return
			
func reset_dash_after_delay() -> void:
	# Unused coroutine — originally intended to delay can_dash reset
	await get_tree().create_timer(0.5).timeout
	can_dash = true
	can_stomp = true

func handle_air_logic(delta, is_grounded):
	if is_on_floor():
		return
		
	# Change trail offset to 0 value
	if flying:
		trail.offset.y = 0
	elif ball:
		trail.offset.y = 15
	else:
		trail.offset.y = 0
		
		
	# Enable attachment only when freely airborne (not grinding or dashing)
	if not hang and not grinding and not dashed:
		hangable = true
		
	rot = 0  # Always reset rotation while airborne
	
	if not hang:
		control_lock = false  # Restore directional input in the air
		
	crouch = false
	floor_snap_length = 0  # No floor snapping in the air

	# Cancel a pending bounce if airborne without falling
	if next_bounce == true and falling == false:
		next_bounce = false
	
	# You can enter ball mode upon landing
	if ((velocity.x != 0 or velocity.y != 0) and Input.is_action_just_pressed("ui_down")) or ((rot != 0) and Input.is_action_just_pressed("ui_down")) and next_bounce == false:
		crouch = true
		ball = true
	
	# ── Drop Dash Charging ─────────────────────────────────────────
	# Charge the drop dash by holding jump while airborne
	if Input.is_action_pressed("ui_accept") and drop_dash_charge < drop_dash_charge_time:
		drop_dash_charge += delta
		if drop_dash_charge >= drop_dash_charge_time:
			is_drop_dashing = true  # Fully charged — ready to fire on landing
	
	# Play jump animation if not in a special air state
	if dashed == false:
		if (falling == false or (falling == true and not ball)) and ball == false and grinding == false and not flying and not hang and not is_on_wall() and not is_on_floor():
			if ap.current_animation != "stomp":
				ap.play("jump")
		# Clamp horizontal speed at low momentum
		if time_elapsed < 50 and ball == false:
			motion.x = clamp(motion.x , -1000, 1000)
			time_elapsed = 0
		elif time_elapsed >= 60 and ball == false:
			# Slightly higher clamp on flat trajectory
			if slopefactor == 0:
				motion.x = clamp(motion.x , -1300, 1300)
				
	# Prevent character from using air tricks while grinding
	if not grinding:
		handle_air_actions(is_grounded)

@abstract
func handle_air_actions(is_grounded) -> void

@abstract
func handle_ground_action() -> void

@abstract
func handle_wall_mechanics() -> void

func handle_jump_input(is_grounded):
	var slope_influence = abs(slopefactor)
	var slope_acceleration = sign(-slopefactor * direction)
	
	# Variable jump height: cut upward velocity when button is released early
	if is_jumping and !Input.is_action_pressed("ui_accept") and motion.y < 0:
		motion.y *= 0.8
		is_jumping = false
	
	if Input.is_action_just_pressed("ui_accept") and (grinding or is_grounded or is_coyote_time_active()) and (ball or (!crouch and !ball)) and not just_wall_jumped and not is_spinning:
		floor_snap_length = 0
		
		# Allow jumping while pressing down only if also pressing a direction
		var can_jump_with_down = Input.is_action_pressed("ui_down") and direction != 0
		
		if !Input.is_action_pressed("ui_down") or can_jump_with_down:
			if slope_acceleration < 0:
				if time_elapsed >= 50:
					# Boost launch angle on steep uphill slopes at high speed
					rot = 0
					position += Vector2(0, -(5)).rotated(rot)
			elif abs(slopefactor) > 0.1 and time_elapsed < 60:
				# Kill horizontal momentum when jumping off a wall/slope at low speed
				motion.x = 0
				position += Vector2(0, -(6)).rotated(rot)
				
			grinding = false
			
			# Coyote jump gets a bonus — slightly higher arc
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
	# Returns true if within the coyote grace window (recently left a ledge, didn't jump yet)
	if has_jumped:
		return false
	var time_since_grounded = Time.get_ticks_msec() / 1000.0 - last_grounded_time
	return time_since_grounded < coyote_time and motion.y >= 0 and not was_on_floor

# ─────────────────────────────────────────────
# Animation
# ─────────────────────────────────────────────
func update_animations():
	# doturn is a 0–2 scale representing how close to max speed the character is (used for anim speed)
	var doturn = abs(((abs(motion.x)/max_speed)*2))
	if not ouch:
		# Don't override the climb animation while on a wall
		if (wall_cast.is_colliding() or wall_cast_2.is_colliding()) and (not raycast.is_colliding()) and rot == 0:
			return
		if is_on_floor():
			if ball and not grinding:
				ap.speed_scale = 1
				ap.play("ball")
			
			if direction == 0 and not grinding:
				handle_idle_animations()
			else:
				handle_movement_animations(doturn)
		else:
			# Don't reset speed scale while the glide animation is playing
			if not flying:
				ap.speed_scale = 1  # Reset speed scale in air (individual air anims control their own)
	else:
		ap.play("hurt")

func handle_idle_animations():
	# Play appropriate idle/crouch animation when standing still
	if ball != true and crouch != true and is_spinning == false and wait == false and not is_spinningdash and swipe == false:
		if direction == 0 and abs(motion.x) > skid_min_speed:
			ap.play("skid")   # Skid even at low speed (abs > 0, vs Sonic's > 500)
		else:
			ap.play("stance")
		ap.speed_scale = 1
		if Input.is_action_pressed("ui_down") and is_spinning == false and next_bounce == false and grinding == false and swipe == false:
			ap.play("Crouch")

func handle_movement_animations(doturn):
	# doturn < 1 means the character is slower than half speed — play "turn" transition anim
	if doturn < 1 and doturn > -1 and doturn == abs(doturn) and grinding == false and swipe == false:
		ap.speed_scale = 0.75
		if ball != true and (time_elapsed < 10) and control_lock == false:
			ap.play("turn")
	else:
		# Scale animation speed with actual movement speed
		ap.speed_scale = doturn*1.1
		if ball != true and grinding == false and swipe == false:
			# Choose animation tier based on current speed
			ap.play("Dash max" if abs(motion.x) > 1100 else "Dash" if time_elapsed > 50 or abs(motion.x) > 500 else "run")
			if abs(motion.x) > 500:
				runsmoke()

func runsmoke():
	# Spawn a ground dust puff at the feet and mirror it to the movement direction
	var runsmoke_effect : Node = smokeground.instantiate()
	runsmoke_effect.position = position
	get_parent().add_child(runsmoke_effect)
	runsmoke_effect.rotation_degrees = rot
	runsmoke_effect.flip_h = velocity.x < 0
	await get_tree().create_timer(0.13).timeout  # Brief delay before cleanup (handled in runsmoke scene)

func smokeemit():
	# Spawn a burst smoke effect at the character's position (used on dashes and boosts)
	var instantsmoke = smoke.instantiate()
	instantsmoke.position = position
	if velocity.y < 0:
		instantsmoke.rotation_degrees = 270  # Point smoke upward if launching upward
	instantsmoke.flip_h = velocity.x < 0
	get_parent().add_child(instantsmoke)

func sparkemit():
	# Spawn a sparkle effect (used during tricks)
	var instantsmoke = sparkle.instantiate()
	instantsmoke.position = position
	get_parent().add_child(instantsmoke)

# ─────────────────────────────────────────────
# Movement Utilities
# ─────────────────────────────────────────────
func approach(current, target, speed):
	# Moves 'current' toward 'target' by at most 'speed' — never overshoots
	if current < target:
		return min(current + speed, target)
	elif current > target:
		return max(current - speed, target)
	return current

func get_gravityy() -> float:
	# Returns lower gravity while rising, higher gravity while falling (asymmetric arc)
	return jump_gravity if velocity.y < 0.0 else fall_gravity

func roll():
	# Enter or exit ball mode based on current state
	if motion.x == 0 and next_bounce == false:
		ball = false  # Standing still — just stand up
	else:
		ball = crouch == true  # Stay in ball only if still crouching

func switch_direction(_direction):
	# Flip sprite to face the correct way
	sprite.flip_h = direction == -1

# ─────────────────────────────────────────────
# Special Moves
# ─────────────────────────────────────────────
func dash(_direction):
	# Air dash: brief horizontal burst with a pop upward and no gravity
	falling = true
	dashed = true
	ball = false
	crouch = false
	flying = false
	can_dash = false
	ap.play("flick")
	motion.y = -450
	fall_gravity = 0           # Disable gravity briefly for the dash hang-time
	smokeemit()
	sfx.pitch_scale = 2
	sfx.stream = load("res://Sounds/SonicSFX/SA_113.wav")
	sfx.play()

	# Only override speed if below dash threshold — respects existing momentum
	if abs(motion.x) <= 1050:
		time_elapsed = 60
		max_speed = 1000
		acc = 5000
		motion.x = 1050 * sign(direction) if direction != 0 else 1050 * (1 if sprite.flip_h == false else -1)
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default   # Restore gravity after dash hang
	dashx = true
	can_dash = false
	
func airdown():
	# Stomp: slam straight down at high speed, set up for a bounce on landing
	bounce += 1
	next_bounce = true
	falling = true
	dashed = true
	can_dash = true
	time_elapsed = 0
	motion.y = 1000
	ap.play("stomp")
	fall_gravity = 10500     # Very high fall gravity for a fast, snappy slam
	sfx.pitch_scale = 2
	sfx.stream = load("res://Sounds/SonicSFX/Spiked.wav")
	sfx.play()
	motion.x = 0             # Cancel all horizontal momentum for a clean vertical drop
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default
	dashx = true
	dashed = false

func airspin():
	# Air horizontal boost — costs meter, launches in current direction with upward arc
	falling = true
	dashed = true
	ball = false
	if is_player == true:
		Test.meter -= 50
	ap.play("airspin")
	motion.y = -650
	fall_gravity = 0         # Brief gravity suspension for the spin hang-time
	spinaudio()
	smokeemit()
	max_speed = 1200
	acc = 5000
	time_elapsed = 200
	motion.x = 1200 * sign(direction)
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default

func airup():
	# Air vertical boost — costs meter, launches straight up
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
	await get_tree().create_timer(0.3).timeout  # Small delay before entering "falling" state
	falling = true
	ap.play("falling")
	
func perform_trick():
	# Cycle through trick animations in order; gain meter and count tricks
	dashed = true
	falling = true
	if is_player == true:
		Test.meter += 1
		GlobalCanvasLayer.tricks += 1
		
	var tricks = ["trick1", "trick2", "trick3", "trick4"]
	var last_index = tricks.find(last_trick)
	var next_index = (last_index + 1) % tricks.size()  # Always moves to the next in sequence
	var new_trick = tricks[next_index]
	last_trick = new_trick
	sparkemit()
	sfx.pitch_scale = 1
	sfx.stream = load("res://Sounds/SonicSFX/sparklesfx.MP3")
	sfx.play()
	ap.play(new_trick)
	await get_tree().create_timer(0.3).timeout
	# Only re-enable dash/fall if trick button was released during the animation
	if not Input.is_action_pressed("trick"):
		dashed = false
	
func spinaudio():
	# Play a random spin voice line + spin SFX
	var audio_files = [
		"res://Sounds/SonicVoiceLines/spin1.MP3",
		"res://Sounds/SonicVoiceLines/spin2.MP3",
		"res://Sounds/SonicVoiceLines/spin3.MP3"
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
	# After leaving a wall, bring max_speed back down from the burst
	max_speed = 1000

func _on_spin_timer_timeout():
	# Spin dash auto-cancels after the timer expires (even if button is held)
	if is_spinningdash:
		is_spinningdash = false
		is_spinning = false
		sfx.pitch_scale = 1
		control_lock = false

func _on_wait_timer_timeout():
	# Trigger the idle "wait" animation after standing still long enough
	wait = true
	ap.play("wait")

func _on_animation_player_current_animation_changed(anim_name: String):
	# Reset the wait timer any time a non-wait animation starts playing
	if anim_name == "stance":
		$WaitTimer.start()
	elif anim_name != "wait":
		wait = false
		$WaitTimer.stop()

func spindash():
	# Guard: don't process spindash if peelout is active
	if is_ready or Input.is_action_pressed("ui_up"):
		return
		
	if is_on_floor() and Input.is_action_pressed("ui_down") and ball == false and next_bounce == false and motion.x == 0 and direction == 0:
		control_lock = true
		if Input.is_action_just_pressed("ui_accept"):
			# Each accept press adds one charge and revs up the sound
			ap.play("revcharge")
			await(get_tree().create_timer(0.05)).timeout
			$SpinTimer.start()
			spin_charge += 1
			is_spinning = true
			is_spinningdash = true
			crouch = true
			ap.speed_scale = 1
			ap.play("revup")
			$Sfx.pitch_scale = clamp((float)(spin_charge)/2, 1, 2)
			$Sfx.stream = load("res://Sounds/SonicSFX/rev.MP3")
			$Sfx.play()

	elif is_on_floor() and Input.is_action_just_released("ui_down") and is_spinning and is_spinningdash:
		# Release: calculate and apply burst speed based on charge level
		$Sfx.pitch_scale = 1.5
		$Sfx.stream = load("res://Sounds/SonicSFX/spindash.MP3")
		$Sfx.play()
		is_spinning = false
		is_spinningdash = false
		crouch = true
		ball = true

		spin_dash_speed = clamp(spin_charge * spin_dash_acceleration, 0, 1550)
		# Launch in current movement direction; default to sprite facing if stopped
		motion.x = spin_dash_speed * sign(motion.x) if motion.x != 0 else spin_dash_speed * (1 if sprite.flip_h == false else -1)
		time_elapsed = abs(motion.x)
		acc = spin_dash_speed
		
		# Max charge gives a guaranteed speed cap and momentum boost
		if spin_charge >= 3:
			max_speed = 1550
			acc = 5000
			time_elapsed = 200
		
		spin_charge = 0
		smokeemit()
		
	# If the rev-up animation is almost done, drop back to the base charge level
	if ap.current_animation == "revup" and $SpinTimer.time_left < 0.5:
		ap.play("revdown")
		spin_charge = 1
		
func revpeelout():
	# Start the rev peel-out animation
	Input.is_action_pressed("ui_up")  # Note: this line has no effect — likely a leftover check
	ap.play("Revpeelout")
	is_ready = true
		
func peelout():
	# Guard: don't process peelout if spindash is active
	if is_spinningdash or Input.is_action_pressed("ui_down"):
		return
		
	if is_on_floor() and Input.is_action_pressed("ui_up") and ball == false and next_bounce == false and motion.x == 0 and direction == 0: 
		control_lock = true
		crouch = true
		if is_spinning == false and is_ready == false:
			$AnimationPlayer.play("ready")
		
		if Input.is_action_pressed("ui_accept") and is_spinning == false and is_ready == false:
			revpeelout()

	elif is_on_floor() and Input.is_action_just_released("ui_up") and is_spinning and is_ready:
		# Release: launch forward at full peel-out speed
		control_lock = false
		crouch = false
		$Sfx.pitch_scale = 1.5
		$Sfx.stream = load("res://Sounds/SonicSFX/spindash.MP3")
		$Sfx.play()
		time_elapsed = 300
		is_spinning = false
		is_ready = false
		spin_dash_speed = clamp(spin_charge * spin_dash_acceleration, 0, 1600)
		motion.x = spin_dash_speed * sign(motion.x) if motion.x != 0 else spin_dash_speed * (1 if sprite.flip_h == false else -1)
		max_speed = 1800
		acc = 5000
		ap.play("Dash max")
		smokeemit()
		
	elif not is_spinningdash:
		# Not in any special state — ensure flags are clean
		is_ready = false
		is_spinning = false

func _on_control_lock_timer_timeout() -> void:
	control_lock = false  # Restore player control after a timed lock (e.g. from a launch)

func _on_coyote_timer_timeout() -> void:
	canjump = false  # Legacy coyote timer — coyote logic now uses timestamps instead

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Rings") and ouch == false:
		$Sfx.stream = load("res://Sounds/Obstacles/Rings/ringsfx.MP3")
		$Sfx.pitch_scale = 1
		$Sfx.play()
			
	if area.is_in_group("Spring") and is_player:
		tricknumber()
		flying = false          # Springs cancel the glide
		GlobalCanvasLayer.tricks = 0
		Test.meter += 50  # Springs give a meter bonus
		
	if area.is_in_group("Rail"):
		# Grinding resets fly state and meter
		flymeter.visible = false 
		flying = false
		flymeter_current_amount = flymeter_amount
		# Landing on a grind rail
		hang = false
		hangable = false
		grinding = true
		bounce = 0
		can_dash = true
		dashed = false
		motion.y = 0  # Snap vertical motion to rail level

	if area.is_in_group("Player") and flying:
		# Show the directional arrow when near a player while flying
		# (signals to the other player that this character can carry them)
		$Arrow.visible = true
		
	if area.is_in_group("enemyattack") and ouch == false:
		hurt()

func attach_item(item):
	# Reparent an item directly to the player (alternative to the held_item system)
	print("attach")
	var item_parent = item.get_parent()
	var grandparent = item_parent.get_parent()
	grandparent.remove_child(item_parent)
	add_child(item_parent)
	item_parent.position = Vector2(0, 0)
	
	if item_parent.has_node("CollisionShape2D"):
		item_parent.get_node("CollisionShape2D").disabled = true
	if item_parent.has_method("set_physics_process"):
		item_parent.set_physics_process(false)
	
	print("Item attached to player!")
	
func apply_spring_boost(velocity_boost: Vector2):
	# Apply a velocity from a spring; multiply by 1.5 if already mid-bounce chain
	if bounce > 0:
		motion = velocity_boost*1.5
	else:
		motion = velocity_boost
		
func pick_upward_angle() -> float:
	# Returns a random angle pointing in an upward/sideways direction (for ring scatter)
	var valid_ranges = [
		Vector2(deg_to_rad(-45), deg_to_rad(45)),
		Vector2(deg_to_rad(45), deg_to_rad(135))
	]
	var selected_range = valid_ranges[randi() % valid_ranges.size()]
	return randf_range(selected_range.x, selected_range.y)		
		
func player_death():
	if not is_player:
		return
	ap.speed_scale = 1
	ap.play("death")
	$Sfx.volume_db = 10
	$Sfx.pitch_scale = 1
	$Sfx.stream = load("res://Sounds/SonicSFX/sonic-game-over-sfx.wav")
	$Sfx.play()
	# Prevent physics process method from running anymore
	set_physics_process(false)
	
func emit_rings():
	# Scatter a portion of held rings on taking damage (mimics classic Sonic ring loss)
	if Test.rings <= 0 and invincible == false:
		player_death()
		return
	else:
		# Play damage sound while emitting rings
		# Only play ring loss sound when you have rings
		$Sfx.pitch_scale = 1
		$Sfx.stream = load("res://Sounds/SonicSFX/sonic-rings-drop.MP3")
		$Sfx.play()
	
	var loss : int
	var spawn_count : int
	
	if Test.rings < 6:
		Test.rings = 0
	else:
		loss = round((float)(Test.rings) / 2)
		Test.rings -= loss
		
	
	# Lookup table: maps total rings held to how many ring objects to spawn
	match Test.rings + loss:
		1:  spawn_count = 0
		2:  spawn_count = 0
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
			# For larger ring counts: scatter half of lost rings, capped at 10
			spawn_count = clamp(int((float)(loss) / 2), 1, 10)
	
	for i in range(spawn_count):
		var ring = ring_scene.instantiate()
		var angle = randf_range(0, TAU)     # Random scatter direction
		var speed = randf_range(500, 1000)  # Random scatter speed
		ring.scale = Vector2(1.25, 1.25)
		ring.global_position = position
		ring.velocity = Vector2.RIGHT.rotated(angle) * speed
		ring.loss = true  # Marks the ring as a "lost" ring (typically has a pickup timer)
		get_parent().call_deferred("add_child", ring)
		
func hurt():
	# Trigger damage response: scatter rings, drain meter, play hurt animation, begin invincibility
	if is_player == true:
		emit_rings()
		Test.meter -= 50
		if Test.meter <= 0:
			Test.meter = 0
	ouch = true
	motion = Vector2(0, 0)
	time_elapsed = 0
	await get_tree().create_timer(0.375, false).timeout  # Brief stun window
	ouch = false
	$invincibity.start()
	invincible = true
	
func handle_hitbox():
	# Flicker the sprite while invincible to signal the player is temporarily immune
	if invincible == true:
		$Sprite2D.modulate.a = 0.5

func _on_invincibity_timeout() -> void:
	# Invincibility ends — restore full opacity
	invincible = false
	$Sprite2D.modulate.a = 1

func _on_attackbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Enemy"):
		can_stomp = true
		bounce = 0
		if not is_on_floor() and swipe == false:
			# Bounce off enemies in the air; height scales with current momentum
			if time_elapsed >= 50:
				motion.y = -1000
			else:
				motion.y = -750
		Test.meter += 5  # Gain meter for every enemy hit

func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	$onscreentimer.stop()  # Stop the out-of-screen repositioning timer when back on screen


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	if is_player == false:
		$onscreentimer.start()  # Start the timer to teleport AI back near the camera


func _on_onscreentimer_timeout() -> void:
	# Teleport off-screen AI character to just above the camera to keep it near the player
	global_position.x = get_viewport().get_camera_2d().global_position.x
	global_position.y = get_viewport().get_camera_2d().global_position.y - 500 


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Revpeelout":
		# Peel-out rev animation finished — transition into the actual peel-out spin loop
		ap.play("peel out")
		spin_charge += 2
		is_spinning = true
		ap.speed_scale = 0.8
		ap.play("peel out")
		$Sfx.pitch_scale = clamp((float)(spin_charge)/2, 0, 2)
		$Sfx.stream = load("res://Sounds/SonicSFX/rev.MP3")
		$Sfx.play()
	if anim_name == "death":
		GlobalSignals.emit_signal("game_over")
		
