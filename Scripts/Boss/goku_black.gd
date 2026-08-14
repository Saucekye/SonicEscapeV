extends Node2D

enum BossState {INTRO, IDLE, ATTACK_FOLLLOW, ATTACK_BARRAGE, DEAD}

var state = BossState.INTRO
var max_health = 30
var health = 30

var active_player: Node2D
var start = false

var next_attack = 0

var hover_offset = 0.0

var velocity = Vector2.ZERO
var gravity = 900
var dying = false

signal end
# Signal to emit to the boss hp bar UI element
signal update_health_bar(boss_health : int, boss_max_health : int)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var defeat_flash: ColorRect = $DefeatFlash
@onready var sprite: Sprite2D = $Sprite2D

var sprite_mat : ShaderMaterial

func _on_caine_start_goku_black() -> void:
	state = BossState.INTRO
	animation_player.play("intro")
	await animation_player.animation_finished
	state = BossState.IDLE
	animation_player.play("idle")
	GlobalSignals.disable_boss_ui.emit(false)
	start_attack_loop()

# --------------------------------------------------
# READY
# --------------------------------------------------

func _ready():
	sprite_mat = sprite.material
	defeat_flash.visible = false

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

	if active_player == null or not is_instance_valid(active_player):
		return

	if health <= 0 and not dying:
		start_death()

# --------------------------------------------------
# MAIN LOOP
# --------------------------------------------------

func start_attack_loop():

	while state != BossState.DEAD:

		if state != BossState.IDLE:
			await get_tree().process_frame
			continue

		await get_tree().create_timer(randf_range(1.5, 3)).timeout

		if next_attack == 0:
			await start_punch_attack()
			next_attack = 1
		else:
			await start_follow_attack()
			next_attack = 0
			
		if state != BossState.DEAD:
			state = BossState.IDLE

# --------------------------------------------------
# FLYING
# --------------------------------------------------

func fly_behavior(delta):
	pass

# --------------------------------------------------
# MOVE TO POSITION
# --------------------------------------------------

func move_to_position(target_pos: Vector2, speed: float) -> void:
	pass

# --------------------------------------------------
# FACE PLAYER
# --------------------------------------------------

func face_player():

	sprite.flip_h = active_player.global_position.x < global_position.x

# --------------------------------------------------
# ATTACK 1
# --------------------------------------------------

func start_punch_attack() -> void:
	pass

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
	$hitsfx.play()
	health -= 1

# --------------------------------------------------
# HIT DETECTION
# --------------------------------------------------

func _on_hitbox_area_entered(area: Area2D) -> void:

	if area.is_in_group("item"):
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		area.get_parent().queue_free()

	if area.is_in_group("Playerattack"):
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		if area.is_in_group("Player"):
			area.get_parent().can_stomp = true
			area.get_parent().bounce = 0


# --------------------------------------------------
# DAMAGE
# --------------------------------------------------

func take_damage(amount = 1):

	if state == BossState.DEAD:
		return

	health -= amount

	if health <= 0:
		start_death()

# --------------------------------------------------
# DEATH
# --------------------------------------------------

func start_death():
	GlobalCanvasLayer.tricks += 10
	dying = true
	state = BossState.DEAD
	$AudioStreamPlayer2.stop()
	animation_player.play("death")
	$TextureRect/AnimationPlayer.play("end")
	velocity.y = -600
	velocity.x = randf_range(-200, 200)
