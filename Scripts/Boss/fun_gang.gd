extends Node2D

enum BossState {INTRO, IDLE, ATTACK1, ATTACK2, ATTACK3, DEAD}

var state = BossState.INTRO
var max_health: int 
var health: int
var begin = false

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


func _ready():
	max_health = min(50, max(10, Test.level * 2))
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
	
	face_player()

	match state:
		BossState.INTRO or BossState.IDLE:
			return
		BossState.ATTACK1:
			attack_axe_throw(delta)
		BossState.ATTACK2:
			attack_axe_throw(delta)
		BossState.DEAD:
			_death_physics(delta)

	if health <= 0 and not dying:
		start_death()
		
func face_player():
	if state == BossState.IDLE:
		sprite.flip_h = active_player.global_position.x < global_position.x

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
	pass
	
func attack_axe_throw(delta : float):
	const AXE_THR0W_SPEED_SCALAR : float = 10.0
	const AXE_FALL_SPEED_SCALAR : float = 10.0
	if dying:
		return
	elif anim.current_animation == "AttackTransition":
		anim.play("Attack2to")
		axe_throw_position_x = active_player.global_position.x
	#elif anim.current_animation == "Attack2part1":
		#self.global_position.x += delta * (self.global_position.y - axe_launch_marker.global_position.y)
		#self.global_position.y += delta * (self.global_position.x - axe_throw_position_x)
		#if self.global_position.y <= axe_launch_marker.global_position.y:
		#print(self.global_position)
		#print(axe_launch_marker.global_position.y)
		#print(axe_throw_position_x)
		
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Attack2to":
		anim.play("Attack2part1")
		var position_tween = get_tree().create_tween()
		var offset_flip = 1 if sprite.flip_h else -1
		position_tween.tween_property(self, "global_position", Vector2(axe_throw_position_x - (AXE_THROW_POSITION_X_OFFSET * offset_flip), axe_launch_marker.global_position.y), 1)
		await position_tween.finished
		anim.play("Attack2part2")
		
	
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
