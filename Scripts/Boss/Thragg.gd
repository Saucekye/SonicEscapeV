extends Node2D

enum BossState {INTRO, FLY, ATTACK_PUNCH, ATTACK_FOLLOW, DEAD}

var state = BossState.INTRO
var health = 40

var active_player: Node2D
var start = false

var next_attack = 0

var hover_offset = 0.0

var velocity = Vector2.ZERO
var gravity = 900
var dying = false

signal end

@onready var anim = $Sprite2D/AnimationPlayer
@onready var sprite = $Sprite2D
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial
@onready var fly_center: Node2D = get_parent().get_node("Marker2D")
@onready var attack1_markers = [
	get_parent().get_node("Marker2D2"),
	get_parent().get_node("Marker2D1")
]

# --------------------------------------------------
# READY
# --------------------------------------------------

func _ready():
	$TextureRect2.visible = false
	sprite_mat = sprite.material as ShaderMaterial

# --------------------------------------------------
# PROCESS
# --------------------------------------------------

func _process(delta):

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

	if state == BossState.INTRO:
		return

	if active_player == null or not is_instance_valid(active_player):
		return

	if state == BossState.FLY:
		fly_behavior(delta)

	if health <= 0 and not dying:
		start_death()

# --------------------------------------------------
# INTRO
# --------------------------------------------------

func start_intro():

	state = BossState.INTRO

	anim.play("intro")
	await anim.animation_finished

	anim.play("idle")

	state = BossState.FLY

	start_attack_loop()

# --------------------------------------------------
# MAIN LOOP
# --------------------------------------------------

func start_attack_loop():

	while state != BossState.DEAD:

		if state != BossState.FLY:
			await get_tree().process_frame
			continue

		await get_tree().create_timer(randf_range(1.5, 3)).timeout

		if state != BossState.FLY:
			continue

		if next_attack == 0:
			await start_punch_attack()
			next_attack = 1
		else:
			await start_follow_attack()
			next_attack = 0

		state = BossState.FLY

# --------------------------------------------------
# FLYING
# --------------------------------------------------

func fly_behavior(delta):

	if fly_center == null:
		return

	# -----------------------------
	# BASE CENTER (Marker2D)
	# -----------------------------
	var center = fly_center.global_position

	# -----------------------------
	# ORBIT MOTION
	# -----------------------------
	hover_offset += delta * 2.0

	var orbit_radius = 200.0

	var orbit_pos = center + Vector2(
		cos(hover_offset),
		sin(hover_offset)
	) * orbit_radius

	# -----------------------------
	# SLIGHT PLAYER INFLUENCE
	# -----------------------------
	var player_bias = Vector2.ZERO

	if active_player != null and is_instance_valid(active_player):
		player_bias = (active_player.global_position - center) * 0.2

	var target = orbit_pos + player_bias

	# -----------------------------
	# SMOOTH MOVE
	# -----------------------------
	global_position = global_position.lerp(target, delta * 2.5)

# --------------------------------------------------
# MOVE TO POSITION
# --------------------------------------------------

func move_to_position(target_pos: Vector2, speed: float) -> void:

	while global_position.distance_to(target_pos) > 5:

		global_position = global_position.move_toward(
			target_pos,
			speed * get_process_delta_time()
		)

		await get_tree().process_frame

# --------------------------------------------------
# FACE PLAYER
# --------------------------------------------------

func face_player():

	sprite.flip_h = active_player.global_position.x < global_position.x

# --------------------------------------------------
# ATTACK 1
# --------------------------------------------------

func start_punch_attack() -> void:

	state = BossState.ATTACK_PUNCH

	var marker = attack1_markers.pick_random()

	if marker == null:
		return

	await move_to_position(marker.global_position, 1000)

	if marker.name == "Marker2D2":
		sprite.flip_h = true
		$TextureRect2/AnimationPlayer.play("left")
	elif marker.name == "Marker2D1":
		sprite.flip_h = false
		$TextureRect2/AnimationPlayer.play("right")
	await get_tree().create_timer(0.15).timeout

	# --------------------------------------------------
	# attack1 START
	# --------------------------------------------------
	anim.play("attack1")
	await anim.animation_finished

	# --------------------------------------------------
	# attack1to (INTERRUPTIBLE + PLAYER SUCK)
	# --------------------------------------------------
	anim.play("attack1to")
	$TextureRect2.visible = true

	var t := 0.0
	var max_time := 2.0
	var cancel_distance := 160.0
	var pull_strength := 800.0

	while t < max_time:

		if active_player == null or not is_instance_valid(active_player):
			break

		var dist = global_position.distance_to(active_player.global_position)

		# 🔥 EARLY CANCEL CONDITION
		if dist <= cancel_distance:
			break

		# 🌀 SUCK PLAYER IN
		var pull_dir = (global_position - active_player.global_position).normalized()
		active_player.global_position += pull_dir * pull_strength * get_process_delta_time()

		t += get_process_delta_time()
		await get_tree().process_frame

	# --------------------------------------------------
	# attack1end (KEEP SUCKING UNTIL ANIMATION ENDS)
	# --------------------------------------------------
	anim.play("attack1end")

	while anim.is_playing():

		if active_player != null and is_instance_valid(active_player):
			var pull_dir = (global_position - active_player.global_position).normalized()
			active_player.global_position += pull_dir * pull_strength * get_process_delta_time()

		await get_tree().process_frame

	anim.play("idle")
	$TextureRect2.visible = false

# --------------------------------------------------
# ATTACK 2
# --------------------------------------------------

func start_follow_attack() -> void:

	state = BossState.ATTACK_FOLLOW

	if active_player == null or not is_instance_valid(active_player):
		return

	anim.play("attack2")

	var rush_time = 0.785
	var t = 0.0

	while t < rush_time:

		global_position = global_position.move_toward(
			active_player.global_position,
			1200 * get_process_delta_time()
		)

		t += get_process_delta_time()
		await get_tree().process_frame

	var locked_pos = global_position

	while anim.is_playing():

		global_position = locked_pos
		face_player()

		await get_tree().process_frame

	anim.play("idle")
	state = BossState.FLY

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
		await flash_sprite()
		area.get_parent().queue_free()

	if area.is_in_group("Playerattack"):
		await flash_sprite()
		if area.is_in_group("Player"):
			area.get_parent().can_stomp = true
			area.get_parent().bounce = 0

# --------------------------------------------------
# PLAYER DETECTION
# --------------------------------------------------

func _on_area_2d_area_entered(area: Area2D):

	if area.is_in_group("Player") and start == false:
		active_player = area.get_parent()
		start = true
		start_intro()

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

	dying = true
	state = BossState.DEAD
	$AudioStreamPlayer2.stop()
	anim.play("death")
	$TextureRect/AnimationPlayer.play("end")
	velocity.y = -600
	velocity.x = randf_range(-200, 200)
