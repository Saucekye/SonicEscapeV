extends Node2D

enum BossState {INTRO, IDLE, ATTACK1, ATTACK2, ATTACK3, DEAD}

var state = BossState.INTRO
var max_health: int 
var health: int
var begin = false
var attacking : bool = false

var active_player: CharacterBody2D
var axe_throw_position_x : float
const AXE_THROW_POSITION_X_OFFSET : float = -50

# Death physics
var velocity = Vector2.ZERO
var gravity = 900
var dying = false

# Signal to emit to the boss hp bar UI element
signal update_health_bar(boss_health : int, boss_max_health : int)
signal end

@export var position_1 : Marker2D
@export var position_2 : Marker2D
@export var axe_launch_marker : Marker2D

@onready var sprite = $Sprite2D
@onready var lightning_anim = $Node/LightningEffect/AnimationTree
@onready var timer = $ActionTimer
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial
@onready var hitsfx: AudioStreamPlayer = $hitsfx
@onready var flash_animation_player: AnimationPlayer = $DefeatFlashScreen/FlashAnimationPlayer
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var line_attack: CollisionShape2D = $HitBox/LineAttack
@onready var line_2d: Line2D = $Line2D

func _ready():
	max_health = min(50, max(15, Test.level * 2))
	health = max_health

func _start():
	randomize()
	anim.play("Intro")
	await anim.animation_finished
	anim.play("Idle")
	timer.start()
	begin = true
	GlobalSignals.disable_boss_ui.emit(false)

func _on_makima_intro_done() -> void:
	_start()

# --------------------------------------------------
# FIND ACTIVE PLAYER
# --------------------------------------------------
func _find_active_player() -> CharacterBody2D:
	# Use the group system - much more reliable!
	var players = get_tree().get_nodes_in_group("active_player")
	if players.size() > 0 and is_instance_valid(players[0]):
		return players[0]

	# Fallback: Check all CharacterBody2D nodes for is_player property
	var all_characters = get_tree().get_nodes_in_group("all_characters")
	for body in all_characters:
		if is_instance_valid(body) and "is_player" in body and body.is_player == true:
			return body

	return null

# --------------------------------------------------
# RESYNC ACTIVE PLAYER
# --------------------------------------------------
# Call this every frame (or right before using active_player after an
# await) so a mid-fight character switch is picked up immediately instead
# of the boss staying locked onto whichever character it started with.
func _resync_active_player() -> void:
	var current_player = _find_active_player()
	if current_player != null:
		active_player = current_player

func _process(delta):
	# Always resync with whoever is currently in the "active_player" group.
	_resync_active_player()

	match state:
		BossState.INTRO or BossState.IDLE:
			return
		BossState.ATTACK1:
			attack_line()
		BossState.ATTACK2:
			attack_axe_throw()
		BossState.DEAD:
			_death_physics(delta)

	if health <= 0 and not dying:
		start_death()
		
func flip(face_right : bool = true):
	self.scale.x = -1 if face_right else 1

func _on_action_timer_timeout() -> void:
	var randAttack : float = RandomNumberGenerator.new().randf()
	if randAttack > 0.5:
		state = BossState.ATTACK1
	else:
		state = BossState.ATTACK2
	anim.play("AttackTransition")
	await anim.animation_finished
		
# ---------------- ATTACKS ----------------
func attack_line():
	if dying or attacking:
		return
	attacking = true
	anim.play("Attack1to")
	await anim.animation_finished
	anim.play("Attack1")
	var wait_time : float = randf_range(1, 2)
	await get_tree().create_timer(wait_time).timeout
	anim.play("Attack1end")
	
func attack_line_create_collision() -> void:
	var attack_stall_time : float = 0.15
	var line_attack_duration : float = 0.3
	var line_scalar : float = 50
	var line_collision : SegmentShape2D = line_attack.shape
	# Set the points for the segment collision
	line_collision.a = Vector2.ZERO
	line_collision.b = line_attack.to_local(active_player.global_position) * line_scalar
	# Clear previous points and have the line visual match the collision
	line_2d.clear_points()
	line_2d.points = PackedVector2Array([line_collision.a, line_collision.b])
	await get_tree().create_timer(attack_stall_time).timeout
	line_attack.disabled = false
	line_2d.visible = true
	await get_tree().create_timer(line_attack_duration).timeout
	line_attack.disabled = true
	line_2d.visible = false
	
func attack_axe_throw():
	var attack_pos_x_offset : float = 50 
	attack_pos_x_offset *= -1 if self.scale.x > 0 else 1
	if dying or attacking:
		return
	attacking = true
	anim.play("Attack2to")
	await anim.animation_finished
	axe_throw_position_x = active_player.global_position.x + attack_pos_x_offset
	anim.play("Attack2part1")		
	var position_tween = get_tree().create_tween()
	position_tween.tween_property(self, "global_position:x", axe_throw_position_x, 0.5)
	await anim.animation_finished
	position_tween.stop()
	anim.play("Attack2part2")
	await anim.animation_finished
	anim.play("Attack2end")
		
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if dying:
		return
	if anim_name == "Attack1end" or anim_name == "Attack2end":
		state = BossState.IDLE
		anim.play_backwards("AttackTransition")
		attacking = false
	if anim_name == "AttackTransition":
		anim.play("Idle")
		timer.start()
		set_new_position()
		
func set_new_position() -> void:
	var rndm = RandomNumberGenerator.new()
	if rndm.randf() > 0.5:
		self.global_position.x = position_1.global_position.x
		flip(false)
	else:
		self.global_position.x = position_2.global_position.x	
		flip(true)
	
# ---------------- DEATH ----------------
func start_death():
	dying = true
	state = BossState.DEAD
	GlobalCanvasLayer.tricks += 10

	if not timer.is_stopped():
		timer.stop()

	# Stop music
	#$AudioStreamPlayer.stop()
	anim.play("Death")
	flash_animation_player.play("end")
	velocity.y = -600
	velocity.x = randf_range(-200,200)
	
func _death_physics(delta: float):
	anim.stop()
	Engine.time_scale = 0.25
	velocity.y += gravity * delta
	sprite.global_position += velocity * delta
	sprite.rotation += 12 * delta
	await get_tree().create_timer(0.35, true).timeout
	Engine.time_scale = 1.0

	if sprite.global_position.y > 1500:
		emit_signal("end")
		queue_free()

# ---------------- SPRITE FLASH ----------------
func flash_sprite(duration: float = 0.1) -> void:
	sprite_mat.set_shader_parameter("flash_amount", 1.0)
	await get_tree().create_timer(duration).timeout
	sprite_mat.set_shader_parameter("flash_amount", 0.0)
	hitsfx.play()
	
# --------------------------------------------------
# DAMAGE
# --------------------------------------------------
func take_damage(amount = 1):
	if state == BossState.DEAD:
		return
		
	hitsfx.play()
	health -= amount
	
	if health <= 0:
		start_death()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("item"):
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		area.get_parent().queue_free()
		take_damage()
	elif area.is_in_group("Playerattack"):
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		take_damage()
		if area.is_in_group("Player"):
			area.get_parent().can_stomp = true
			area.get_parent().bounce = 0
