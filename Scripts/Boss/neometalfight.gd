extends Node2D

enum BossState {IDLE, ATTACK1, ATTACK2, ATTACK3, DEAD}
signal end

var phase2_voice_played = false
var state = BossState.IDLE
var dash_direction = 0
var attackstaken = 0
var health = 70
var max_health = 70
var start = false
var begin = false

var active_player: Node2D

# Death physics
var velocity = Vector2.ZERO
var gravity = 900
var dying = false

# Count how many times Attack2 happens
var attack2_count = 0

@onready var sprite = $Sprite2D
@onready var anim = $Sprite2D/AnimationPlayer
@onready var lightning_anim = $Node/LightningEffect/AnimationTree
@onready var timer = $Timer
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial

@onready var attack1_markers = [
	$Marker2D1,
	$Marker2D2,
	$Marker2D3
]

@onready var attack2_markers = [
	$Marker2D1,
	$Marker2D2
]

@onready var attack3_markers = [
	$Marker2D6
]


func _start():
	randomize()
	timer.stop()
	anim.play("intro")
	lightning_anim.play("Left")
	await anim.animation_finished
	
	timer.start()
	begin = true


func _ready():
	self.process_mode = Node.PROCESS_MODE_DISABLED
	get_parent().get_node("CharacterBody2D").visible = false
	get_parent().get_node("CharacterBody2D").process_mode = Node.PROCESS_MODE_DISABLED

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
				if health > 30:
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
	
	$Sprite2D/CanvasLayer/ColorRect.queue_free()

	if not timer.is_stopped():
		timer.stop()

	anim.play("death")
	$AudioStreamPlayer.stop()
	
	$TextureRect/AnimationPlayer.play("end")

	velocity.y = -600
	velocity.x = randf_range(-200,200)



# ---------------- ATTACK 1 ----------------
func start_attack1():
	if health > 0:
		attack2_count = 0
		state = BossState.ATTACK1

		anim.play("transitontoattack")
		await anim.animation_finished

		var marker = attack1_markers.pick_random()
		sprite.global_position = marker.global_position

		anim.play("Attack")

		if marker == $Marker2D1:
			lightning_anim.play("Left")
		elif marker == $Marker2D2:
			lightning_anim.play("Right")
		elif marker == $Marker2D3:
			lightning_anim.play("Center")

		await anim.animation_finished

		state = BossState.IDLE
		anim.play("Idle")

		attackstaken = 0



# ---------------- ATTACK 2 ----------------
func start_attack2():
	if health > 0:
		attack2_count += 1
		state = BossState.ATTACK2

		var marker = attack2_markers.pick_random()
		sprite.global_position = marker.global_position
		
		if marker == $Marker2D1:
			$Sprite2D.flip_h = false
		elif marker == $Marker2D2:
			$Sprite2D.flip_h = true
			
		anim.play("Attack2")
		await anim.animation_finished

		anim.play("Attack2to")

		var tween = create_tween()

		if marker == $Marker2D1:
			dash_direction = 1
			tween.tween_property(sprite, "global_position:x", sprite.global_position.x + 750, 0.5)

		elif marker == $Marker2D2:
			dash_direction = -1
			tween.tween_property(sprite, "global_position:x", sprite.global_position.x - 750, 0.5)

		await tween.finished

		anim.play("Attack2end")

		var end_tween = create_tween()
		end_tween.tween_property(sprite, "global_position:x", sprite.global_position.x + (dash_direction * 120), 0.025)
		end_tween.set_ease(Tween.EASE_OUT)

		await anim.animation_finished

		state = BossState.IDLE
		anim.play("Idle")

		attackstaken = 0



# ---------------- ATTACK 3 ----------------
func start_attack3():
	if health > 0:
		timer.stop()
		if health > 30:
			start_attack1()
			return
			
		if health <= 30 and not phase2_voice_played:
			phase2_voice_played = true
			get_parent().get_node("CharacterBody2D").visible = true
			get_parent().get_node("CharacterBody2D").process_mode = Node.PROCESS_MODE_INHERIT

		state = BossState.ATTACK3

		var marker = attack3_markers.pick_random()
		sprite.global_position = marker.global_position

		anim.play("Attack3")
		await anim.animation_finished

		if active_player == null:
			state = BossState.IDLE
			anim.play("Idle")
			return

		var direction = (active_player.global_position - sprite.global_position).normalized()
		var target_position = sprite.global_position + direction * 900

		var tween = create_tween()
		tween.tween_property(sprite, "global_position", target_position, 0.35)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)

		await tween.finished

		start_attack1()



# ---------------- TIMER TRIGGER ----------------
func _on_timer_timeout():

	if attack2_count >= 2:
		start_attack1()
		return

	if health <= 30:
		var r = randi() % 3
		if r == 0:
			start_attack1()
		elif r == 1:
			start_attack2()
		else:
			start_attack3()
	else:
		var r = randi() % 2
		if r == 0:
			start_attack1()
		else:
			start_attack2()



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
		await flash_sprite()
		if area.is_in_group("Player"):
			area.get_parent().can_stomp = true
			area.get_parent().bounce = 0


		attackstaken += 1

		if attackstaken >= 3 and state == BossState.IDLE:

			attackstaken = 0

			if not timer.is_stopped():
				timer.stop()

			if attack2_count >= 2:
				start_attack1()
			else:

				if health <= 30:
					var r = randi() % 3
					if r == 0:
						start_attack1()
					elif r == 1:
						start_attack2()
					else:
						start_attack3()
				else:
					var r = randi() % 2
					if r == 0:
						start_attack1()
					else:
						start_attack2()



# ---------------- START BOSS ----------------
func _on_area_2d_area_entered(area: Area2D) -> void:

	if area.is_in_group("Player") and start == false:

		active_player = area.get_parent()

		start = true

		self.process_mode = Node.PROCESS_MODE_INHERIT

		_start()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	$Sprite2D/CanvasLayer/Sprite2D/AnimationPlayer.play("loop")
