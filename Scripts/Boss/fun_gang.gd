
extends Node2D

enum BossState {INTRO, IDLE, ATTACK1, ATTACK2, ATTACK3, DEAD}

var state = BossState.INTRO
var max_health: int
var health: int
var begin = false
var attacking: bool = false

var active_player: CharacterBody2D
var axe_throw_position_x: float

# Heart projectile
const HEART_SCENE = preload("res://Scenes/Boss/Heart.tscn")
var heart_active: bool = false
var active_heart: Node2D = null

# Idle after the intro, before the first attack
const IDLE_AFTER_INTRO_TIME: float = 2.0

# Axe slam tuning
const AXE_TRACK_SPEED: float = 700.0
const AXE_LOCK_TIME: float = 0.2
const AXE_X_OFFSET: float = -130.0

# Axe x tracking state
var axe_hold_x: bool = false
var axe_chase_x: bool = false
var axe_x: float

# Death physics
var velocity = Vector2.ZERO
var gravity = 900
var dying = false

# Signals
signal update_health_bar(boss_health: int, boss_max_health: int)
signal end

@export var position_1: Marker2D
@export var position_2: Marker2D
@export var axe_launch_marker: Marker2D

@onready var sprite = $Sprite2D
@onready var lightning_anim = $Node/LightningEffect/AnimationTree
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial
@onready var hitsfx: AudioStreamPlayer = $hitsfx
@onready var flash_animation_player: AnimationPlayer = $DefeatFlashScreen/FlashAnimationPlayer
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var line_attack: CollisionShape2D = $HitBox/LineAttack
@onready var line_2d: Line2D = $Line2D


func _ready():
	max_health = min(50, max(20, Test.level * 2))
	health = max_health
	process_priority = 100


# --------------------------------------------------
# HEART PROJECTILE
# --------------------------------------------------

func spawn_heart() -> void:
	if dying or heart_active:
		return

	var heart = HEART_SCENE.instantiate()

	active_heart = heart
	heart_active = true

	heart.tree_exited.connect(_on_heart_removed)

	get_tree().current_scene.add_child(heart)
	heart.global_position = global_position


func _on_heart_removed() -> void:
	heart_active = false
	active_heart = null


func remove_heart() -> void:
	if is_instance_valid(active_heart):
		active_heart.queue_free()

	active_heart = null
	heart_active = false


# --------------------------------------------------
# INTRO
# --------------------------------------------------

func _start():
	randomize()
	anim.play("Intro")
	$AudioStreamPlayer.play()

	await anim.animation_finished

	if dying:
		return

	begin = true
	GlobalSignals.disable_boss_ui.emit(false)

	state = BossState.IDLE
	anim.play("Idle")

	await get_tree().create_timer(IDLE_AFTER_INTRO_TIME).timeout

	if dying:
		return

	state = BossState.ATTACK1


func _on_makima_intro_done() -> void:
	_start()


# --------------------------------------------------
# FIND ACTIVE PLAYER
# --------------------------------------------------

func _find_active_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("active_player")

	if players.size() > 0 and is_instance_valid(players[0]):
		return players[0]

	var all_characters = get_tree().get_nodes_in_group("all_characters")

	for body in all_characters:
		if is_instance_valid(body) and "is_player" in body and body.is_player == true:
			return body

	return null


# --------------------------------------------------
# RESYNC ACTIVE PLAYER
# --------------------------------------------------

func _resync_active_player() -> void:
	var current_player = _find_active_player()

	if current_player != null:
		active_player = current_player


func _process(delta):
	_resync_active_player()

	# Axe x tracking
	if axe_hold_x:
		if axe_chase_x and active_player != null:
			var target_x: float = active_player.global_position.x + AXE_X_OFFSET * sign(scale.x)
			axe_x = move_toward(axe_x, target_x, AXE_TRACK_SPEED * delta)

		global_position.x = axe_x

	match state:
		BossState.INTRO, BossState.IDLE:
			return

		BossState.ATTACK1:
			attack_line()

		BossState.ATTACK2:
			attack_axe_throw()

		BossState.DEAD:
			_death_physics(delta)

	if health <= 0 and not dying:
		start_death()


func flip(face_right: bool = true):
	self.scale.x = -1 if face_right else 1


func _on_action_timer_timeout() -> void:
	pass


# --------------------------------------------------
# ATTACKS
# --------------------------------------------------

func attack_line():
	if dying or attacking:
		return

	attacking = true

	anim.play("Attack1to")
	await anim.animation_finished

	if dying:
		return

	anim.play("Attack1")

	var wait_time: float = randf_range(1.5, 2.0)
	await get_tree().create_timer(wait_time).timeout

	if dying:
		return

	anim.play("Attack1end")


func attack_line_create_collision() -> void:
	if dying or active_player == null:
		return

	var attack_stall_time: float = 0.1
	var line_attack_duration: float = 0.1
	var line_scalar: float = 50.0

	var line_collision: SegmentShape2D = line_attack.shape

	line_collision.a = Vector2.ZERO
	line_collision.b = line_attack.to_local(active_player.global_position) * line_scalar

	line_2d.clear_points()
	line_2d.points = PackedVector2Array([
		line_collision.a,
		line_collision.b
	])

	await get_tree().create_timer(attack_stall_time).timeout

	if dying:
		return

	line_attack.disabled = false
	line_2d.visible = true

	await get_tree().create_timer(line_attack_duration).timeout

	line_attack.disabled = true
	line_2d.visible = false


func attack_axe_throw():
	if dying or attacking:
		return

	attacking = true

	anim.play("Attack2to")
	await anim.animation_finished

	if dying:
		return

	axe_x = global_position.x
	axe_hold_x = true
	axe_chase_x = true

	anim.play("Attack2part1")

	while anim.is_playing() and anim.current_animation == "Attack2part1" and not dying:
		var time_left: float = anim.current_animation_length - anim.current_animation_position
		axe_chase_x = time_left > AXE_LOCK_TIME
		await get_tree().process_frame

	axe_chase_x = false

	if dying:
		axe_hold_x = false
		return

	anim.play("Attack2part2")
	await anim.animation_finished

	if dying:
		axe_hold_x = false
		return

	anim.play("Attack2end")


# --------------------------------------------------
# ATTACK CHAIN
# --------------------------------------------------

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if dying:
		return

	if anim_name == "Attack1end":
		set_new_position()
		attacking = false
		state = BossState.ATTACK2

	elif anim_name == "Attack2end":
		axe_hold_x = false
		set_new_position()
		attacking = false
		state = BossState.ATTACK1


func set_new_position() -> void:
	if position_1 == null or position_2 == null:
		return

	if randf() > 0.5:
		global_position.x = position_1.global_position.x
		flip(false)
	else:
		global_position.x = position_2.global_position.x
		flip(true)


# --------------------------------------------------
# DEATH
# --------------------------------------------------

func start_death():
	if dying:
		return

	dying = true

	# Remove the active Heart as soon as the boss starts dying.
	remove_heart()

	axe_hold_x = false
	axe_chase_x = false
	state = BossState.DEAD

	GlobalCanvasLayer.tricks += 10

	$AudioStreamPlayer.stop()

	anim.play("Death")
	flash_animation_player.play("end")

	velocity.y = -600
	velocity.x = randf_range(-200, 200)


func _death_physics(delta: float):
	anim.stop()
	Engine.time_scale = 0.25

	velocity.y += gravity * delta
	sprite.global_position += velocity * delta
	sprite.rotation += 12 * delta

	await get_tree().create_timer(0.35, true).timeout
	Engine.time_scale = 1.0

	if not is_instance_valid(sprite):
		return

	if sprite.global_position.y > 1500:
		emit_signal("end")
		queue_free()


# --------------------------------------------------
# SPRITE FLASH
# --------------------------------------------------

func flash_sprite(duration: float = 0.1) -> void:
	if sprite_mat == null:
		return

	sprite_mat.set_shader_parameter("flash_amount", 1.0)

	await get_tree().create_timer(duration).timeout

	if not is_instance_valid(self) or dying:
		return

	sprite_mat.set_shader_parameter("flash_amount", 0.0)
	hitsfx.play()


# --------------------------------------------------
# DAMAGE
# --------------------------------------------------

func take_damage(amount = 1):
	if dying or state == BossState.DEAD:
		return

	hitsfx.play()
	health -= amount
	update_health_bar.emit(max(health, 0), max_health)

	if health <= 0:
		start_death()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dying:
		return

	if area.is_in_group("item"):
		await flash_sprite()

		if dying:
			return

		if is_instance_valid(area) and is_instance_valid(area.get_parent()):
			area.get_parent().queue_free()

		take_damage()
		spawn_heart()

	elif area.is_in_group("Playerattack"):
		await flash_sprite()

		if dying:
			return

		take_damage()
		spawn_heart()

		if area.is_in_group("Player"):
			var player = area.get_parent()

			if is_instance_valid(player):
				player.can_stomp = true
				player.bounce = 0
