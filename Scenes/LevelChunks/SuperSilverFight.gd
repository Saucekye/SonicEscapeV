extends Node2D

enum BossState {INTRO, FLY, ATTACK1, ATTACK2, ATTACK3, ATTACK4, FALLING, PHASE2TRANSITION, DEAD}
signal end
signal dialogue2
signal lunara
signal over

var phase2_voice_played = false
var state = BossState.INTRO
var dash_direction = 0
var attackstaken = 0
var next_attack = 0
var health = 50
var max_health = 50
var start = false
var begin = false

var active_player: Node2D

# Death / fall physics
var velocity = Vector2.ZERO
var gravity = 900
var dying = false

# Count how many times Attack2 happens
var attack2_count = 0
var hover_offset = 0.0

# Hit debounce (prevents multiple hitboxes/frames stacking damage from one hit)
var hit_cooldown = 0.0
const HIT_COOLDOWN_TIME = 0.1
var phase = 1

# Signal to emit to the boss hp bar UI element
signal update_health_bar(boss_health : int, boss_max_health : int)
signal playcutscene
signal dialogue

@onready var sprite = $Sprite2D
@onready var anim = $Sprite2D/AnimationPlayer
@onready var lightning_anim = $Node/LightningEffect/AnimationTree
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial

@onready var fly_center: Node2D = get_parent().get_node("Marker2D")

@onready var attack1_markers = [
	get_parent().get_node("Marker2D1"),
	get_parent().get_node("Marker2D2")
]

@onready var attack2_markers = [
	get_parent().get_node("Marker2D1"),
	get_parent().get_node("Marker2D2")
]

@onready var attack3_markers = [
	get_parent().get_node("Marker2D3")
]

func _start():
	randomize()
	anim.play("introto1")
	await anim.animation_finished
	anim.play("introto1_2")
	get_parent().get_node("AnimatedSprite2D").visible = true
	emit_signal("playcutscene")
	emit_signal("dialogue")
	await get_tree().create_timer(40).timeout
	anim.play("intro_2")
	await anim.animation_finished
	anim.play("intro_3")
	await get_tree().create_timer(7).timeout
	anim.play("intro_4")
	await anim.animation_finished
	anim.play("intro_5")
	await get_tree().create_timer(3.5).timeout
	anim.play("intro_6")
	await anim.animation_finished
	anim.play("Idle")
	$Sprite2D.z_index = -1
	state = BossState.FLY
	GlobalSignals.disable_boss_ui.emit(false)
	start_attack_loop()

	begin = true

func _ready():
	$TextureRect2.visible = false
	$TextureRect3.visible = false
	sprite_mat = sprite.material as ShaderMaterial
	anim.play("intro")
	get_parent().get_node("AnimatedSprite2D").visible = false

# --------------------------------------------------
# PROCESS
# --------------------------------------------------

func _process(delta):
	if start:
		if state == BossState.DEAD:
			anim.stop()
			Engine.time_scale = 0.25

			velocity.y += gravity * delta
			sprite.global_position += velocity * delta
			sprite.rotation += 12 * delta

			await get_tree().create_timer(0.35, true).timeout
			Engine.time_scale = 1.0
			
			if sprite.global_position.y > get_viewport_rect().size.y + 200:
				await get_tree().create_timer(3).timeout
				GlobalSignals.emit_signal("complete")
			return

		if state == BossState.FALLING:
			anim.stop()
			Engine.time_scale = 0.25

			velocity.y += gravity * delta
			sprite.global_position += velocity * delta
			sprite.rotation += 12 * delta

			if sprite.global_position.y > get_viewport_rect().size.y + 200:
				Engine.time_scale = 1.0
				$Sprite2D/HitBox.monitorable = false
				$Sprite2D/HitBox.monitoring = false
				start_phase2()
				return

			await get_tree().create_timer(0.35, true).timeout
			Engine.time_scale = 1.0

			return

		if state == BossState.INTRO or state == BossState.PHASE2TRANSITION:
			return

		if active_player == null or not is_instance_valid(active_player):
			return

		if state == BossState.FLY:
			fly_behavior(delta)

# --------------------------------------------------
# MAIN LOOP
# --------------------------------------------------

func start_attack_loop():

	while state != BossState.DEAD or BossState.FALLING:

		if state != BossState.FLY:
			await get_tree().process_frame
			continue

		var wait_time = randf_range(3, 4) if phase == 1 else randf_range(1.5, 2.5)
		await get_tree().create_timer(wait_time).timeout

		if state != BossState.FLY:
			continue

		if phase == 1:
			if next_attack == 0:
				await start_punch_attack()
				next_attack = 1
			elif next_attack == 1:
				await start_attack2()
				next_attack = 2
			else:
				await start_follow_attack()
				next_attack = 0
		else:
			if next_attack == 0:
				await start_punch_attack()
				next_attack = 1
			elif next_attack == 1:
				await start_attack2()
				next_attack = 2
			elif next_attack == 2:
				await start_attack3()
				next_attack = 0
			else:
				await start_follow_attack()
				next_attack = 0

		if state != BossState.DEAD:
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

	state = BossState.ATTACK1

	var marker = attack1_markers.pick_random()

	if marker == null:
		return

	await move_to_position(marker.global_position, 1000)

	if marker.name == "Marker2D2":
		sprite.flip_h = true
		$TextureRect2/AnimationPlayer.play("right")
	elif marker.name == "Marker2D1":
		sprite.flip_h = false
		$TextureRect2/AnimationPlayer.play("left")
	await get_tree().create_timer(0.15).timeout

	# --------------------------------------------------
	# attack1 START
	# --------------------------------------------------
	anim.play("Attack1")
	await anim.animation_finished

	# --------------------------------------------------
	# attack1to (INTERRUPTIBLE + PLAYER SUCK)
	# --------------------------------------------------
	if state == BossState.FALLING or state == BossState.DEAD:
		return

	anim.play("Attack1to")
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
	anim.play("Attack1end")

	while anim.is_playing():

		if active_player != null and is_instance_valid(active_player):
			var pull_dir = (global_position - active_player.global_position).normalized()
			active_player.global_position += pull_dir * pull_strength * get_process_delta_time()

			await get_tree().process_frame

		# If boss falls/dies while the sucking animation is happening, bail out
		if state == BossState.FALLING or state == BossState.DEAD:
			return

	anim.play("Idle")
	$TextureRect2.visible = false

# --------------------------------------------------
# ATTACK 4
# --------------------------------------------------

func start_follow_attack() -> void:

	state = BossState.ATTACK4

	if active_player == null or not is_instance_valid(active_player):
		return

	anim.play("Attack4")

	var rush_time = 2.65
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

	anim.play("Idle")
	state = BossState.FLY

# --------------------------------------------------
# ATTACK 2
# --------------------------------------------------

func start_attack2():
	if health > 0:
		attack2_count += 1
		state = BossState.ATTACK2

		var marker = attack2_markers.pick_random()
		self.global_position = marker.global_position

		if marker.name == "Marker2D1":
			$Sprite2D.flip_h = false
		elif marker.name == "Marker2D2":
			$Sprite2D.flip_h = true

		anim.play("Attack2")
		await anim.animation_finished

		anim.play("Attack2to")

		var tween = create_tween()

		if marker.name == "Marker2D1":
			dash_direction = 1
			tween.tween_property(self, "global_position:x", self.global_position.x + 550, 0.45)

		elif marker.name == "Marker2D2":
			dash_direction = -1
			tween.tween_property(self, "global_position:x", self.global_position.x - 550, 0.45)

		await tween.finished

		anim.play("Attack2end")

		var end_tween = create_tween()
		end_tween.tween_property(self, "global_position:x", self.global_position.x + (dash_direction * 120), 0.025)
		end_tween.set_ease(Tween.EASE_OUT)

		await anim.animation_finished

		state = BossState.FLY
		if dying == false:
			anim.play("Idle")

		attackstaken = 0

# --------------------------------------------------
# ATTACK 3 (Phase 2 only)
# --------------------------------------------------

func start_attack3() -> void:

	state = BossState.ATTACK3
	
	var marker = attack3_markers.pick_random()
	if marker == null:
		return
	
	await move_to_position(marker.global_position, 1000)
	face_player()
	
	anim.play("Attack3")  # swap to your actual animation name
	$Sprite2D.visible = true
	$TextureRect3.visible = true
	await get_tree().create_timer(3.3).timeout
	
	if active_player == null:
		state = BossState.FLY
		anim.play("Idle")
		return

	var direction = (active_player.global_position - self.global_position).normalized()
	var target_position = self.global_position + direction * 900

	var tween = create_tween()
	tween.tween_property(self, "global_position", target_position, 0.35)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	await tween.finished

	anim.play("Idle")
	state = BossState.FLY
	start_attack_loop()
# --------------------------------------------------
# FLASH
# --------------------------------------------------

func flash_sprite(duration: float = 0.1) -> void:

	sprite_mat.set_shader_parameter("flash_amount", 1.0)

	await get_tree().create_timer(duration).timeout

	sprite_mat.set_shader_parameter("flash_amount", 0.0)
	$hitsfx.play()
	health -= 1

	if health <= 0:
		if phase == 1:
			start_fall_phase1()
		else:
			emit_signal("over")
			start_death()

# --------------------------------------------------
# PLAYER DETECTION
# --------------------------------------------------

func _on_area_2d_area_entered(area: Area2D):

	if area.is_in_group("Player") and start == false:
		active_player = area.get_parent()
		start = true
		_start()

# --------------------------------------------------
# DAMAGE
# --------------------------------------------------

func take_damage(amount = 1):

	if state == BossState.DEAD or state == BossState.FALLING or state == BossState.PHASE2TRANSITION:
		return

	health -= amount

	if health <= 0:
		if phase == 1:
			start_fall_phase1()
		else:
			start_death()

# --------------------------------------------------
# PHASE 1 "DEATH" -> FALL OFFSCREEN -> PHASE 2
# --------------------------------------------------

func start_fall_phase1() -> void:
	GlobalCanvasLayer.tricks = 10
	anim.play("death")
	state = BossState.FALLING
	anim.stop()
	$AudioStreamPlayer.stop()
	velocity.y = -600
	#velocity.x = randf_range(-200, 200)

# --------------------------------------------------
# PHASE 2 TRANSITION
# --------------------------------------------------

func start_phase2() -> void:
	state = BossState.PHASE2TRANSITION
	sprite.visible = false
	
	await get_tree().create_timer(5).timeout
	if not phase2_voice_played:
		phase2_voice_played = true
		emit_signal("dialogue2")
	
	phase = 2
	health = 75

	
	await get_tree().create_timer(9).timeout
	update_health_bar.emit(health, 75)
	var display = get_parent().get_node("BossHPDisplay")
	display._set_new_boss(self, "LunaraNoctis")
	($TextureRect2.material as ShaderMaterial).set_shader_parameter("base_rain_speed", 1.0) 
	velocity.y = 0
	sprite.position = Vector2.ZERO
	$Sprite2D/HitBox.monitorable = false
	$Sprite2D/HitBox.monitoring = false
	sprite.rotation = 0
	sprite.visible = false
	
	start_attack3()
	await get_tree().create_timer(14).timeout
	emit_signal("lunara")

# --------------------------------------------------
# REAL DEATH (Phase 2 only)
# --------------------------------------------------

func start_death():
	GlobalCanvasLayer.tricks = 10
	dying = true
	state = BossState.DEAD
	$AudioStreamPlayer.stop()
	anim.play("death")
	
	get_parent().get_node("TextureRect/AnimationPlayer").play("end")
	velocity.y = -600
	velocity.x = randf_range(-200, 200)


func _on_hit_box_area_entered(area: Area2D) -> void:
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


func _on_animated_sprite_2d_music() -> void:
	$AudioStreamPlayer.play()


func _on_animated_sprite_2d_music_2() -> void:
	$AudioStreamPlayer.stream = load("res://Music/Boss/Super Silver/FINAL(2).MP3")
	$AudioStreamPlayer.volume_db = -5
	$AudioStreamPlayer.play()
