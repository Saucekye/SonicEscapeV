class_name SonicCharacterBase extends CharacterBody2D

# ============================================================
# NODES
# ============================================================
@onready var ap     = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var timer  = $Timer
@onready var trail  = $Trail2D
@onready var sfx    = $Sfx
@onready var voice  = $Voice

# ============================================================
# EXPORTS
# ============================================================
@export var is_player          := true
@export var stored_layer       : int
@export var stored_mask        : int
@export var jump_height        : float = 260
@export var jump_time_to_peak  : float = 0.5
@export var jump_time_to_descent: float = 0.45
@export var player_path        : NodePath

# ============================================================
# SIGNALS
# ============================================================
signal good
signal great
signal awesome
signal outstanding
signal amazing
signal state_changed(old_state: int, new_state: int)

# ============================================================
# STATE MACHINE
# ============================================================
enum State {
	GROUND,
	CROUCH,
	BALL,
	SPINDASH,
	PEELOUT,
	JUMP,
	AIR,
	DASH,
	STOMP,
	AIRSPIN,
	AIRUP,
	TRICK,
	GRIND,
	HANG,
	HURT,
	BOOST,
	DROP_DASH,
}

var current_state : int = State.GROUND
var previous_state: int = State.GROUND

# ============================================================
# PRELOADED RESOURCES
# ============================================================
var smoke       = preload("res://Smoke Attack.tscn")
var sparkle     = preload("res://Sparkle.tscn")
var smokeground = preload("res://misc/runsmoke.tscn")
var ring_scene  = preload("res://obstacles/rings/Rings.tscn")

var sfx_jump        = preload("res://Sonic Sfx/Jump.wav")
var sfx_break_speed = preload("res://Sonic Sfx/Break Speed.wav")
var sfx_spindash    = preload("res://Sonic Sfx/spindash.MP3")
var sfx_rev         = preload("res://Sonic Sfx/rev.MP3")
var sfx_sa113       = preload("res://Sonic Sfx/SA_113.wav")
var sfx_spiked      = preload("res://Sonic Sfx/Spiked.wav")
var sfx_trick       = preload("res://Sonic Sfx/Trick.wav")
var sfx_sparkle     = preload("res://Sonic Sfx/sparklesfx.MP3")
var sfx_rings_drop  = preload("res://Sonic Sfx/sonic-rings-drop.MP3")
var sfx_ring_pickup = preload("res://obstacles/rings/ringsfx.MP3")

var voice_spin1 = preload("res://Sonic VoiceLines/spin1.MP3")
var voice_spin2 = preload("res://Sonic VoiceLines/spin2.MP3")
var voice_spin3 = preload("res://Sonic VoiceLines/spin3.MP3")

# ============================================================
# PHYSICS CONSTANTS
# ============================================================
const SPEED         = 10.0
const JUMP_VELOCITY = -500.0
const DASHSPEED     = 10000
const fric          = 60

# ============================================================
# MOVEMENT VARIABLES
# ============================================================
var motion      := Vector2.ZERO
var direction    = 0
var max_speed    = 500
var acc          = 15
var time_elapsed = 0
var rot          := 0.0
var slopeangle   := 0.0
var slopefactor  := 0.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Plain vars like the old script — recalculated in _ready() after exports apply
# Matches old script exactly: @onready uses inspector-applied export values
# and runs before _ready() regardless of subclass overrides.
var default : float = 0.0  # set in _ready() to mirror fall_gravity
@onready var jump_gravity  : float = ((-2.0 * jump_height) / (jump_time_to_peak    * jump_time_to_peak))    * -1.0
@onready var fall_gravity  : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
@onready var jump_velocity : float = ((2.0  * jump_height) / jump_time_to_peak) * -1.0

# ============================================================
# STATE FLAGS
# ============================================================
var grounded        := false
var can_dash         = true
var can_stomp        = true
var dashx            = false
var dashed           = false
var falling          = false
var next_bounce      = false
var bounce           = 0
var just_wall_jumped = false
var has_jumped       = false
var control_lock     = false
var invincible       = false
var ouch             = false
var wait             = false
var in_loop          = false
var stomp_no_bounce  = false
var jump_pressed     = false
var is_jumping       = false

# ============================================================
# SPINDASH / PEELOUT
# ============================================================
var spin_charge            = 0
var spin_dash_speed        = 0
var spin_dash_acceleration = 600
var max_spin_charge        = 20
var last_trick             = ""
var _is_spinning           = false
var _is_spinningdash       = false
var _is_ready              = false

# ============================================================
# DROP DASH
# ============================================================
var is_drop_dashing       = false
var drop_dash_charge      = 0.0
var drop_dash_charge_time = 0.3
var drop_dash_speed       = 1400

# ============================================================
# COYOTE TIME
# ============================================================
var coyote_time        := 0.25
var last_grounded_time := 0.0
var was_on_floor       := false
var prev_grounded       = false

# ============================================================
# BOOST
# ============================================================
var is_boosting = false

# ============================================================
# ITEM & ATTACHMENT
# ============================================================
var held_item           : Node2D = null
var item_hold_offset    : Vector2 = Vector2(0, -30)
var item_pickup_cooldown = 0.0

var attached_to_entity      : Node2D = null
var entity_attachment_offset: Vector2 = Vector2.ZERO
var follow_target           : Node2D = null
var hang_cooldown            = 0.0
var hangable                 = false

# ============================================================
# AI / MISC
# ============================================================
var player: CharacterBody2D
var texture          = "res://Sonic/sonicsheetsonic-sheetmakeup2-sheet.png"
var stickdir         = Vector2.ZERO
var saveddir         = 0
var reverse_to_right = false
var reverse_to_left  = true
var _prev_direction  = 0
var falloffwall      = false
var stuck            = false
var canjump          = false
var spin             = 0
var grinding         = false
var hang             = false

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	# @onready vars above are already set by the engine before _ready() runs.
	# default mirrors fall_gravity so gravity resets use the same value.
	default = fall_gravity

	$Trail2D.visible   = false
	timer.wait_time    = 12
	$Sprite2D.visible  = true
	$Sprite2D2.visible = false
	change_state(State.GROUND)

# ============================================================
# STATE MACHINE CORE
# ============================================================

func change_state(new_state: int) -> void:
	if new_state == current_state:
		return
	_exit_state(current_state)
	previous_state = current_state
	current_state  = new_state
	hang = (current_state == State.HANG)
	emit_signal("state_changed", previous_state, current_state)
	_enter_state(current_state)


func _enter_state(state: int) -> void:
	match state:
		State.GROUND:
			floor_snap_length = 10
			fall_gravity      = default
			grinding          = false
		State.CROUCH:
			ap.play("Crouch")
		State.BALL:
			pass
		State.SPINDASH:
			control_lock     = true
			_is_spinning     = false
			_is_spinningdash = false
			ap.play("Crouch")
		State.PEELOUT:
			control_lock = true
			_is_spinning = false
			_is_ready    = false
			ap.play("Crouch")
		State.JUMP:
			floor_snap_length = 0
			is_jumping        = true
			jump_pressed      = true
			grounded          = false
			fall_gravity      = default
			# Sound/anim handled in _do_jump to respect ball/grind checks
		State.AIR:
			floor_snap_length = 0
			fall_gravity      = default
			rot               = 0
			up_direction      = Vector2(0, -1)
		State.DASH:
			floor_snap_length = 0
			dashed       = true
			falling      = true
			can_dash     = false
			fall_gravity = 0
			motion.y     = -450
			smokeemit()
			sfx.pitch_scale = 2
			sfx.stream      = sfx_sa113
			sfx.play()
			ap.play("flick")
			_finish_dash_async()
		State.STOMP:
			dashed       = true
			can_dash     = true
			falling      = true
			next_bounce  = true
			bounce      += 1
			fall_gravity = 10500
			motion.y     = 1000
			motion.x     = 0
			time_elapsed = 0
			ap.play("stomp")
			sfx.pitch_scale = 2
			sfx.stream      = sfx_spiked
			sfx.play()
			_finish_stomp_async()
		State.AIRSPIN:
			dashed   = true
			falling  = true
			if is_player:
				Test.meter -= 50
			fall_gravity = 0
			motion.y     = -650
			motion.x     = 1200 * sign(direction)
			max_speed    = 1200
			acc          = 5000
			time_elapsed = 200
			spinaudio()
			smokeemit()
			ap.play("airspin")
			_finish_airspin_async()
		State.AIRUP:
			dashed = true
			if is_player:
				Test.meter -= 50
			motion.y = -1100
			spinaudio()
			smokeemit()
			ap.play("airup")
			_finish_airup_async()
		State.TRICK:
			dashed  = true
			falling = true
		State.GRIND:
			dashed    = false
			can_dash  = true
			bounce    = 0
			motion.y  = 0
			floor_snap_length = 0
			grinding  = true
		State.HANG:
			z_index      = -1
			motion       = Vector2.ZERO
			velocity     = Vector2.ZERO
			time_elapsed = 0
			control_lock = true
			hangable     = true
			if ap.has_animation("hang"):
				ap.play("hang")
		State.HURT:
			ouch         = true
			motion       = Vector2.ZERO
			time_elapsed = 0
			sfx.pitch_scale = 1
			sfx.stream      = sfx_rings_drop
			sfx.play()
			_finish_hurt_async()
		State.BOOST:
			is_boosting  = true
			time_elapsed = 300
			max_speed    = 1800
			acc          = 5000
			smokeemit()
			sfx.pitch_scale = 1.8
			sfx.stream      = sfx_spindash
			sfx.play()
			ap.play("Dash max")
		State.DROP_DASH:
			is_drop_dashing = true


func _exit_state(state: int) -> void:
	match state:
		State.SPINDASH:
			control_lock     = false
			_is_spinning     = false
			_is_spinningdash = false
		State.PEELOUT:
			control_lock = false
			_is_spinning = false
			_is_ready    = false
		State.HANG:
			z_index                  = 1
			control_lock             = false
			attached_to_entity       = null
			follow_target            = null
			entity_attachment_offset = Vector2.ZERO
			hang_cooldown            = 0.5
			hangable                 = false
			motion.y                 = -500
			grounded                 = false
			has_jumped               = true
			is_jumping               = true
			floor_snap_length        = 0
			can_dash                 = true
		State.HURT:
			ouch = false
		State.DROP_DASH:
			is_drop_dashing  = false
			drop_dash_charge = 0.0

# ============================================================
# ASYNC HELPERS
# ============================================================

func _finish_dash_async() -> void:
	if abs(motion.x) <= 1050:
		time_elapsed = 60
		max_speed    = 1000
		acc          = 5000
		motion.x     = 1050 * sign(direction) if direction != 0 \
						else 1050 * (1 if not sprite.flip_h else -1)
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default
	dashx    = true
	can_dash = false
	if current_state == State.DASH:
		change_state(State.AIR)


func _finish_stomp_async() -> void:
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default
	dashx  = true
	dashed = false


func _finish_airspin_async() -> void:
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default
	if current_state == State.AIRSPIN:
		change_state(State.AIR)


func _finish_airup_async() -> void:
	await get_tree().create_timer(0.13).timeout
	fall_gravity = default
	await get_tree().create_timer(0.3).timeout
	if current_state == State.AIRUP:
		falling = true
		ap.play("falling")
		change_state(State.AIR)


func _play_next_trick_async() -> void:
	var tricks     = ["trick1", "trick2", "trick3", "trick4"]
	var last_index = tricks.find(last_trick)
	var next_index = (last_index + 1) % tricks.size()
	last_trick     = tricks[next_index]
	ap.play(last_trick)
	await get_tree().create_timer(0.3).timeout
	if not Input.is_action_pressed("trick"):
		dashed = false


func _perform_trick() -> void:
	dashed  = true
	falling = true
	if current_state != State.TRICK:
		change_state(State.TRICK)
	if is_player:
		Test.meter += 1
		GlobalCanvasLayer.tricks += 1
	sparkemit()
	sfx.pitch_scale = 1
	sfx.stream      = sfx_sparkle
	sfx.play()
	_play_next_trick_async()


func _finish_hurt_async() -> void:
	if is_player:
		emit_rings()
		Test.meter = max(0, Test.meter - 50)
	await get_tree().create_timer(0.375, false).timeout
	ouch = false
	$invincibity.start()
	invincible = true
	change_state(State.AIR if not is_on_floor() else State.GROUND)

# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:
	if Test.mobile:
		handle_stick_input()

# ============================================================
# PHYSICS PROCESS
# ============================================================

func _physics_process(delta: float) -> void:
	if Input.is_action_just_released("airspin"):
		is_boosting = false

	var is_grounded = is_on_floor()
	if is_grounded:
		last_grounded_time = Time.get_ticks_msec() / 1000.0
	was_on_floor = is_grounded

	if is_grounded and not prev_grounded:
		has_jumped = false
	prev_grounded = is_grounded

	Test.meter = min(Test.meter, Test.maxmeter)

	if is_on_floor_only():
		if is_boosting:
			Test.meter -= 10 * delta
			if Test.meter <= 0:
				Test.meter  = 0
				is_boosting = false
			else:
				var boost_dir = direction if direction != 0 else (1 if not sprite.flip_h else -1)
				motion.x  = move_toward(motion.x, 1800 * boost_dir, 5000 * delta)
				max_speed = 1800
		else:
			Test.meter += 1 * delta

	if is_on_floor():
		if is_player:
			tricknumber()
			GlobalCanvasLayer.tricks = 0
		slopeangle  = get_floor_normal().angle() + (PI / 2)
		slopefactor = get_floor_normal().x
	else:
		slopefactor = 0

	$CollisionShape2D.rotation = rot
	$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, rot, 0.25)

	if is_on_floor():
		if not grounded:
			if abs(slopeangle) >= 0.5 and abs(motion.y) > abs(motion.x):
				var downhill_dir = -sign(slopefactor)
				if sign(motion.x) == downhill_dir or motion.x == 0:
					motion.x += motion.y * slopefactor
			grounded = true
		rot = slopeangle
	else:
		if not $CollisionShape2D/Raycast.is_colliding() and grounded:
			grounded     = false
			motion       = get_real_velocity()
			rot          = 0
			up_direction = Vector2(0, -1)

	if is_on_floor():
		if falling == false and next_bounce == false:
			bounce = 0
		if Input.is_action_pressed("airspin"):
			next_bounce = false
			can_stomp   = true
		if next_bounce == true and falling == true:
			match bounce:
				1: motion.y = -750
				2: motion.y = -950
				_ when bounce >= 3: motion.y = -1100
			can_stomp = true

	var slope_influence    = abs(slopefactor)
	var slope_acceleration = sign(-slopefactor * direction)

	if abs(motion.x) > 1250:
		max_speed = abs(motion.x)
		acc       = 5 + 10 * slope_influence
	else:
		if time_elapsed > 50:
			if max_speed == 500 and is_on_floor():
				$Trail2D.visible = true
				sfx.pitch_scale  = 2
				sfx.stream       = sfx_break_speed
				sfx.play()
				smokeemit()
			if abs(slopefactor) > 0:
				if slope_acceleration > 0:
					max_speed = 1000
					acc       = 5 + 10 * slope_influence
				elif _is_ball():
					max_speed = 1800
					acc       = 5 + 10 * slope_influence
				else:
					max_speed = 1200
					acc       = 5 + 10 * slope_influence
			elif max_speed <= 900:
				max_speed = 900
				acc       = 5
		else:
			max_speed = 500
			acc       = 25

	# Gravity runs BEFORE jump input — matches old script order.
	# Without this, the floor else-branch resets motion.y = 50
	# immediately after _physics_state applies jump_velocity.
	if not is_on_floor() and rot == 0:
		motion.y += get_gravityy() * delta
	else:
		motion.y = 0 if abs(slopefactor) == 1 else 50

	_update_direction(delta)
	_physics_state(delta, is_grounded)

	if _is_spinning:
		direction = 0

	if abs(time_elapsed) > 60 or abs(motion.x) > 500:
		up_direction = get_floor_normal()
		velocity     = Vector2(motion.x, motion.y).rotated(rot)
	else:
		up_direction = Vector2(0, -1)
		velocity     = Vector2(motion.x, motion.y)

	if is_on_ceiling() and not grounded and motion.y < 0:
		motion.y = 100

	if is_on_wall() and ($CollisionShape2D/WallCast.is_colliding() or $CollisionShape2D/WallCast2.is_colliding()):
		time_elapsed = 0
		motion.x     = 0
		rot          = 0

	if abs(motion.x) == 0 and abs(slopeangle) >= 1:
		rot          = 0
		time_elapsed = 0

	if direction != 0:
		switch_direction(direction)
		if direction > 0:
			reverse_to_left = true

	var was_on_wall    = is_on_wall()
	var just_left_wall = was_on_wall and not is_on_wall() and motion.x >= 0.0
	if just_left_wall:
		timer.start()

	update_animations()
	handle_hitbox()
	handle_item(delta)
	handle_attachment(delta)

	if current_state != State.HANG:
		move_and_slide()
		just_wall_jumped = false

	update_attachment_position()
	update_held_item_position()

# ============================================================
# PER-STATE PHYSICS
# ============================================================

func _physics_state(delta: float, is_grounded: bool) -> void:
	match current_state:
		State.GROUND:    _state_ground(delta, is_grounded)
		State.CROUCH:    _state_crouch(delta)
		State.BALL:      _state_ball(delta, is_grounded)
		State.SPINDASH:  spindash()
		State.PEELOUT:   peelout()
		State.JUMP:      _state_jump_or_air(delta, is_grounded)
		State.AIR:       _state_jump_or_air(delta, is_grounded)
		State.DROP_DASH: _state_drop_dash(is_grounded)
		State.DASH:      pass
		State.STOMP:     _state_stomp()
		State.AIRSPIN:   pass
		State.AIRUP:     pass
		State.TRICK:     _state_trick(delta, is_grounded)
		State.GRIND:     _state_grind(delta, is_grounded)
		State.HANG:      _state_hang()
		State.HURT:      pass
		State.BOOST:     _state_boost(delta)


func _state_ground(delta: float, is_grounded: bool) -> void:
	_update_floor_snap()
	handle_movement_input(delta)

	if not is_grounded:
		change_state(State.AIR)
		return

	trail.visible = abs(motion.x) > 500

	if Input.is_action_pressed("ui_down") and motion.x == 0 and not _is_spinning and not next_bounce:
		ap.play("Crouch")

	if Input.is_action_just_released("ui_up") and motion.x == 0:
		control_lock = false

	if _wants_to_ball():
		change_state(State.BALL)
		return

	if abs(motion.x) > 0:
		control_lock = false

	if _is_ball() and (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("trick")
	or Input.is_action_just_pressed("airspin") or Input.is_action_just_pressed("airup")):
		control_lock = false
		_set_ball(false)
		roll()

	if _wants_jump(is_grounded):
		_do_jump(is_grounded)
		return

	if motion.x == 0 and direction == 0 and not next_bounce:
		if abs(slopefactor) < 0.4 and Input.is_action_pressed("ui_down") \
		and not Input.is_action_pressed("ui_up") and not _is_ready:
			change_state(State.SPINDASH)
			return
		if Input.is_action_pressed("ui_up") \
		and not Input.is_action_pressed("ui_down") and not _is_spinningdash:
			change_state(State.PEELOUT)
			return

	handle_wall_mechanics()


func _state_crouch(delta: float) -> void:
	apply_friction(delta)
	if Input.is_action_just_released("ui_down") or motion.x != 0:
		control_lock = false
		change_state(State.GROUND)
		return
	if _wants_to_ball():
		change_state(State.BALL)


func _state_ball(delta: float, is_grounded: bool) -> void:
	apply_friction(delta)

	if is_grounded:
		_update_floor_snap()
		trail.visible = abs(motion.x) > 500

		if motion.x == 0 and not next_bounce:
			_set_ball(false)
			change_state(State.GROUND)
			return

		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("trick") \
		or Input.is_action_just_pressed("airspin") or Input.is_action_just_pressed("airup"):
			control_lock = false
			_set_ball(false)
			roll()
			change_state(State.GROUND)
			return

		if _wants_jump(is_grounded):
			_do_jump(is_grounded)
			return

		if motion.x == 0 and direction == 0 and not next_bounce:
			if abs(slopefactor) < 0.4 and Input.is_action_pressed("ui_down") \
			and not Input.is_action_pressed("ui_up") and not _is_ready:
				change_state(State.SPINDASH)
				return
			if Input.is_action_pressed("ui_up") \
			and not Input.is_action_pressed("ui_down") and not _is_spinningdash:
				change_state(State.PEELOUT)
				return

		if is_drop_dashing and drop_dash_charge >= drop_dash_charge_time \
		and Input.is_action_pressed("ui_accept"):
			execute_drop_dash()
			return
		else:
			is_drop_dashing  = false
			drop_dash_charge = 0.0
	else:
		handle_movement_input(delta)
		if not dashed:
			_clamp_air_speed()
		if Input.is_action_pressed("ui_accept") and drop_dash_charge < drop_dash_charge_time:
			drop_dash_charge += delta
			if drop_dash_charge >= drop_dash_charge_time:
				is_drop_dashing = true
		handle_air_actions(is_grounded)

	handle_wall_mechanics()


func _state_jump_or_air(delta: float, is_grounded: bool) -> void:
	handle_movement_input(delta)

	# Matches old handle_air_logic — runs every airborne frame
	if not is_on_floor():
		if not hang and not grinding and not dashed:
			hangable = true
		rot               = 0
		floor_snap_length = 0
		if not hang:
			control_lock = false

	# Variable jump cut — old script: motion.y *= 0.8
	if is_jumping and Input.is_action_just_released("ui_accept") and motion.y < 0:
		motion.y  *= 0.8
		is_jumping = false

	# Drop dash charge
	if Input.is_action_pressed("ui_accept") and drop_dash_charge < drop_dash_charge_time:
		drop_dash_charge += delta
		if drop_dash_charge >= drop_dash_charge_time:
			is_drop_dashing = true

	# Landing
	if is_grounded:
		has_jumped = false
		if is_drop_dashing and drop_dash_charge >= drop_dash_charge_time \
		and Input.is_action_pressed("ui_accept"):
			execute_drop_dash()
			return
		else:
			is_drop_dashing  = false
			drop_dash_charge = 0.0
		change_state(State.GROUND)
		return

	# Air speed clamp only when not dashed — matches old script
	if not dashed:
		_clamp_air_speed()

	handle_air_actions(is_grounded)

	if not hang and hangable and hang_cooldown <= 0:
		var fp = find_flying_player_nearby()
		if fp and fp.get("flying") and not is_on_floor():
			_attach_to_flying_player(fp)
			return

	handle_wall_mechanics()


func _state_drop_dash(is_grounded: bool) -> void:
	if is_grounded:
		if Input.is_action_pressed("ui_accept"):
			execute_drop_dash()
		else:
			change_state(State.GROUND)


func _state_stomp() -> void:
	if is_on_floor():
		if Input.is_action_pressed("airspin"):
			next_bounce = false
			can_stomp   = true
		change_state(State.GROUND)


func _state_trick(delta: float, is_grounded: bool) -> void:
	if Input.is_action_just_pressed("trick") \
	and not (is_on_wall_only() and not $CollisionShape2D/Raycast.is_colliding() and rot == 0):
		$Parry/AnimationPlayer.play("play")
		_perform_trick()

	handle_movement_input(delta)
	if not dashed:
		_clamp_air_speed()
	handle_air_actions(is_grounded)

	if is_grounded:
		if grinding:
			change_state(State.GRIND)
		else:
			change_state(State.GROUND)


func _state_grind(delta: float, is_grounded: bool) -> void:
	handle_movement_input(delta)

	if Input.is_action_just_pressed("trick"):
		$Parry/AnimationPlayer.play("play")
		_perform_trick()
		return

	if _wants_jump(is_grounded):
		grinding = false
		_do_jump(is_grounded)
		return
	if not is_grounded:
		grinding = false
		change_state(State.AIR)


func _state_hang() -> void:
	update_attachment_position()
	var near_ground   = _raycast_near_ground()
	var should_detach = false
	if near_ground:
		should_detach = true
	elif not is_instance_valid(attached_to_entity):
		should_detach = true
	elif not attached_to_entity.get("flying"):
		should_detach = true
	elif Input.is_action_just_pressed("airspin") or Input.is_action_just_pressed("trick"):
		should_detach = true
	if should_detach:
		change_state(State.AIR)
		await get_tree().process_frame


func _state_boost(delta: float) -> void:
	if not is_on_floor():
		is_boosting = false
		change_state(State.AIR)
		return
	Test.meter -= 10 * delta
	if Test.meter <= 0:
		Test.meter  = 0
		is_boosting = false
		change_state(State.GROUND)
		return
	var boost_dir = direction if direction != 0 else (1 if not sprite.flip_h else -1)
	motion.x  = move_toward(motion.x, 1800 * boost_dir, 5000 * delta)
	max_speed = 1800

# ============================================================
# AIR ACTIONS — matches old handle_air_actions exactly
# ============================================================

func handle_air_actions(is_grounded: bool) -> void:
	if grinding:
		return

	# Air dash
	if Input.is_action_just_pressed("ui_accept") \
	and not Input.is_action_pressed("ui_down") \
	and can_dash \
	and not $CollisionShape2D/WallCast.is_colliding() \
	and not $CollisionShape2D/WallCast2.is_colliding() \
	and not is_coyote_time_active():
		can_dash  = false
		can_stomp = true
		change_state(State.DASH)
		ap.play("flick")
		return

	# Airspin — not ui_down AND not ui_up AND direction != 0
	if is_player and Test.meter >= 50 \
	and Input.is_action_just_pressed("airspin") \
	and not Input.is_action_pressed("ui_down") \
	and not Input.is_action_pressed("ui_up") \
	and direction != 0:
		change_state(State.AIRSPIN)
		ap.play("airspin")
		time_elapsed = 200
		max_speed    = 1200
		can_dash     = true
		can_stomp    = true
		bounce       = 0
		return

	# Airup — (airspin + ui_up) OR airup button
	if is_player and Test.meter >= 50 \
	and ((Input.is_action_just_pressed("airspin") and Input.is_action_pressed("ui_up")) \
	or Input.is_action_just_pressed("airup")):
		can_dash  = true
		can_stomp = true
		bounce    = 0
		change_state(State.AIRUP)
		return

	# Stomp — airspin + ui_down
	if Input.is_action_just_pressed("airspin") \
	and Input.is_action_pressed("ui_down") \
	and can_stomp \
	and not is_on_wall():
		can_dash  = true
		can_stomp = false
		change_state(State.STOMP)
		return

	# Trick
	if Input.is_action_just_pressed("trick") \
	and not (is_on_wall_only() and not $CollisionShape2D/Raycast.is_colliding() and rot == 0):
		$Parry/AnimationPlayer.play("play")
		_perform_trick()

# ============================================================
# BALL HELPERS
# ============================================================

func _is_ball() -> bool:
	return current_state == State.BALL

func _set_ball(value: bool) -> void:
	if value and current_state != State.BALL:
		change_state(State.BALL)
	elif not value and current_state == State.BALL:
		change_state(State.GROUND)

# ============================================================
# INPUT HELPERS
# ============================================================

func _update_direction(_delta: float) -> void:
	if not is_player:
		_update_ai_direction()
		return
	var allow = (not is_on_floor() and _is_ball()) or not _is_ball()
	if not allow:
		return
	if abs(stickdir.x) > 0.5 and Test.mobile:
		direction = sign(stickdir.x)
		if spin_charge == 0: control_lock = false
	elif abs(Input.get_joy_axis(0, 0)) > 0.5:
		direction = sign(Input.get_axis("ui_left", "ui_right") + Input.get_joy_axis(0, 0))
		if spin_charge == 0: control_lock = false
	else:
		direction = int(Input.get_axis("ui_left", "ui_right"))
		if direction != 0 and spin_charge == 0:
			control_lock = false


func _update_ai_direction() -> void:
	player = get_node(player_path) as CharacterBody2D
	if in_loop or not player:
		return
	var to_player = player.global_position - global_position
	var dist      = to_player.length()
	const STOP_RANGE  = 60.0
	const RAMP_DIST   = 200.0
	const MAX_SPD     = 2000.0
	const CHANGE_RATE = 10500.0
	if dist > STOP_RANGE:
		direction = sign(to_player.x)
		var factor = clamp((dist - STOP_RANGE) / RAMP_DIST, 0.0, 1.0)
		max_speed  = move_toward(max_speed, MAX_SPD * factor, CHANGE_RATE * get_physics_process_delta_time())
	else:
		direction = 0
		max_speed = move_toward(max_speed, 0.0, CHANGE_RATE * get_physics_process_delta_time())


func _wants_jump(is_grounded: bool) -> bool:
	return Input.is_action_just_pressed("ui_accept") \
		and (is_grounded or grinding or is_coyote_time_active()) \
		and not just_wall_jumped \
		and current_state != State.SPINDASH \
		and current_state != State.PEELOUT \
		and not _is_spinning


func _wants_to_ball() -> bool:
	return ((velocity.x != 0 or velocity.y != 0) or rot != 0) \
		and Input.is_action_just_pressed("ui_down") \
		and not next_bounce


func _do_jump(is_grounded):
	var slope_influence = abs(slopefactor)
	var slope_acceleration = sign(-slopefactor * direction)
	if is_jumping and !Input.is_action_pressed("ui_accept") and motion.y < 0:
		motion.y *= 0.8  # or 0.3, etc. — this cuts upward momentum
		is_jumping = false
	
	if Input.is_action_just_pressed("ui_accept") and (grinding or is_grounded or is_coyote_time_active()) and (current_state == State.BALL or (current_state != State.CROUCH and current_state != State.BALL)) and not just_wall_jumped and not _is_spinning:
		motion += Vector2(0, -(5)).rotated(rot)
		floor_snap_length = 0
		
		# Allow jumping if ui_down is pressed BUT also ui_right or ui_left is pressed
		var can_jump_with_down = Input.is_action_pressed("ui_down") and direction != 0
		
		if !Input.is_action_pressed("ui_down") or can_jump_with_down:
			
			if slope_acceleration < 0:
				if time_elapsed >= 50:
					rot = 0
					position += Vector2(0, -(5)).rotated(rot)
			
			elif abs(slopefactor) > 0.1 and time_elapsed < 60:
				motion.x = 0# If you're sideways or upside-down (on a wall or cieling)...
				position += Vector2(0, -(6)).rotated(rot)
				
			grinding = false
			if is_coyote_time_active() == true:
				motion.y += jump_velocity * 1.3
			else:
				motion.y += jump_velocity
			
			
			has_jumped = true
			is_jumping = true
			jump_pressed = true
				
			if current_state == State.BALL == false and grinding == false:
				ap.play("jump")
				sfx.pitch_scale = 1
				sfx.stream = load("res://Sonic Sfx/Jump.wav")
				sfx.play()
				change_state(State.JUMP)
				
				

	


func _clamp_air_speed() -> void:
	if time_elapsed < 50 and not _is_ball():
		motion.x     = clamp(motion.x, -1000, 1000)
		time_elapsed = 0
	elif time_elapsed >= 60 and not _is_ball() and slopefactor == 0:
		motion.x = clamp(motion.x, -1300, 1300)


func _update_floor_snap() -> void:
	floor_snap_length = 30 if time_elapsed > 50 else 10

# ============================================================
# DROP DASH
# ============================================================

func execute_drop_dash() -> void:
	is_drop_dashing  = false
	drop_dash_charge = 0.0
	change_state(State.BALL)
	var dash_dir = 1 if not sprite.flip_h else -1
	if direction != 0:
		dash_dir = sign(direction)
	if max_speed <= 1000:
		motion.x     = drop_dash_speed * dash_dir
		time_elapsed = 100
		max_speed    = 1000
		acc          = 5000
	smokeemit()
	sfx.pitch_scale = 1.8
	sfx.stream      = sfx_spindash
	sfx.play()
	ap.play("ball")
	ap.speed_scale = 2

# ============================================================
# MOVEMENT
# ============================================================

func handle_movement_input(delta: float) -> void:
	if direction != 0 and not control_lock:
		if not _is_ball() or not is_on_floor():
			var target_speed = max_speed * direction
			var current_acc  = acc
			if sign(motion.x) != sign(target_speed) and motion.x != 0:
				current_acc = 2500 * delta
			motion.x = approach(motion.x, target_speed, current_acc)

		if is_on_floor():
			if sign(motion.x) != sign(max_speed * direction) and motion.x != 0 and not _is_ball():
				motion.x = move_toward(motion.x, 0, fric / 3.0)
			if dashx:
				await get_tree().create_timer(0.01).timeout
				dashx = false
			if abs(motion.x) > 200 and not _is_ball() and not is_boosting:
				var slope_acceleration = sign(-slopefactor * direction)
				if abs(slopefactor) < 0.5 or slope_acceleration < 0:
					time_elapsed += 1.5
			elif _is_ball() and abs(slopefactor) > 0.1:
				if sign(-slopefactor * direction) > 0:
					time_elapsed += 2

		if motion.x / direction < 1:
			time_elapsed = 30
	else:
		if not is_boosting:
			apply_friction(delta)


func apply_friction(delta: float) -> void:
	if not _is_ball():
		if time_elapsed > 50 or not is_on_floor():
			motion.x     = move_toward(motion.x, 0, 500 * delta)
			time_elapsed = approach(time_elapsed, 0, 1000 * delta)
		else:
			motion.x     = move_toward(motion.x, 0, 5000 * delta)
			time_elapsed = 0
	elif not is_on_floor():
		control_lock = false
		motion.x = move_toward(motion.x, 0, fric / 4.0 * delta)
	else:
		if abs(slopefactor) < 0.1:
			motion.x = move_toward(motion.x, 0, 300 * delta)
			if motion.x == 0:
				time_elapsed = 0
		else:
			var local_slope = get_floor_normal().x
			var slope_accel = gravity * local_slope
			if _is_ball() and slope_accel > 0 and time_elapsed > 60:
				slope_accel *= 2
			if abs(motion.x) < 10:
				motion.x += slope_accel * delta
			elif sign(motion.x) != sign(slope_accel):
				motion.x = move_toward(motion.x, 0, abs(slope_accel) * delta / 3.0)
			else:
				motion.x += slope_accel * delta

# ============================================================
# SPINDASH / PEELOUT
# ============================================================

func spindash() -> void:
	if Input.is_action_just_released("ui_down"):
		if _is_spinning and _is_spinningdash:
			_release_spindash()
			change_state(State.BALL)
		else:
			change_state(State.GROUND)
		return

	if not is_on_floor() or not Input.is_action_pressed("ui_down") \
	or Input.is_action_pressed("ui_up"):
		change_state(State.GROUND)
		return

	if Input.is_action_just_pressed("ui_accept"):
		ap.play("revcharge")
		await get_tree().create_timer(0.05).timeout
		$SpinTimer.start()
		spin_charge      += 1
		_is_spinning      = true
		_is_spinningdash  = true
		ap.speed_scale    = 1
		ap.play("revup")
		sfx.pitch_scale = min(spin_charge / 2.0, 2.0)
		sfx.stream      = sfx_rev
		sfx.play()

	if ap.current_animation == "revup" and $SpinTimer.time_left < 0.5:
		ap.play("revdown")
		spin_charge = 1


func _release_spindash() -> void:
	sfx.pitch_scale  = 1.5
	sfx.stream       = sfx_spindash
	sfx.play()
	_is_spinning     = false
	_is_spinningdash = false
	spin_dash_speed  = clamp(spin_charge * spin_dash_acceleration, 0, 1550)
	motion.x = spin_dash_speed * sign(motion.x) if motion.x != 0 \
		else spin_dash_speed * (1 if not sprite.flip_h else -1)
	time_elapsed = abs(motion.x)
	acc          = spin_dash_speed
	if spin_charge >= 3:
		max_speed    = 1550
		acc          = 5000
		time_elapsed = 200
	spin_charge = 0
	smokeemit()


func revpeelout() -> void:
	ap.play("Revpeelout")
	_is_ready = true


func peelout() -> void:
	if Input.is_action_just_released("ui_up"):
		if _is_spinning and _is_ready:
			_release_peelout()
		change_state(State.GROUND)
		return

	if not is_on_floor() or not Input.is_action_pressed("ui_up") \
	or Input.is_action_pressed("ui_down"):
		_is_ready    = false
		_is_spinning = false
		change_state(State.GROUND)
		return

	if not _is_spinning and not _is_ready:
		$AnimationPlayer.play("ready")

	if Input.is_action_pressed("ui_accept") and not _is_spinning and not _is_ready:
		revpeelout()


func _release_peelout() -> void:
	control_lock = false
	sfx.pitch_scale = 1.5
	sfx.stream      = sfx_spindash
	sfx.play()
	time_elapsed = 300
	_is_spinning = false
	_is_ready    = false
	spin_dash_speed = clamp(spin_charge * spin_dash_acceleration, 0, 1600)
	motion.x = spin_dash_speed * sign(motion.x) if motion.x != 0 \
		else spin_dash_speed * (1 if not sprite.flip_h else -1)
	max_speed = 1800
	acc       = 5000
	ap.play("Dash max")
	smokeemit()

# ============================================================
# WALL MECHANICS
# ============================================================

func handle_wall_mechanics() -> void:
	if not ($CollisionShape2D/WallCast.is_colliding() or $CollisionShape2D/WallCast2.is_colliding()):
		return
	if $CollisionShape2D/Raycast.is_colliding() or rot != 0:
		return
	if is_player:
		tricknumber()
		GlobalCanvasLayer.tricks = 0
	falling   = false
	dashed    = false
	_set_ball(false)
	motion.y /= 1.3
	ap.play("onwallair")
	sprite.flip_h = $CollisionShape2D/WallCast.is_colliding()
	if Input.is_action_just_pressed("ui_accept"):
		var wall_normal  = get_wall_normal()
		var push_dir     = 1 if wall_normal.x > 0 else -1
		position        += Vector2(push_dir * 25, 0).rotated(rot)
		motion.x         = 2500 * push_dir
		motion.y         = jump_velocity / 1.5
		just_wall_jumped = true
		change_state(State.JUMP)

# ============================================================
# ANIMATIONS
# ============================================================

func update_animations() -> void:
	if ouch:
		ap.play("hurt")
		return
	match current_state:
		State.BALL, State.STOMP, State.DROP_DASH:
			if not grinding:
				ap.speed_scale = 1
				ap.play("ball")
		State.HURT:
			ap.play("hurt")
		State.HANG, State.SPINDASH, State.PEELOUT:
			pass
		_:
			if is_on_floor():
				if direction == 0 and not grinding:
					_handle_idle_animations()
				elif not grinding:
					_handle_movement_animations()
			else:
				# Old script: only set speed_scale in the air
				# Jump anim driven by _do_jump; action anims by _enter_state
				ap.speed_scale = 1


func _handle_idle_animations() -> void:
	if _is_ball() or _is_spinning or wait or _is_spinningdash:
		return
	if direction == 0 and abs(motion.x) > 500:
		ap.play("skid")
	else:
		ap.play("stance")
	ap.speed_scale = 1
	if Input.is_action_pressed("ui_down"):
		ap.play("Crouch")


func _handle_movement_animations() -> void:
	var doturn = abs((abs(motion.x) / max_speed) * 2)
	if doturn < 1 and not grinding:
		ap.speed_scale = 0.75
		if time_elapsed < 10 and not control_lock:
			ap.play("turn")
	else:
		ap.speed_scale = doturn * 1.1
		if not _is_ball() and not grinding:
			if abs(motion.x) > 1100:
				ap.play("Dash max")
			elif time_elapsed > 50 or abs(motion.x) > 500:
				ap.play("Dash")
			else:
				ap.play("run")
			if abs(motion.x) > 500:
				runsmoke()

# ============================================================
# ATTACHMENT
# ============================================================

func handle_attachment(delta: float) -> void:
	if hang_cooldown > 0:
		hang_cooldown -= delta


func _attach_to_flying_player(flying_player: Node2D) -> void:
	attached_to_entity = flying_player
	if flying_player.has_node("Marker2D"):
		follow_target            = flying_player.get_node("Marker2D")
		entity_attachment_offset = global_position - follow_target.global_position
	else:
		follow_target            = flying_player
		entity_attachment_offset = global_position - flying_player.global_position
	change_state(State.HANG)


func update_attachment_position() -> void:
	if current_state != State.HANG or not is_instance_valid(attached_to_entity):
		return
	if follow_target and is_instance_valid(follow_target):
		global_position = follow_target.global_position
	else:
		global_position = attached_to_entity.global_position + entity_attachment_offset
	velocity = Vector2.ZERO
	motion   = Vector2.ZERO


func _raycast_near_ground() -> bool:
	var space  = get_world_2d().direct_space_state
	var query  = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 50))
	query.exclude = [self]
	var result = space.intersect_ray(query)
	return result != null and result.has("position")

# ============================================================
# ITEM HANDLING
# ============================================================

func handle_item(delta: float) -> void:
	if item_pickup_cooldown > 0:
		item_pickup_cooldown -= delta
	if held_item and Input.is_action_just_pressed("trick"):
		drop_item()
		return
	if not held_item and Input.is_action_pressed("ui_up") and item_pickup_cooldown <= 0:
		var item = find_item_nearby()
		if item and current_state != State.HANG:
			pick_up_item(item)


func update_held_item_position() -> void:
	if not held_item or not is_instance_valid(held_item):
		return
	var offset = item_hold_offset
	offset.x   = abs(offset.x) * (-1 if sprite.flip_h else 1)
	held_item.global_position = global_position + offset
	if held_item.has_node("Sprite2D"):
		var item_sprite      = held_item.get_node("Sprite2D")
		item_sprite.rotation = sprite.rotation
		item_sprite.flip_h   = sprite.flip_h
	if held_item.get("velocity") != null:
		held_item.velocity = Vector2.ZERO
	if held_item.get("motion") != null:
		held_item.motion = Vector2.ZERO
	held_item.rotation = 0


func pick_up_item(item: Node2D) -> void:
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


func drop_item() -> void:
	throw_item()


func throw_item() -> void:
	if not held_item or not is_instance_valid(held_item):
		return
	var throw_direction := Vector2.ZERO
	var has_input       := false
	if Test.mobile and stickdir != Vector2.ZERO:
		throw_direction = stickdir.normalized()
		has_input = true
	elif abs(Input.get_joy_axis(0, 0)) > 0.5 or abs(Input.get_joy_axis(0, 1)) > 0.5:
		throw_direction = Vector2(Input.get_joy_axis(0, 0), Input.get_joy_axis(0, 1)).normalized()
		has_input = true
	else:
		throw_direction = Vector2(
			Input.get_axis("ui_left", "ui_right"),
			Input.get_axis("ui_down", "ui_up")
		)
		if throw_direction != Vector2.ZERO:
			throw_direction = throw_direction.normalized()
			has_input = true
	if not has_input:
		return
	var spin_dir = throw_direction
	if abs(spin_dir.x) < 0.05:
		spin_dir.x = 0.25
	spin_dir = spin_dir.normalized()
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
	var throw_power = 400 + abs(velocity.x)
	if abs(throw_direction.x) > 0:
		throw_power *= 1.5
	if not is_on_floor():
		motion.y += jump_velocity / 1.5
	held_item.velocity = Vector2.ZERO
	throw_direction.y  = -throw_direction.y
	held_item.velocity = throw_direction * throw_power
	if held_item.has_method("start_spinning"):
		held_item.start_spinning(spin_dir)
	if sfx:
		sfx.pitch_scale = 1.2
		sfx.stream      = sfx_sa113
		sfx.play()
	item_pickup_cooldown = 0.5
	held_item = null


func find_flying_player_nearby() -> Node2D:
	for area in $Hitbox.get_overlapping_areas():
		if area.is_in_group("Player") and Input.is_action_pressed("ui_up"):
			var pnode = area.get_parent()
			if pnode != self and pnode.get("flying"):
				return pnode
	return null


func find_item_nearby() -> Node2D:
	for area in $Hitbox.get_overlapping_areas():
		if area.is_in_group("item"):
			return area.get_parent()
	return null

# ============================================================
# BOOST / COMBAT / DAMAGE
# ============================================================

func ground_boost() -> void:
	if current_state == State.GROUND or current_state == State.BALL:
		change_state(State.BOOST)


func hurt() -> void:
	if current_state == State.HURT or invincible:
		return
	change_state(State.HURT)


func handle_hitbox() -> void:
	$Sprite2D.modulate.a = 0.5 if invincible else 1.0


func emit_rings() -> void:
	if Test.rings <= 0:
		return
	var loss: int = 0
	if Test.rings < 6:
		Test.rings = 0
	else:
		loss       = int(Test.rings / 2)
		Test.rings -= loss
	var spawn_count = clamp(int((Test.rings + loss) / 3), 0, 10)
	for _i in range(spawn_count):
		var ring             = ring_scene.instantiate()
		var angle            = randf_range(0, TAU)
		var speed            = randf_range(500, 1000)
		ring.scale           = Vector2(1.25, 1.25)
		ring.global_position = position
		ring.velocity        = Vector2.RIGHT.rotated(angle) * speed
		ring.loss            = true
		get_parent().add_child(ring)

# ============================================================
# TRICKS / AUDIO / VFX
# ============================================================

func tricknumber() -> void:
	if GlobalCanvasLayer.tricks > 5:  Test.trick = "good"
	if GlobalCanvasLayer.tricks > 10: Test.trick = "great"
	if GlobalCanvasLayer.tricks > 15: Test.trick = "awesome"
	if GlobalCanvasLayer.tricks > 20: Test.trick = "outstanding"
	if GlobalCanvasLayer.tricks > 30: Test.trick = "amazing"


func spinaudio() -> void:
	var clips       = [voice_spin1, voice_spin2, voice_spin3]
	voice.stream    = clips[randi() % clips.size()]
	sfx.stream      = sfx_trick
	sfx.pitch_scale = 2
	sfx.play()
	voice.play()


func runsmoke() -> void:
	var inst              = smokeground.instantiate()
	inst.position         = position
	inst.rotation_degrees = rot
	inst.flip_h           = velocity.x < 0
	get_parent().add_child(inst)
	await get_tree().create_timer(0.13).timeout


func smokeemit() -> void:
	var inst = smoke.instantiate()
	inst.position = position
	if velocity.y < 0:
		inst.rotation_degrees = 270
	inst.flip_h = velocity.x < 0
	get_parent().add_child(inst)


func sparkemit() -> void:
	var inst = sparkle.instantiate()
	inst.position = position
	get_parent().add_child(inst)

# ============================================================
# UTILITY
# ============================================================

func approach(current: float, target: float, speed: float) -> float:
	return min(current + speed, target) if current < target else max(current - speed, target)


func get_gravityy() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity


func is_coyote_time_active() -> bool:
	if has_jumped:
		return false
	var elapsed = Time.get_ticks_msec() / 1000.0 - last_grounded_time
	return elapsed < coyote_time and motion.y >= 0 and not was_on_floor


func switch_direction(new_direction: int) -> void:
	if new_direction != _prev_direction:
		ap.speed_scale *= -1
		_prev_direction = new_direction
	sprite.flip_h = new_direction == -1


func roll() -> void:
	if motion.x == 0 and not next_bounce:
		_set_ball(false)
	elif current_state == State.CROUCH:
		_set_ball(true)


func apply_spring_boost(velocity_boost: Vector2) -> void:
	motion = velocity_boost * (1.5 if bounce > 0 else 1.0)
	change_state(State.AIR)


func pick_upward_angle() -> float:
	var ranges = [
		Vector2(deg_to_rad(-45), deg_to_rad(45)),
		Vector2(deg_to_rad(45),  deg_to_rad(135))
	]
	var r = ranges[randi() % ranges.size()]
	return randf_range(r.x, r.y)


func attach_item(item: Node2D) -> void:
	var item_parent = item.get_parent()
	var grandparent = item_parent.get_parent()
	grandparent.remove_child(item_parent)
	add_child(item_parent)
	item_parent.position = Vector2.ZERO
	if item_parent.has_node("CollisionShape2D"):
		item_parent.get_node("CollisionShape2D").disabled = true
	if item_parent.has_method("set_physics_process"):
		item_parent.set_physics_process(false)


func _on_launch_finished() -> void:
	print("Spring path finished! Movement restored.")

# ============================================================
# STICK INPUT
# ============================================================

func handle_stick_input() -> void:
	var ev_up   = InputEventAction.new()
	var ev_down = InputEventAction.new()
	ev_up.action   = "ui_up"
	ev_down.action = "ui_down"
	if stickdir.y < 0:
		ev_up.pressed = true
		Input.parse_input_event(ev_up)
	elif stickdir.y > 0.5:
		ev_down.pressed = true
		Input.parse_input_event(ev_down)
	else:
		ev_up.pressed   = false
		ev_down.pressed = false
		Input.parse_input_event(ev_up)
		Input.parse_input_event(ev_down)

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_timer_timeout() -> void:
	max_speed = 1000


func _on_spin_timer_timeout() -> void:
	if _is_spinningdash:
		_is_spinningdash = false
		_is_spinning     = false
		sfx.pitch_scale  = 1
		control_lock     = false


func _on_wait_timer_timeout() -> void:
	wait = true
	ap.play("wait")


func _on_animation_player_current_animation_changed(name: String) -> void:
	if name == "stance":
		$WaitTimer.start()
	elif name != "wait":
		wait = false
		$WaitTimer.stop()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Revpeelout" and current_state == State.PEELOUT:
		ap.play("peel out")
		spin_charge    += 2
		_is_spinning    = true
		ap.speed_scale  = 0.8
		sfx.pitch_scale = min(spin_charge / 2.0, 2.0)
		sfx.stream      = sfx_rev
		sfx.play()


func _on_control_lock_timer_timeout() -> void:
	control_lock = false


func _on_coyote_timer_timeout() -> void:
	canjump = false


func _on_invincibity_timeout() -> void:
	invincible = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Rings") and not ouch:
		sfx.stream      = sfx_ring_pickup
		sfx.pitch_scale = 1
		sfx.play()
	if area.is_in_group("Spring") and is_player:
		tricknumber()
		GlobalCanvasLayer.tricks = 0
		Test.meter += 50
	if area.is_in_group("Rail"):
		grinding = true
		bounce   = 0
		can_dash = true
		dashed   = false
		motion.y = 0
		change_state(State.GRIND)
	if area.is_in_group("enemyattack"):
		hurt()


func _on_attackbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Enemy") and not is_on_floor():
		motion.y    = -1000 if time_elapsed >= 50 else -750
		Test.meter += 5


func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	$onscreentimer.stop()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	if not is_player:
		$onscreentimer.start()


func _on_onscreentimer_timeout() -> void:
	var cam = get_viewport().get_camera_2d()
	global_position = Vector2(cam.global_position.x, cam.global_position.y - 500)
