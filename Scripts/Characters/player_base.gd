@abstract
class_name Player extends CharacterBody2D

# ─────────────────────────────────────────────
# Debug Variables
@export_group("Debug Variables")
@export var debug_prevent_death = false

# Node References
@onready var ap = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var timer = $Timer          # Used to reset max_speed after leaving a wall
@onready var trail = $Trail2D
@onready var sfx = $Sfx
@onready var voice = $Voice
@onready var invincibity: Timer = $invincibity
@onready var boost_sprite : AnimatedSprite2D = $Boost

@export_group("Node References")
@export var is_player := true        ## If false, this character is AI-controlled and will follow a player node
@export var character_id: String = "" 
# Collision layers stored before entering special zones (e.g. loops), restored on exit
@export var stored_layer: int
@export var stored_mask: int

@export_group("Character Audio")
@export var audio_files : Array
## Echo on the voice lines, like Sonic's
@export var voice_echo := true

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

# Movement State Variables
@export_group("Movement Variables")
@export var max_speed = 500             ## Current speed cap — increases with momentum
@export var acc = 15                    ## Horizontal acceleration — increases with slope/momentum
@export var skid_min_speed : float = 500	## The minimum speed needed to maintain a skid after letting go of a direction while running
@export var MIN_ROT_BALL : float = 0.80		## The minimum rotation where crouching will force the player straight into a ball
@export var  ABOSLUTE_MAX_SPEED : float = 1400	## Factoring in slopes, this is the absolute max motion.x a player can travel
@export var  BASE_MAX_SPEDD : float = 1000	## The max speed a player can attain on flat ground
@export var  MAX_SPEED : float = 1800	## The max speed the player can achieve throug
@export var  MAX_LOW_SPEED : float = 500	## The maximum motion.x when player is traveling at low speed
var run_smoke_interval : float = 0.06   # seconds between run dust puffs
var run_smoke_timer := 0.0
var is_boosting = false         ## True while the ground boost is active (drains meter)
var stomp_no_bounce = false     ## Unused/reserved: prevent bounce after stomp
var is_jumping = false          ## True between pressing jump and releasing it
var jump_pressed = false        ## Tracks whether jump was pressed this frame
var wait = false                ## True when the idle "wait" animation is playing
const SPEED = 10.0              ## Unused base speed constant (legacy)
const BOOST_SPEED := 1800.0      # ground boost top speed
const EXTRA_LIFE_WAIT := 1.5     # seconds down before an extra life starts the floor over
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



func _hands_off() -> bool:
	return Test.reading_page or Pause.visible

func inp_pressed(action: String) -> bool:
	return Input.is_action_pressed(action) and not _hands_off()

func inp_just_pressed(action: String) -> bool:
	if action == "trick" and _super_frame == Engine.get_physics_frames():
		return false
	return Input.is_action_just_pressed(action) and not _hands_off()

func inp_just_released(action: String) -> bool:
	return Input.is_action_just_released(action)

func inp_axis(negative: String, positive: String) -> float:
	return 0.0 if _hands_off() else Input.get_axis(negative, positive)

func joy_axis(axis: JoyAxis) -> float:
	return Input.get_joy_axis(0, axis) if not _hands_off() else 0.0

# This character's rings and meter
var my_rings:
	get: return Test.rings
	set(v): Test.rings = v
var my_meter:
	get: return Test.meter
	set(v): Test.meter = v

var last_animation : String = ""			## Keeps track of the last animation. Useful for things like airup where you go from air up aniamtion to falling animation only if you were previously in air
# Flying State Variables
@export_group("Flying Variables")
@export var flymeter_amount = 85	## Max amount of flying energy
var flymeter_current_amount : float = 85	## Remaining fly energy (drains per flutter, resets on ground/rail)
var flying = false      ## True while the fly/hover ability is active
var swipe = false       ## True during the swipe attack animation window

# Drilling State Variables
var is_drilling = false             ## True while the wall-drill ability is active
var drill_start_time = 0.0          ## Timestamp when drilling started (currently unused)
var original_collision_mask = collision_mask  ## Saved mask — restored when drilling ends

# Drop Dash Variables
var is_drop_dashing = false         ## True once the drop dash is fully charged in the air
var drop_dash_charge = 0.0          ## Timer tracking how long jump has been held in air
var drop_dash_charge_time = 0.3     ## Seconds required to fully charge a drop dash
var drop_dash_speed = 1400          ## Speed applied when the drop dash triggers on landing

# Physics & Rotation State
var motion := Vector2(0,0)      # Internal velocity - applied to CharacterBody2D.velocity each frame
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

# Item Holding System
var held_item: Node2D = null                        ## Reference to the item currently being carried
var item_hold_offset: Vector2 = Vector2(0, -30)     ## Where the item appears relative to the character

# Direction & Wall Jump State
var reverse_to_right = false    ## Unused reverse direction flag
var reverse_to_left = true      ## Unused reverse direction flag
var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0  ## Initial upward velocity on jump
var direction = 0               ## Current horizontal input: -1, 0, or 1
var just_wall_jumped = false    ## Prevents double-triggering wall jump logic
var has_jumped = false          ## Prevents coyote jump after a real jump
var hanging_on_wall : bool = false

# Preloaded Scenes
var smoke = preload("res://Scenes/Effect/Smoke Attack.tscn")          ## Air dash / burst smoke
var sparkle = preload("res://Scenes/Effect/Sparkle.tscn")             ## Trick sparkle effect
var smokeground = preload("res://misc/runsmoke.tscn")   ## Foot dust when running fast
var ring_scene = preload("res://Scenes/Obstacles/Rings/Rings.tscn")  ## Rings scattered on damage

# Spin Dash Variables
@export_group("Spin Dash Variables")
@export var spin_dash_max_charge_speed : int = 1550	## The max x value from releasing the spindash
@export var spin_dash_charge_amount : int = 600    ## Speed added per charge press
@export var spin_dash_acc : int = 500		## Acceleration with spindash at max charge
var spin_dash_speed = 0             ## Calculated release speed for spindash/peelout
var spin_charge = 0                 ## Number of times the charge button was pressed during spindash
var is_spinning = false             ## True while any spinning charge is held
var max_spin_charge = 20            ## Unused cap on spin charge level

# Coyote Time Variables
var coyote_time := 0.25             ## Seconds after leaving a ledge where you can still jump
var last_grounded_time := 0.0       ## Timestamp of the last frame on the ground
var was_on_floor := false           ## Whether the character was on the floor last frame
var prev_grounded = false           ## Previous grounded state (for landing detection)
var grinding = false                ## True while grinding on a rail

# Player Signals

@export_group("UI Elements")
@export var music_color : Color = Color(0.0, 0.478, 1.0, 1.0)
@export var icon_character : Texture = preload("uid://c8po8bidqr685")
@export var icon_character_position_adjust : Vector2 = Vector2.ZERO
@export var icon_background : Texture = preload("uid://dquf4877dk8p6")

# Misc
@export_group("Misc")
@export var player_path: NodePath   ## Path to the player node this AI character should follow
@export var follow_offset: Vector2 = Vector2.ZERO   ## Formation offset behind the leader; assigned at spawn from Test.FORMATION_OFFSETS, x auto-flips with leader facing
@export var trail_position : Vector2 = Vector2.ZERO		## Default trail  position when running
@export var trail_ball_position : Vector2 = Vector2(0, 15)	## Trail position for rolling
@export var trail_dash_max_position : Vector2 = trail_position	## Trail position when running with top speed animation (If you want this and trail_positoin to be the same, keep it as the zero vector)

var texture = "res://Sprites/Characters/Sonic/sonicsheetsonic-sheetmakeup2-sheet.png"  ## Unused texture path
var stickdir = Vector2(0,0)         ## Virtual joystick input direction (mobile only)
var player: Player         ## Reference to the followed player, resolved from player_path

# Hanging / Rail State
var hang = false        ## True while attached to a flying player (disables move_and_slide)
var hangable = false    ## Whether attachment is currently allowed (cleared on ground contact)


func _ready():
	# Voice lines through the echo
	var voice_player := get_node_or_null("Voice")
	if voice_echo and voice_player and AudioServer.get_bus_index(Test.VOICE_ECHO_BUS) != -1:
		voice_player.bus = Test.VOICE_ECHO_BUS
	# Dying drops your rings, with their sound
	var ring_loss := AudioStreamPlayer2D.new()
	ring_loss.name = "DeathRings"
	ring_loss.stream = load("res://Sounds/SonicSFX/sonic-rings-drop.MP3")
	ring_loss.bus = sfx.bus if sfx else "SFX"
	add_child(ring_loss)
	$Trail2D.visible = false    # #Trail starts hidden; shown when speed is high enough
	timer.wait_time = 12        # Wall-exit speed reset delay
	$Sprite2D.visible = true
	$Sprite2D2.visible = false  # Secondary sprite hidden by default (alternate costume/state)
	if trail_dash_max_position == Vector2.ZERO:
		trail_dash_max_position = trail_position
	if not is_player:
		add_to_group("AICharacters")
		assign_formation_slot()

func assign_formation_slot():
	# Determine which formation slot this character occupies based on selection order
	if character_id == Test.charactertwo:
		follow_offset = Test.FORMATION_OFFSETS[0]
	elif character_id == Test.characterthree:
		follow_offset = Test.FORMATION_OFFSETS[1]
	elif character_id == Test.characterfour:
		follow_offset = Test.FORMATION_OFFSETS[2]
	
func _process(_delta):
	_update_shield()
	# Handle virtual joystick on mobile - converts stick input into action events
	if Test.mobile == true and not Test.touch_controls_v2:	# the new touch controls press up/down themselves
		handle_stick_input()	
	if debug_prevent_death and inp_just_pressed("debug"):
		my_rings = 999
		Test.level = 3
	
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
	_ld_carry = maxf(_ld_carry - delta, 0.0)
	if _light_dash(delta):
		return
	_check_super(delta)

	# Release boost if the airspin button is let go
	if inp_just_released("airspin"):
		is_boosting = false

	# ── Track floor state ──────────────────────────────────────────────
	var is_grounded = is_on_floor()
	if is_grounded:
		last_grounded_time = Time.get_ticks_msec() / 1000.0  # Stamp for coyote time
	was_on_floor = is_grounded
	
	if is_grounded and not prev_grounded:
		# Just landed - reset flying state and hide the fly arrow indicator
		if motion.y > 500 and not grinding:
			landing_dust(motion.y)  # dust burst on hard landings
		$Arrow.visible = false
		flying = false
		fall_gravity = default
		has_jumped = false
		if not inp_pressed("crouch"):
			ball = false
	
	# Reset has_jumped on fresh landing (allows coyote jump on next edge)
	if is_grounded and not prev_grounded:
		has_jumped = false
		
	prev_grounded = is_grounded
	
	# Cap the boost meter so it never exceeds maximum
	if my_meter > Test.maxmeter:
		my_meter = Test.maxmeter
		
	# ── Ground Boost Logic ─────────────────────────────────────────────
	if is_on_floor_only():
		if is_boosting:
			# Drain meter while boosting; cancel if depleted
			my_meter -= Test.meter_cost(10 * delta)
			if my_meter <= 0:
				my_meter = 0
				is_boosting = false
			else:
				# Allow steering during boost — use current direction input
				var boost_dir = direction if direction != 0 else (1 if not sprite.flip_h else -1)
				motion.x = move_toward(motion.x, boost_speed() * boost_dir, 5000 * delta)
				max_speed = 1800
		else:
			# Passively recharge meter when not boosting
			my_meter += 1 * delta
			
	# ── Slope Calculation ──────────────────────────────────────────────
	if is_on_floor():
		finished_in_air = false
		insta_used = false
		if is_player == true and held_item == null:	
			if GlobalCanvasLayer.tricks > 0:
				tricknumber()   # landing on 3+ tricks
			GlobalCanvasLayer.tricks = 0
			
		# Floor normal angle offset by 90° gives the surface's "forward" angle
		slopeangle = get_floor_normal().angle() + (PI/2)
		
		# slopefactor = how much of the slope is horizontal (1 = vertical wall, 0 = flat ground)
		slopefactor = get_floor_normal().x
	else:
		slopefactor = 0  # No slope influence while airborne

	# ── Rotation & Sprite Alignment ────────────────────────────────────
	$CollisionShape2D.rotation = rot           # Collision shape snaps to floor angle immediately
	$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, rot, 0.25)
	if finish_spinning:
		# The trick finisher
		if is_on_floor() or is_on_wall() or is_on_ceiling() or grinding or is_player_dead:
			finish_spinning = false
			finish_spin = 0.0
			$Sprite2D.rotation = rot
		else:
			finish_spin = fmod(finish_spin + FINISH_SPIN_SPEED * get_physics_process_delta_time(), TAU)
			$Sprite2D.rotation = rot + finish_spin
	if _insta_spin_left > 0.0:
		var turn := minf(_insta_spin_left, INSTA_SPIN_SPEED * get_physics_process_delta_time())
		_insta_spin_left -= turn
		_insta_spin += turn
		if _insta_spin_left <= 0.0 or is_on_floor() or grinding or is_player_dead:
			_insta_spin_left = 0.0
			_insta_spin = 0.0
			$Sprite2D.rotation = rot
		else:
			$Sprite2D.rotation = rot - _insta_spin   # minus: anticlockwise
	if grounded:
		boost_sprite.rotation = lerp_angle($Sprite2D.rotation, rot, 0.25)  # Sprite smoothly follows

	if is_on_floor():
		# ── Momentum Conversion on Landing ────────────────────────────
		if not grounded:
			# If landing on a steep slope while falling faster than moving horizontally,
			# convert some vertical speed into horizontal speed (like Sonic's slope physics)
			if abs(slopeangle) >= 0.5 and abs(motion.y) > abs(motion.x):
				var downhill_direction = sign(slopefactor)
				if sign(motion.x) == downhill_direction or motion.x == 0:
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
				sfx.pitch_scale = 2
				sfx.stream = load("res://Sounds/SonicSFX/Break Speed.wav")
				sfx.play()
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
		player = get_node(player_path) as Player
		
		if in_loop:
			# Inside a loop: keep current heading, don't recalculate from player position
			pass
		elif player and ((not is_on_floor() and ball == true) or ball == false):
			# Formation slot behind the leader; x flips with leader facing so followers trail correctly
			var facing_sign := -1.0 if player.sprite.flip_h else 1.0
			var desired_position = player.global_position + Vector2(follow_offset.x * facing_sign, follow_offset.y)
			
			# Push apart from other AI followers so they don't stack on top of each other
			for other in get_tree().get_nodes_in_group("AICharacters"):
				if other == self:
					continue
				var away = global_position - other.global_position
				var dist = away.length()
				if dist > 0.001 and dist < Test.FORMATION_SEPARATION_DISTANCE:
					var push_amount = (Test.FORMATION_SEPARATION_DISTANCE - dist) * Test.FORMATION_SEPARATION_STRENGTH
					desired_position.x += sign(away.x) * push_amount
			
			var to_target = desired_position - global_position
			var actual_distance = to_target.length()
			var max_possible_speed = 2000
			var speed_ramp_distance = 200 # Distance over which speed ramps up
			var speed_change_rate = 10500
			
			if actual_distance > Test.FORMATION_STOP_RANGE:
				direction = sign(to_target.x)  # Chase the formation slot horizontally
				var distance_factor = clamp((actual_distance - Test.FORMATION_STOP_RANGE) / speed_ramp_distance, 0.0, 1.0)
				var target_speed = max_possible_speed * distance_factor
				max_speed = move_toward(max_speed, target_speed, speed_change_rate * delta)
			else:
				# Close enough to formation slot — decelerate to stop
				direction = 0
				max_speed = move_toward(max_speed, 0, speed_change_rate * delta)
				if is_on_floor() and absf(motion.x) < 60.0 and sprite.flip_h != player.sprite.flip_h:
					sprite.flip_h = player.sprite.flip_h
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
				if abs(joy_axis(JOY_AXIS_LEFT_X)) > 0.5:
					# Controller analog stick - combine with digital input
					direction = inp_axis("ui_left", "ui_right") + joy_axis(JOY_AXIS_LEFT_X)
					if spin_charge == 0:
						control_lock = false
					direction = sign(direction)
				else:
					# Keyboard / digital input
					direction = inp_axis("ui_left", "ui_right")
					if direction > 0 or direction < 0:
						if spin_charge == 0:
							control_lock = false

	handle_movement_input(delta)

	# ── Apply Velocity (rotated to match slope) ────────────────────────
	if is_grounded and (abs(time_elapsed) > 60 or abs(motion.x) > 500):
		# At high speed or high momentum, and whlie grounded, rotate the velocity vector to stick to slopes
		up_direction = get_floor_normal()
		#if is_player:
			#print(motion.x)
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
		
	if direction != 0 and not grinding:
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
		#if abs(slopefactor) == 1:
			## On a perfectly vertical wall — zero out vertical to avoid drifting
			#motion.y = 0
		#else:
		# Small constant downward force keeps the character pressed to the floor
		motion.y = 50
	
	# Disable directional input during spinning charge (spin dash charges in place)
	if is_spinning:
		direction = 0
	
	# Set wall hanging to false, verify when handling wall mechanics
	hanging_on_wall = false

	# ── Per-Frame Sub-Systems ──────────────────────────────────────────
	handle_wall_mechanics()	# Check wall first to set hanging_on_wall to true if on wall before handling air and ground movement
	handle_floor_logic(delta)
	handle_air_logic(delta, is_grounded)	
	handle_jump_input(is_grounded)
	update_animations()
	handle_hitbox()
	handle_item(delta)
	handle_attachment(delta)
	
	if not hang:
		var before := global_transform
		var run_velocity := velocity
		var was_grounded := is_on_floor()
		move_and_slide()  # Skip physics movement while hanging
		_step_up(before, run_velocity, was_grounded)
		just_wall_jumped = false
		
	update_attachment_position()  # Keep attached player snapped to this character
	update_held_item_position()   # Keep held item snapped to this character
		
# Running into a small step carries you up onto it instead of stopping you dead
const STEP_HEIGHT := 52.0      # the tallest step you run up
const STEP_MIN_SPEED := 60.0   # slower than this, a step still stops you

func _step_up(before: Transform2D, run_velocity: Vector2, was_grounded: bool) -> void:
	if not was_grounded or grinding or absf(run_velocity.x) < STEP_MIN_SPEED or absf(run_velocity.y) > absf(run_velocity.x):
		return
	var dir := signf(run_velocity.x)
	var forward := Vector2(run_velocity.x * get_physics_process_delta_time(), 0.0)
	var blocked := is_on_wall() and get_wall_normal().x * dir < -0.9
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_normal().x * dir < -0.9:
			blocked = true   # something upright in front of you
	if not blocked:
		return
	var lifted := before.translated(Vector2(0.0, -STEP_HEIGHT))
	if test_move(before, Vector2(0.0, -STEP_HEIGHT)) or test_move(lifted, forward):
		return   # a ceiling above, or more wall
	# Up, forward, then down onto the step
	global_transform = lifted.translated(forward)
	var landing := move_and_collide(Vector2(0.0, STEP_HEIGHT + 4.0), true)
	if landing == null or landing.get_normal().y > -0.7:
		global_transform = before   # nothing to stand on up there
		return
	global_position += landing.get_travel()
	# Refresh the floor/wall checks
	var keep := velocity
	velocity = Vector2(0.0, 1.0)
	move_and_slide()
	velocity = Vector2(run_velocity.x, keep.y)


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
		elif inp_just_pressed("airspin") or inp_just_pressed("trick"):
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
	motion.x = boost_speed() * boost_direction
	
	smokeemit()
	sfx.pitch_scale = 1.8
	sfx.stream = load("res://Sounds/SonicSFX/spindash.MP3")
	sfx.play()
	ap.play("Dash max")

func handle_item(delta):
	if item_pickup_cooldown > 0:
		item_pickup_cooldown -= delta
	
	# Drop / throw item on trick button
	if held_item and inp_just_pressed("trick"):
		drop_item()
		return
	
	# Pick up a nearby item when holding up
	if not held_item and inp_pressed("ui_up") and item_pickup_cooldown <= 0:
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
		item.disable_physics(self)
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

	elif abs(joy_axis(JOY_AXIS_LEFT_X)) > 0.5 or abs(joy_axis(JOY_AXIS_LEFT_Y)) > 0.5:
		throw_direction = Vector2(
			joy_axis(JOY_AXIS_LEFT_X),
			joy_axis(JOY_AXIS_LEFT_Y)
		).normalized()
		has_input = true
		print("Controller raw:", throw_direction)

	else:
		throw_direction = Vector2(
			inp_axis("ui_left", "ui_right"),
			inp_axis("ui_down", "ui_up")
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
		if area.is_in_group("Player") and inp_pressed("ui_up"):
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
	# Miku pops up with a rating for the chain
	rate_chain(GlobalCanvasLayer.tricks, false)

const CHAIN_RATINGS := ["good", "great", "awesome", "outstanding", "amazing"]
const CHAIN_RATING_AT := [3, 6, 10, 15, 20]   # tricks in the chain for each rating

# Miku's rating for a chain
func rate_chain(n: int, finished: bool) -> void:
	var idx := -1
	for i in CHAIN_RATING_AT.size():
		if n >= CHAIN_RATING_AT[i]:
			idx = i
	if idx < 0:
		return
	if finished:
		idx = mini(idx + 1, CHAIN_RATINGS.size() - 1)
	Test.trick = CHAIN_RATINGS[idx]

func handle_movement_input(delta):
	if direction and not control_lock:
		if ball == false or !is_on_floor():
			var target_speed = max_speed * direction * Test.speed_scale() * _super_speed()
			var current_acc = acc
			
			# Reversing direction — use high deceleration for a "skidding" feel
			if sign(motion.x) != sign(target_speed) and motion.x != 0:
				current_acc = 2500 * delta
				if is_on_floor() and abs(motion.x) > 300 and not ball:
					skid_dust()  # dust sprays forward while braking
				
			motion.x = approach(motion.x, target_speed, current_acc)
			
		if is_on_floor():
			# Extra friction when turning — only when not in ball mode
			if sign(motion.x) != sign(max_speed * direction) and motion.x != 0 and ball == false:
				motion.x = move_toward(motion.x, 0, fric/2 * delta)
			
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
	if _ld_carry > 0.0 and not is_on_floor():
		return
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
				sfx.pitch_scale = 2
				sfx.stream = load("res://Sounds/SonicSFX/Break Speed.wav")
				sfx.play()
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
	# Optional helper - call in handle_floor_logic to enter ball mode naturally without forcing speed
	if ((velocity.x != 0 or velocity.y != 0) and inp_just_pressed("ui_down")) or ((rot != 0) and inp_just_pressed("ui_down")) and next_bounce == false:
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
		if abs(motion.x) <= 300:
			floor_snap_length = 10
		elif abs(motion.x) <= BASE_MAX_SPEDD:
			floor_snap_length = 30
		else:
			floor_snap_length = 40

		falling = false
		dashed = false
		can_dash = true
		can_stomp = true

		trail.visible = abs(motion.x) > 500
		
		if ball:
			trail.offset = trail_ball_position
			apply_friction(delta)
		elif ap.current_animation == "Dash max":
			trail.offset = trail_dash_max_position
		else:
			trail.offset = trail_position
			
	# Fix the position of the boost sprite base on direction
		if is_boosting:
			if direction == 1:
				boost_sprite.position = Vector2(-0.16, 0.04)
			else:
				boost_sprite.position = Vector2(0.16, 0.04)
			
		# Reset crouching if now moving forward while not in ball mode
		if abs(motion.x) > 0 and ball == false:
			crouch = false
			control_lock = false
		
		# Enter crouch from still
		if inp_pressed("ui_down") and motion.x == 0 and is_spinning == false and next_bounce == false:
			crouch = true
			ap.play("Crouch")
			
		# Stand up from crouch on release
		if inp_just_released("crouch") or inp_just_released("ui_up") and motion.x == 0:
			control_lock = false
			crouch = false
			
		# Enter ball mode when pressing down while moving or on a slope
		if (motion.x != 0 or abs(rot) >= MIN_ROT_BALL) and inp_just_pressed("ui_down") and next_bounce == false:
			crouch = true
			ball = true
			
		# Auto-stand from ball when fully stopped on flat ground
		if motion.x == 0 and abs(rot) < MIN_ROT_BALL:
			crouch = false
			ball = false
			spindash()
			
		# Ground attack/action — only triggers if not already mid-aciton
		handle_ground_action()	## Abstract method

	# Exit ball mode when any action button is pressed
	if (inp_just_pressed("ui_up") or inp_just_pressed("trick") or inp_just_pressed("airspin") or inp_just_pressed("airup")) and ball == true and is_on_floor():
		control_lock = false
		ball = false
		crouch = false
		roll()
		
	# Boost input check
	if inp_just_pressed("airspin") and ball == false and not crouch and not is_spinning and not is_spinningdash and my_meter >= 50 and abs(motion.x) > 0:
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
		trail.offset = trail_position
	elif ball:
		trail.offset = trail_ball_position
	else:
		trail.offset = trail_position
		
	# Enable attachment only when freely airborne (not grinding or dashing)
	if not hang and not grinding and not dashed:
		hangable = true
		
	boost_sprite.rotation = lerp_angle($Sprite2D.rotation,0,0.5)
	
	if not hang:
		control_lock = false  # Restore directional input in the air
		
	crouch = false
	floor_snap_length = 0  # No floor snapping in the air

	# Cancel a pending bounce if airborne without falling
	if next_bounce == true and falling == false:
		next_bounce = false
	
	# You can enter ball mode upon landing
	if ((velocity.x != 0 or velocity.y != 0) and inp_just_pressed("ui_down")) or ((rot != 0) and inp_just_pressed("ui_down")) and next_bounce == false:
		crouch = true
		ball = true
	
	# Drop Dash Charging Charge the drop dash by holding jump while airborne
	if inp_pressed("ui_accept") and drop_dash_charge < drop_dash_charge_time:
		drop_dash_charge += delta
		if drop_dash_charge >= drop_dash_charge_time:
			is_drop_dashing = true  # Fully charged — ready to fire on landing
	
	# Play jump animation if not in a special air state
	if dashed == false:
		if (falling == false or (falling == true and not ball)) and ball == false and grinding == false and not flying and not hang and not is_on_floor() and not hanging_on_wall:
			if ap.current_animation != "stomp":
				ap.play("jump")
		# Clamp horizontal speed at low momentum
		if time_elapsed < 50 and ball == false:
			motion.x = clamp(motion.x , -1000, 1000)
			time_elapsed = 0
		elif time_elapsed >= 60 and ball == false and _ld_carry <= 0.0:   # not straight out of a light speed dash
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
	if is_jumping and !inp_pressed("ui_accept") and motion.y < 0:
		motion.y *= 0.8
		is_jumping = false
	
	if inp_just_pressed("ui_accept") and (grinding or is_grounded or is_coyote_time_active()) and (ball or (!crouch and !ball)) and not just_wall_jumped and not is_spinning:
		floor_snap_length = 0
		
		# Allow jumping while pressing down only if also pressing a direction
		var can_jump_with_down = inp_pressed("ui_down") and direction != 0
		
		if !inp_pressed("ui_down") or can_jump_with_down:
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
				motion.y += jump_velocity * 1.3 * Test.jump_scale() * _super_jump()
			else:
				motion.y += jump_velocity * Test.jump_scale() * _super_jump()
			motion.rotated(rotation)
			
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

# Animation
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
		if inp_pressed("ui_down") and is_spinning == false and next_bounce == false and grinding == false and swipe == false:
			ap.play("Crouch")
		# Look up: every character, standing still and holding up
		elif inp_pressed("ui_up") and direction == 0 and motion.x == 0 and is_on_floor() and not is_ready \
				and next_bounce == false and grinding == false and swipe == false and ap.has_animation("ready"):
			ap.play("ready")

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
	# Rate-limited
	var speed_t : float = clamp((abs(motion.x) - 500.0) / 1300.0, 0.0, 1.0)
	var interval : float = lerp(run_smoke_interval * 1.6, run_smoke_interval * 0.6, speed_t)
	if not is_player:
		interval *= 2.0  # AI followers kick up half as much
	var now = Time.get_ticks_msec() / 1000.0
	if now - run_smoke_timer < interval:
		return
	# Irregular rhythm
	run_smoke_timer = now + interval * randf_range(-0.35, 0.35)
	# Kick the puff back from the feet and let it drift up as it fades
	var dir : float = sign(motion.x) if motion.x != 0 else (-1.0 if sprite.flip_h else 1.0)
	var kick := Vector2(-dir * lerp(60.0, 240.0, speed_t), -randf_range(8.0, 40.0))
	spawn_dust(Vector2(-dir * randf_range(0.0, 12.0), randf_range(-4.0, 1.0)), kick, dir < 0)

func spawn_dust(offset: Vector2, kick: Vector2, face_left: bool, anim_speed: float = -1.0) -> void:
	# One dust puff from the runsmoke sprite
	var puff : Node = smokeground.instantiate()
	puff.position = position + offset.rotated(rot)
	get_parent().add_child(puff)
	puff.rotation = rot
	puff.scale = Vector2(1.125, 1.125)
	puff.flip_h = face_left
	puff.speed_scale = anim_speed if anim_speed > 0.0 else randf_range(1.7, 2.5)
	if randf() < 0.5:
		puff.frame = 1  # skip the small first blob half the time, for variety
	if "velocity" in puff:
		puff.velocity = kick.rotated(rot)
		puff.drag = 420.0
		puff.fade_out = true

func skid_dust() -> void:
	# Classic Sonic skid
	var now = Time.get_ticks_msec() / 1000.0
	if now - run_smoke_timer < 0.045:
		return
	run_smoke_timer = now
	var dir : float = sign(motion.x)
	spawn_dust(Vector2(dir * randf_range(4.0, 10.0), randf_range(-2.0, 1.0)),
		Vector2(dir * randf_range(80.0, 160.0), -randf_range(20.0, 60.0)), dir > 0, 2.6)

func landing_dust(impact: float) -> void:
	# A hard landing kicks dust out to both sides
	var power : float = clamp(impact / 1200.0, 0.4, 1.0)
	for side in [-1.0, 1.0]:
		spawn_dust(Vector2(side * 6.0, 0.0),
			Vector2(side * lerp(80.0, 200.0, power), -lerp(10.0, 40.0, power)), side < 0, 2.4)

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

# Movement Utilities
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
	boost_sprite.flip_h = direction == -1

# Special Moves
func spinaudio():
	if audio_files.size() < 1:
		sfx.stream = load("res://Sounds/SonicSFX/Trick.wav")
	else:
		# Play a random spin voice line + spin SFX
		var random_index = randi() % audio_files.size()
		var random_audio = audio_files[random_index]
		if random_audio:
			voice.stream = random_audio
			sfx.stream = load("res://Sounds/SonicSFX/Trick.wav")
			sfx.pitch_scale = 2
			sfx.play()
			voice.play()

# Signal Handlers
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
	# Keep track of the last animation chnaged
	if anim_name != "":
		last_animation = anim_name
	# Reset the wait timer any time a non-wait animation starts playing
	if anim_name == "stance":
		$WaitTimer.start()
	elif anim_name != "wait":
		wait = false
		$WaitTimer.stop()

func spindash():
	# Guard: don't process spindash if peelout is active
	if is_ready or inp_pressed("ui_up"):
		return
		
	if is_on_floor() and inp_pressed("ui_down") and ball == false and motion.x == 0 and direction == 0:
		control_lock = true
		if inp_just_pressed("ui_accept"):
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
			sfx.pitch_scale = clamp((float)(spin_charge)/2, 1, 2)
			sfx.stream = load("res://Sounds/SonicSFX/rev.MP3")
			sfx.play()

	elif is_on_floor() and inp_just_released("ui_down") and is_spinning and is_spinningdash:
		# Release: calculate and apply burst speed based on charge level
		sfx.pitch_scale = 1.5
		sfx.stream = load("res://Sounds/SonicSFX/spindash.MP3")
		sfx.play()
		is_spinning = false
		is_spinningdash = false
		crouch = true
		ball = true

		spin_dash_speed = clamp(spin_charge * spin_dash_charge_amount, 0, spin_dash_max_charge_speed)
		# Launch in current movement direction; default to sprite facing if stopped
		motion.x = spin_dash_speed * sign(motion.x) if motion.x != 0 else spin_dash_speed * (1 if sprite.flip_h == false else -1)
		time_elapsed = abs(motion.x)
		acc = spin_dash_speed
		
		# Max charge gives a guaranteed speed cap and momentum boost
		if spin_charge >= 3:
			max_speed = spin_dash_max_charge_speed
			acc = spin_dash_acc
			time_elapsed = 200
		
		spin_charge = 0
		smokeemit()
		
	# If the rev-up animation is almost done, drop back to the base charge level
	if ap.current_animation == "revup" and $SpinTimer.time_left < 0.5:
		ap.play("revdown")
		spin_charge = 1
		

func _on_control_lock_timer_timeout() -> void:
	control_lock = false  # Restore player control after a timed lock (e.g. from a launch)

func _on_coyote_timer_timeout() -> void:
	canjump = false  # Legacy coyote timer — coyote logic now uses timestamps instead

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Rings") and ouch == false:
		sfx.stream = load("res://Sounds/Obstacles/Rings/ringsfx.MP3")
		sfx.pitch_scale = 1
		sfx.play()
			
	if area.is_in_group("Spring") and is_player:
		tricknumber()
		flying = false          # Springs cancel the glide
		GlobalCanvasLayer.tricks = 0
		my_meter += 50  # Springs give a meter bonus
		
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
		is_boosting = false
		boost_sprite.visible = false
		GlobalCanvasLayer.boost = false
		
	if area.is_in_group("Player") and flying:
		# Show the directional arrow when near a player while flying
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
	if not is_player or has_meta("downed"):
		return
	if has_node("DeathRings") and not is_player_dead:
		$DeathRings.play()
	if Test.extra_lives > 0:
		_use_extra_life()
		return
	trail.visible = false
	ap.speed_scale = 1
	ap.play("death")
	sfx.volume_db = 10
	sfx.pitch_scale = 1
	sfx.stream = load("res://Sounds/SonicSFX/sonic-game-over-sfx.wav")
	sfx.play()
	is_player_dead = true
	GlobalSignals.set_teto_animation.emit("hurt_loop")
	# Reset level back to 0
	if Test.level != 20:
		Test.level = 0
		# Prevent physics process method from running anymore
	set_physics_process(false)
	
# An extra life from Salvage
func _use_extra_life() -> void:
	Test.extra_lives -= 1
	is_player_dead = true
	trail.visible = false
	ap.speed_scale = 1
	ap.play("death")
	sfx.volume_db = 10
	sfx.pitch_scale = 1
	sfx.stream = load("res://Sounds/SonicSFX/sonic-game-over-sfx.wav")
	sfx.play()
	set_physics_process(false)
	await get_tree().create_timer(EXTRA_LIFE_WAIT).timeout
	if is_inside_tree():
		load("res://Scripts/Level/level_generator.gd").rest_done_level = Test.level
		get_tree().change_scene_to_file("res://Scenes/Level/test3.tscn")


# The shield from Salvage
const SHIELD_SHEET := preload("res://Sprites/Effects/Shield/green_shield.png")   # six frames across
const SHIELD_FRAMES := 6
const SHIELD_FPS := 15.0
const SHIELD_ALPHA := 0.65
var _shield: Node2D

func _update_shield() -> void:
	var want := is_player and Test.shields_left > 0 and not is_player_dead
	if want and _shield == null:
		_shield = Node2D.new()
		_shield.name = "Shield"
		_shield.z_index = 2
		var spr := Sprite2D.new()
		spr.name = "Sprite"
		spr.texture = SHIELD_SHEET
		spr.hframes = SHIELD_FRAMES
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shield.add_child(spr)
		add_child(_shield)
	if _shield:
		_shield.visible = want
		if want:
			_shield.position = $Sprite2D.position
			var spr: Sprite2D = _shield.get_node("Sprite")
			var size := float(SHIELD_SHEET.get_height())
			spr.scale = Vector2.ONE * (_shield_radius() * 2.0 / size)
			spr.frame = int(Time.get_ticks_msec() / 1000.0 * SHIELD_FPS) % SHIELD_FRAMES
			_shield.modulate.a = SHIELD_ALPHA


func _shield_radius() -> float:
	var spr: Sprite2D = $Sprite2D
	var cell := spr.get_rect().size * spr.scale.abs()
	return maxf(cell.x, cell.y) * 0.42


# It takes the hit
func _pop_shield() -> void:
	Test.shields_left -= 1
	sfx.pitch_scale = 1.4
	sfx.stream = load("res://Sounds/SonicSFX/sonic-rings-drop.MP3")
	sfx.play()
	if _shield:
		_shield.visible = false
	$invincibity.start()
	invincible = true


var finished_in_air := false     # done a trick finisher this jump

# The insta shield
const INSTA_SHIELD_TIME := 0.25   # how long it lasts
const INSTA_SHIELD_REACH := 2.0   # how much bigger your attack reach gets
const INSTA_SHIELD_SIZE := 0.9    # how big the swipe looks
var insta_used := false           # used the insta shield this jump
var insta_on := false
var _insta_count := 0

func insta_shield() -> void:
	insta_used = true
	insta_on = true
	_insta_count += 1
	var mine := _insta_count
	var box := get_node_or_null("Attackbox") as Node2D
	if box:
		box.scale = Vector2.ONE * INSTA_SHIELD_REACH
	var fx := Sprite2D.new()
	fx.set_script(preload("res://Scripts/Effects/insta_shield.gd"))
	fx.time = INSTA_SHIELD_TIME
	fx.radius = _shield_radius() * INSTA_SHIELD_SIZE
	fx.flip_h = $Sprite2D.flip_h   # swipes the way you face
	fx.z_index = 3
	fx.position = $Sprite2D.position
	add_child(fx)
	# It hits too: a round attack the size of the swipe
	var hit := Area2D.new()
	hit.name = "InstaHit"
	hit.add_to_group("Playerattack")
	if box is Area2D:
		hit.collision_layer = (box as Area2D).collision_layer
		hit.collision_mask = (box as Area2D).collision_mask
	var ring := CollisionShape2D.new()
	ring.shape = CircleShape2D.new()
	hit.add_child(ring)
	hit.area_entered.connect(_insta_landed)
	add_child(hit)
	# Centred on (and as far round as) the attack box at its insta shield size
	var box_shape := get_node_or_null("Attackbox/CollisionShape2D") as CollisionShape2D
	if box_shape and box_shape.shape:
		ring.global_position = box_shape.global_position
		var ext: Vector2 = box_shape.shape.get_rect().size * 0.5 * box_shape.global_scale.abs()
		(ring.shape as CircleShape2D).radius = maxf(ext.x, ext.y) / maxf(0.001, ring.global_scale.abs().x)
	else:
		ring.position = $Sprite2D.position
		(ring.shape as CircleShape2D).radius = _shield_radius() * INSTA_SHIELD_SIZE
	await get_tree().create_timer(INSTA_SHIELD_TIME, false).timeout
	if is_instance_valid(hit):
		hit.queue_free()
	if mine != _insta_count or not is_instance_valid(self):
		return
	insta_on = false
	if box and is_instance_valid(box):
		box.scale = Vector2.ONE
# A landed insta shield
const INSTA_SPIN_SPEED := 18.0   # how fast
var _insta_spin_left := 0.0
var _insta_spin := 0.0
func _insta_landed(area: Area2D) -> void:
	_on_attackbox_area_entered(area)
	if area.is_in_group("Enemy") and _insta_spin_left <= 0.0 and not finish_spinning:
		_insta_spin_left = TAU
		_insta_spin = 0.0
var finish_spinning := false     # spinning from the trick finisher
const FINISH_SPIN_SPEED := 16.0  # how fast
var finish_spin := 0.0           # the trick finisher spinning the sprite round

# SUPER: all 7 Chaos Emeralds and 50 rings
const SUPER_SPEED := 1.35        # how much faster a super form without its own scene runs
const SUPER_JUMP := 1.2          # and how much harder it jumps
# Characters whose super glow isn't gold
const SUPER_GLOW := {"Knuckles": Color(1.0, 0.5, 0.82), "Blaze": Color(1.0, 0.36, 0.48)}
const SUPER_GLOW_SHADER := preload("res://Shaders/super_glow.gdshader")
var _material_before: Material
var is_super := false            # glowing gold
# HYPER: with all 7 Super Emeralds too, going super makes you hyper
const HYPER_SPEED := 1.6
const HYPER_JUMP := 1.3
const HYPER_AFTERIMAGE_EVERY := 0.045   # seconds between afterimages while moving
var is_hyper := false
var _after_t := 0.0
var _super_frame := -1

# LIGHT SPEED DASH, like Sonic Adventure 1 & 2
@export var can_light_dash := true       ## up + trick near rings zips you along them
@export var light_dash_reach := 170.0    ## how near a ring has to be to start
@export var light_dash_gap := 150.0      ## how far apart rings can be and still be one line
@export var light_dash_speed := 2600.0   ## how fast you zip along
@export var light_dash_exit := 1500.0    ## the least you're going when the line runs out
@export var light_dash_carry := 0.6      ## how long that speed is held before it starts to slow
var _ld_in_speed := 0.0
var _ld_carry := 0.0
var light_dashing := false
var _ld_target: Area2D = null
var _ld_seen := {}
var _ld_dir := Vector2.RIGHT
var _ld_stuck := 0
var _ld_ghost := 0.0


func _ring_ok(r: Node) -> bool:
	if not (r is Area2D) or not is_instance_valid(r) or not r.is_inside_tree() or _ld_seen.has(r):
		return false
	var body := r.get_parent()
	return r.monitoring and body != null and not body.get("_collected") and not body.get("loss")


func _nearest_ring(from: Vector2, reach: float, ahead := Vector2.ZERO) -> Area2D:
	var best: Area2D = null
	var best_d := reach * reach
	for r in get_tree().get_nodes_in_group("Rings"):
		if not _ring_ok(r):
			continue
		var off: Vector2 = (r as Area2D).global_position - from
		if ahead != Vector2.ZERO and off.normalized().dot(ahead) < -0.3:
			continue   # not doubling back on yourself
		var d := off.length_squared()
		if d < best_d:
			best_d = d
			best = r
	return best


# A ring near enough to light speed dash to
func light_dash_ready() -> bool:
	return can_light_dash and not light_dashing and not grinding and _nearest_ring(global_position, light_dash_reach) != null


# Returns true while dashing
func _light_dash(delta: float) -> bool:
	if not light_dashing:
		if not can_light_dash or not is_player or grinding or hang or is_player_dead:
			return false
		if not (inp_pressed("ui_up") and inp_just_pressed("trick")):
			return false
		var first := _nearest_ring(global_position, light_dash_reach)
		if first == null:
			return false
		_super_frame = Engine.get_physics_frames()
		light_dashing = true
		_ld_in_speed = motion.length()
		_ld_seen.clear()
		_ld_target = first
		_ld_stuck = 0
		finish_spinning = false
		_insta_spin_left = 0.0
		is_boosting = false
		ball = false
		crouch = false
		flying = false
		dashed = true
		falling = true
		ap.play("jump")
		trail.visible = true
		sfx.pitch_scale = 1.6
		sfx.stream = load("res://Sounds/SonicSFX/SA_113.wav")
		sfx.play()
		smokeemit()
	# Next ring in the line
	if not _ring_ok(_ld_target):
		_ld_target = _nearest_ring(global_position, light_dash_gap, _ld_dir)
		if _ld_target == null:
			_end_light_dash()
			return false
	var to: Vector2 = _ld_target.global_position - global_position
	var step := light_dash_speed * delta
	if to.length() <= step:
		_ld_seen[_ld_target] = true   # reached it: it gets picked up as you pass
		if to.length() > 0.5:
			_ld_dir = to.normalized()
		var hit := move_and_collide(to)
		if hit:
			move_and_collide(hit.get_remainder().slide(hit.get_normal()))
		_ld_target = null
	else:
		_ld_dir = to.normalized()
		var before := global_position
		var hit := move_and_collide(_ld_dir * step)
		if hit:
			move_and_collide(hit.get_remainder().slide(hit.get_normal()))
		# Can't get there
		_ld_stuck = _ld_stuck + 1 if global_position.distance_to(before) < step * 0.2 else 0
		if _ld_stuck >= 4:
			_ld_seen[_ld_target] = true
			_ld_target = null
			_ld_stuck = 0
	$Sprite2D.flip_h = _ld_dir.x < 0.0 if absf(_ld_dir.x) > 0.1 else $Sprite2D.flip_h
	$Sprite2D.rotation = _ld_dir.angle() if not $Sprite2D.flip_h else _ld_dir.angle() - PI
	motion = _ld_dir * light_dash_speed
	velocity = motion
	_ld_ghost -= delta
	if _ld_ghost <= 0.0:
		_ld_ghost = 0.03
		_afterimage(Color(0.55, 0.8, 1.0, 0.55))
	return true


func _end_light_dash() -> void:
	light_dashing = false
	_ld_target = null
	_ld_seen.clear()
	# Your speed carries on out of it, the way you were going
	var speed := maxf(light_dash_exit, _ld_in_speed)
	motion = _ld_dir * speed
	motion.y = maxf(motion.y, -900.0)   # not off into the sky
	velocity = motion
	time_elapsed = max(time_elapsed, 300)
	max_speed = maxf(absf(motion.x), float(max_speed))
	acc = 5
	trail.visible = true
	_ld_carry = light_dash_carry
	$Sprite2D.rotation = rot
	fall_gravity = default
	dashed = false
	can_dash = true
	can_stomp = true
var _super_drain := 0.0

func _check_super(delta: float) -> void:
	if is_super or is_in_group("super_form"):
		_super_drain += delta
		if _super_drain >= 1.0:
			_super_drain -= 1.0
			my_rings = maxi(my_rings - 1, 0)
		if is_hyper:
			_hyper_look(delta)
		elif is_super:
			var gold := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
			var spr: Sprite2D = $Sprite2D
			if SUPER_GLOW.has(get_meta("character_id", "")):
				if not (spr.material is ShaderMaterial and spr.material.shader == SUPER_GLOW_SHADER):
					_material_before = spr.material
					var m := ShaderMaterial.new()
					m.shader = SUPER_GLOW_SHADER
					m.set_shader_parameter("glow", SUPER_GLOW[get_meta("character_id", "")])
					spr.material = m
				spr.material.set_shader_parameter("pulse", gold)
			else:
				spr.modulate = Color(1.0, 0.9, 0.35).lerp(Color(1.6, 1.4, 0.7), gold)
		if my_rings <= 0:
			_end_super()
		return
	if not is_player or is_on_floor() or Test.chaos_emeralds < Test.SUPER_EMERALDS or my_rings < Test.SUPER_RINGS:
		return
	if inp_pressed("ui_up") and inp_just_pressed("trick"):
		_super_frame = Engine.get_physics_frames()
		_go_super()


func _super_speed() -> float:
	return HYPER_SPEED if is_hyper else SUPER_SPEED if is_super else 1.0


func _super_jump() -> float:
	return HYPER_JUMP if is_hyper else SUPER_JUMP if is_super else 1.0


# Hyper: through every colour, quickly, with white flashes, and afterimages behind
func _hyper_look(delta: float) -> void:
	var spr: Sprite2D = $Sprite2D
	if spr.material is ShaderMaterial and spr.material.shader == SUPER_GLOW_SHADER:
		spr.material = _material_before
	var t := Time.get_ticks_msec() / 1000.0
	var hue := fmod(t * 2.2, 1.0)
	var flash := fmod(t * 8.0, 1.0) < 0.18
	spr.modulate = Color(1.9, 1.9, 1.9) if flash else Color.from_hsv(hue, 0.5, 1.0) * 1.35
	_after_t -= delta
	if _after_t <= 0.0 and absf(motion.x) + absf(motion.y) > 150.0:
		_after_t = HYPER_AFTERIMAGE_EVERY
		_afterimage(Color.from_hsv(fmod(hue + 0.5, 1.0), 0.7, 1.0, 0.6))


func _afterimage(colour: Color) -> void:
	var spr: Sprite2D = $Sprite2D
	var parent := get_parent()
	if parent == null or spr.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = spr.texture
	ghost.hframes = spr.hframes
	ghost.vframes = spr.vframes
	ghost.frame = spr.frame
	ghost.flip_h = spr.flip_h
	ghost.flip_v = spr.flip_v
	ghost.centered = spr.centered
	ghost.offset = spr.offset
	ghost.region_enabled = spr.region_enabled
	ghost.region_rect = spr.region_rect
	ghost.texture_filter = spr.texture_filter
	ghost.modulate = colour
	ghost.z_index = z_index - 1
	parent.add_child(ghost)
	ghost.global_transform = spr.global_transform
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ghost.queue_free)


# Turning hyper
func _hyper_flash() -> void:
	if not is_player:
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0.9)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(white)
	get_tree().current_scene.add_child(layer)
	var tw := white.create_tween()
	tw.tween_property(white, "color:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


func _go_super() -> void:
	sfx.pitch_scale = 1
	sfx.stream = load("res://Sounds/SonicSFX/sparklesfx.MP3")
	sfx.play()
	var id: String = get_meta("character_id", "")
	var entry := Content.character(id)
	var pc := get_parent()
	if entry and entry.super_scene and pc and pc.has_method("swap_to_scene"):
		pc.swap_to_scene(entry.super_scene, id, true)   # its own super form, with its own moves
		return
	is_super = true
	is_hyper = Test.super_emeralds >= Test.SUPER_EMERALDS
	_super_drain = 0.0
	if is_hyper:
		_hyper_flash()


func _end_super() -> void:
	var pc := get_parent()
	if is_in_group("super_form") and pc and pc.has_method("swap_to_scene"):
		var id: String = get_meta("character_id", "")
		pc.swap_to_scene(Content.character(id).scene, id, false)
		return
	is_super = false
	is_hyper = false
	$Sprite2D.modulate = Color.WHITE
	if $Sprite2D.material is ShaderMaterial and $Sprite2D.material.shader == SUPER_GLOW_SHADER:
		$Sprite2D.material = _material_before


# Ground boost top speed, with Faster Boost from Salvage
func boost_speed() -> float:
	return BOOST_SPEED * Test.boost_scale()

func emit_rings():
	# Scatter a portion of held rings on taking damage
	if my_rings <= 0 and invincible == false and ouch == false:
		player_death()
		return
	else:
		# Play damage sound while emitting rings
		# Only play ring loss sound when you have rings
		sfx.pitch_scale = 1
		sfx.stream = load("res://Sounds/SonicSFX/sonic-rings-drop.MP3")
		sfx.play()
	
	var loss : int
	var spawn_count : int
	
	if my_rings < 6:
		loss = Test.rings_lost(my_rings)
	else:
		loss = Test.rings_lost(round((float)(my_rings) / 2))
	my_rings -= loss
		
	
	# Lookup table: maps total rings held to how many ring objects to spawn
	match my_rings + loss:
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
			# For larger ring counts: scatter half of lost rings, capped at 10
			spawn_count = clamp(int((float)(loss) / 2), 0, 10)
	
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
	# Trigger damage response
	if is_super or insta_on:
		return
	if is_player and Test.shields_left > 0 and not invincible:
		_pop_shield()
		return
	if not invincible and held_item and is_instance_valid(held_item) and held_item.has_method("knock_off") \
			and float(held_item.get("spawn_safe") if held_item.get("spawn_safe") != null else 0.0) <= 0.0:
		var lost_item = held_item
		held_item = null
		item_pickup_cooldown = 0.5
		var away := -signf(motion.x) if absf(motion.x) > 1.0 else (1.0 if $Sprite2D.flip_h else -1.0)
		lost_item.knock_off(away)
	if is_player == true:
		emit_rings()
		my_meter -= 50
		if my_meter <= 0:
			my_meter = 0
		var rand : float = randf()
		if !is_player_dead:
			if rand >= 1.0/2.0:
				GlobalSignals.set_teto_animation.emit("taunt")
			else:
				GlobalSignals.set_teto_animation.emit("hurt")
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
		my_meter += 5  # Gain meter for every enemy hit

func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	$onscreentimer.stop()  # Stop the out-of-screen repositioning timer when back on screen


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	if is_player == false:
		$onscreentimer.start()  # Start the timer to teleport AI back near the camera


func _on_onscreentimer_timeout() -> void:
	# Teleport off-screen AI character to just above the camera to keep it near the player
	var cam := get_viewport().get_camera_2d()
	var want := cam.global_position + Vector2(0, -500)
	# Under a roof (the built chunks are solid overhead), that's inside the ground
	var lead := get_node_or_null(player_path) as CollisionObject2D if player_path != NodePath() else null
	if lead:
		var q := PhysicsRayQueryParameters2D.create(lead.global_position, want, collision_mask, [get_rid(), lead.get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
			want = lead.global_position + Vector2(0, -30)
	global_position = want


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Revpeelout":
		# Peel-out rev animation finished — transition into the actual peel-out spin loop
		ap.play("peel out")
		spin_charge += 2
		is_spinning = true
		ap.speed_scale = 0.8
		ap.play("peel out")
		sfx.pitch_scale = clamp((float)(spin_charge)/2, 0, 2)
		sfx.stream = load("res://Sounds/SonicSFX/rev.MP3")
		sfx.play()
	if anim_name == "death":
		GlobalSignals.emit_signal("game_over")
		
