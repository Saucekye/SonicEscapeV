extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var defeat_flash_screen: ColorRect = $DefeatFlashScreen
@onready var flash_animation_player: AnimationPlayer = $DefeatFlashScreen/FlashAnimationPlayer
@onready var music: AudioStreamPlayer = $Music
@onready var action_timer: Timer = $ActionTimer
@onready var attack_spawn_marker: Marker2D = $AttackSpawnMarker

@export var positions : Array[Marker2D]
@export var attack1_projectile : PackedScene = preload("uid://pkgu0rai06d7")

# --- Projectile lifetime scaling ---
# At full health, projectiles live for base_projectile_lifetime seconds.
# At 0 health, projectiles live for max_projectile_lifetime seconds.
@export var base_projectile_lifetime : float = 3.0
@export var max_projectile_lifetime : float = 6.0

enum BossState {INTRO, IDLE, ATTACK_FOLLLOW, ATTACK_BARRAGE, DEAD}

var state = BossState.INTRO
var max_health = 40
var health = 40

var active_player: Node2D
var start = false

var prev_choice : int = 0
var new_pos : Vector2
var current_pos_idx : int = 0

var sprite_mat : ShaderMaterial

var velocity = Vector2.ZERO
var gravity = 900
var dying = false

# --- Attack1 cooldown tracking ---
var attack1_uses : int = 0
var attack1_locked : bool = false
var is_attacking : bool = false

# --- Move-lock tracking ---
# If the boss moves twice in a row, it must land an attack1 before it's
# allowed to move again. If attack1 is itself on cooldown when the lock
# kicks in, the boss instead has to sit idle for move_idle_duration seconds
# before the move lock clears.
var move_uses : int = 0
var move_locked : bool = false
@export var move_idle_duration : float = 1.5
var default_action_timer_wait : float = 0.0

# --- Movement re-entry guard ---
# Prevents move_behavior() from being triggered again (e.g. by the action
# timer firing mid-animation) before the current move has actually resolved
# via move_end_behavior(). Without this, current_pos_idx / new_pos can be
# overwritten mid-flight, causing the boss to appear to "teleport" oddly
# or skip its intended destination.
var is_moving : bool = false

# --- Idle float ---
var sprite_base_position : Vector2
var idle_float_time : float = 0.0
@export var idle_float_amplitude : float = 45.0
@export var idle_float_speed : float = 1.5

signal end
signal update_health_bar(boss_health : int, boss_max_health : int)	## Signal to emit to the boss hp bar UI element
signal boss_defeated

# --------------------------------------------------
# READY
# --------------------------------------------------

func _ready():
	sprite_mat = sprite.material
	defeat_flash_screen.visible = false
	global_position = positions[0].global_position
	current_pos_idx = 0
	sprite_base_position = sprite.position
	default_action_timer_wait = action_timer.wait_time

func _on_caine_start_goku_black() -> void:
	music.play()
	state = BossState.INTRO
	animation_player.play("intro")
	await animation_player.animation_finished
	state = BossState.IDLE
	animation_player.play("idle")
	GlobalSignals.disable_boss_ui.emit(false)
	
# --------------------------------------------------
# PROCESS
# --------------------------------------------------

func _process(delta):

	if state == BossState.DEAD:
		animation_player.stop()
		Engine.time_scale = 0.25

		velocity.y += gravity * delta
		sprite.global_position += velocity * delta
		sprite.rotation += 12 * delta

		await get_tree().create_timer(0.35, true).timeout
		Engine.time_scale = 1.0

		if sprite.global_position.y > 1500:
			emit_signal("end")
			queue_free()
		return

	if state == BossState.INTRO:
		return

	if _get_current_player():
		face_player()

	if state == BossState.IDLE:
		idle_float_time += delta
		sprite.position.x = sprite_base_position.x + sin(idle_float_time * idle_float_speed) * idle_float_amplitude
	else:
		sprite.position.x = sprite_base_position.x

	if health <= 0 and not dying:
		start_death()

func _get_current_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("Player")

	for player in players:
		if is_instance_valid(player) and player.get("is_player") == true:
			active_player = player
			return player

	return null
	
# --------------------------------------------------
# DO ATTACK
# --------------------------------------------------

# Wrapper function for when timer ends
func _on_action_timer_timeout() -> void:
	if is_attacking or is_moving:
		return
	_attack_choice()

func _attack_choice():
	if is_attacking or is_moving:
		return

	var choices = {"stay" : 0, "move" : 1, "attack_follow" : 2, "attack_barrage" : 3}
	var choice : int = int(randf_range(0, choices.size()))
	
	if prev_choice == choices.stay and choice == prev_choice:
		choice = choices.move
	if prev_choice == choices.move and choice == prev_choice:
		choice = choices.attack_barrage

	# If attack1 has been used twice in a row, lock it out and force a move instead
	if attack1_locked and (choice == choices.attack_follow or choice == choices.attack_barrage):
		choice = choices.move

	# If the boss has moved twice in a row, it must land an attack1 next.
	# If attack1 is itself cooling down, force an idle period instead.
	if move_locked and choice == choices.move:
		choice = choices.attack_follow if not attack1_locked else choices.stay

	prev_choice = choice
	
	if choice == choices.stay:
		if move_locked:
			_force_idle_period()
		return
	elif choice == choices.move:
		move_uses += 1
		if move_uses >= 2 and not move_locked:
			move_locked = true
		move_behavior()
	elif choice == choices.attack_follow:
		move_uses = 0
		move_locked = false
		_play_attack1()
	else:
		move_uses = 0
		move_locked = false
		return

func _force_idle_period() -> void:
	# Hold the boss idle for move_idle_duration seconds, then clear the move lock
	# and restore the normal action cadence.
	action_timer.stop()
	action_timer.wait_time = move_idle_duration
	action_timer.start()
	await action_timer.timeout
	move_uses = 0
	move_locked = false
	action_timer.wait_time = default_action_timer_wait

func _play_attack1() -> void:
	is_attacking = true
#	attack1_uses += 1
	animation_player.play("attack1")

#	if attack1_uses >= 2 and not attack1_locked:
#		attack1_locked = true
#		_start_attack1_cooldown()

func _start_attack1_cooldown() -> void:
	await get_tree().create_timer(2.0, true).timeout
	attack1_uses = 0
	attack1_locked = false

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack1":
		attack_behavior()
		animation_player.play("attack1end")
	if anim_name == "attack2":
		animation_player.play("attack2_2")
	if anim_name == "attack2":
		animation_player.play("attack1end")
	elif anim_name == "attack1end":
		is_attacking = false
		move_behavior()
	elif anim_name == "move":
		# Set position after move animation is completed
		move_end_behavior()
	elif anim_name == "move_end":
		animation_player.play("idle")
	elif anim_name == "intro":
		action_timer.start()

# --------------------------------------------------
# MOVE
# --------------------------------------------------

func move_behavior():
	# Guard against re-entry: if we're already mid-move, don't let a second
	# call (e.g. from the action timer, or from attack1end -> move_behavior)
	# stomp on the in-flight new_pos/current_pos_idx before move_end_behavior()
	# has had a chance to apply them.
	if is_moving:
		return
	is_moving = true

	animation_player.play("move")
	# Get new position (never the same marker we're currently at) and set it after the animation is finished
	if positions.size() <= 1:
		new_pos = positions[0].global_position
		return

	var new_pos_idx : int = current_pos_idx
	while new_pos_idx == current_pos_idx:
		new_pos_idx = int(randf_range(0, positions.size()))

	current_pos_idx = new_pos_idx
	new_pos = positions[new_pos_idx].global_position
	
func move_end_behavior():
	animation_player.play("move_end")
	global_position = new_pos
	is_moving = false
	
# --------------------------------------------------
# FACE PLAYER
# --------------------------------------------------

func face_player():
	sprite.flip_h = active_player.global_position.x < global_position.x

# --------------------------------------------------
# ATTACK 1
# --------------------------------------------------

func attack_behavior() -> void:
	var projecitle = attack1_projectile.instantiate()
	var health_pct : float = clamp(float(health) / float(max_health), 0.0, 1.0)
	var missing_pct : float = 1.0 - health_pct
	var lifetime : float = lerp(base_projectile_lifetime, max_projectile_lifetime, missing_pct)

	if "lifetime" in projecitle:
		projecitle.lifetime = lifetime
	self.get_parent().add_child(projecitle)
	projecitle.global_position = attack_spawn_marker.global_position
	if sprite.flip_h:
		projecitle.global_position.x = attack_spawn_marker.global_position.x - attack_spawn_marker.position.x

	# Scale the projectile's lifetime with how low the boss's health is.
	# Full health -> base_projectile_lifetime, zero health -> max_projectile_lifetime.
	
# --------------------------------------------------
# ATTACK 2
# --------------------------------------------------

func start_follow_attack() -> void:
	pass

# --------------------------------------------------
# FLASH
# --------------------------------------------------

func flash_sprite(duration: float = 0.1) -> void:
	sprite_mat.set_shader_parameter("flash_amount", 1.0)
	await get_tree().create_timer(duration).timeout
	sprite_mat.set_shader_parameter("flash_amount", 0.0)

# --------------------------------------------------
# HIT DETECTION
# --------------------------------------------------

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("item"):
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		area.get_parent().queue_free()
		take_damage()
	elif area.is_in_group("Playerattack"):
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		if area.is_in_group("Player"):
			area.get_parent().can_stomp = true
			area.get_parent().bounce = 0
		take_damage()

# --------------------------------------------------
# DAMAGE
# --------------------------------------------------

func take_damage(amount = 1):
	if state == BossState.DEAD:
		return
		
	$hitsfx.play()
	health -= amount
	
	if health <= 0:
		start_death()

# --------------------------------------------------
# DEATH
# --------------------------------------------------

func start_death():
	action_timer.stop()
	GlobalCanvasLayer.tricks += 10
	dying = true
	state = BossState.DEAD
	boss_defeated.emit()
	get_tree().call_group("EnemyProjectile", "queue_free")
	music.stop()
	animation_player.play("death")
	flash_animation_player.play("end")
	velocity.y = -600
	velocity.x = randf_range(-200, 200)
	# Reset attack1 tracking in case the boss instance gets reused
	attack1_uses = 0
	attack1_locked = false
	is_attacking = false
	is_moving = false
	action_timer.wait_time = default_action_timer_wait
	move_uses = 0
	move_locked = false
