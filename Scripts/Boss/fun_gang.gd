extends Node2D

enum BossState {IDLE, ATTACK1, ATTACK2, ATTACK3, DEAD}
signal end

var phase2_voice_played = false
var state = BossState.IDLE
var dash_direction = 0
var attackstaken = 0
var max_health: int 
var health: int
var start = false
var begin = false

var active_player: CharacterBody2D

# Death physics
var velocity = Vector2.ZERO
var gravity = 900
var dying = false

# Count how many times Attack2 happens
var attack2_count = 0

# Signal to emit to the boss hp bar UI element
signal update_health_bar(boss_health : int, boss_max_health : int)

@onready var sprite = $Sprite2D
@onready var anim = $Sprite2D/AnimationPlayer
@onready var lightning_anim = $Node/LightningEffect/AnimationTree
@onready var timer = $ActionTimer
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial

func _start():
	randomize()
	timer.stop()
	anim.play("intro")
	await anim.animation_finished
	GlobalSignals.disable_boss_ui.emit(false)
	timer.start()
	begin = true

func _ready():
	self.process_mode = Node.PROCESS_MODE_DISABLED
	max_health = min(50, max(8, Test.level * 2))
	health = max_health
	
func _on_makima_start_battle(body: Node2D) -> void:
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
	# ---------------- DEATH PHYSICS ----------------
	if state == BossState.DEAD:
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
		return
	# ------------------------------------------------

	# Always resync with whoever is currently in the "active_player" group.
	_resync_active_player()

	# -------- SPEED BASED ON HEALTH --------
	var health_ratio = clamp(health / float(max_health), 0.0, 1.0)
	var target_speed = lerp(1.5, 1.0, health_ratio)
	
	if state != BossState.ATTACK3:
		anim.speed_scale = lerp(anim.speed_scale, target_speed, delta * 3)
	else:
		anim.speed_scale = 1.0

	lightning_anim.speed_scale = lerp(lightning_anim.speed_scale, target_speed, delta * 3)
	# ---------------------------------------

	match state:

		BossState.IDLE:
			if timer.is_stopped():
				if health > (max_health/2):
					timer.start(randf_range(4,4))
				else:
					timer.start(randf_range(2,2))
					

		BossState.ATTACK1:
			pass

		BossState.ATTACK2:
			pass

		BossState.ATTACK3:
			pass


	if health <= 0 and not dying:
		start_death()



# ---------------- DEATH ----------------
func start_death():

	dying = true
	state = BossState.DEAD
	GlobalCanvasLayer.tricks += 10
	$Sprite2D/CanvasLayer/ColorRect.queue_free()

	if not timer.is_stopped():
		timer.stop()

	anim.play("death")
	$AudioStreamPlayer.stop()
	
	$TextureRect/AnimationPlayer.play("end")

	velocity.y = -600
	velocity.x = randf_range(-200,200)





# ---------------- SPRITE FLASH ----------------
func flash_sprite(duration: float = 0.1) -> void:

	sprite_mat.set_shader_parameter("flash_amount", 1.0)

	await get_tree().create_timer(duration).timeout

	sprite_mat.set_shader_parameter("flash_amount", 0.0)

	$hitsfx.play()
	health -= 1


# ---------------- HITBOX ----------------
func _on_hit_box_area_entered(area: Area2D) -> void:

	if area.is_in_group("Playerattack") and begin == true:
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		if area.is_in_group("Player"):
			area.get_parent().can_stomp = true
			area.get_parent().bounce = 0


		attackstaken += 1

		if attackstaken >= 3 and state == BossState.IDLE:

			attackstaken = 0

			if not timer.is_stopped():
				timer.stop()
