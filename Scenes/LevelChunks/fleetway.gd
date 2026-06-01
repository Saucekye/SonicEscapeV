extends Node2D

enum BossState {INTRO, IDLE, FLY, ATTACK, DEAD}

var state = BossState.INTRO
var health = 30

var dying = false
var attacking = false

# Phase 2
var phase2 = false

# Allow flight movement
var can_fly = true

signal end

@onready var anim = $Sprite2D/AnimationPlayer
@onready var sprite = $Sprite2D
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial

@onready var marker: Node2D = get_parent().get_node("Marker2D3")

# --------------------------------------------------
# DEATH PHYSICS
# --------------------------------------------------

var death_velocity := Vector2.ZERO
var gravity := 900

# --------------------------------------------------
# FLY VARIABLES
# --------------------------------------------------

var hover_offset = 0.0

# --------------------------------------------------
# READY
# --------------------------------------------------

func _ready():
	randomize()

# --------------------------------------------------
# GET CURRENT PLAYER (IMPORTANT)
# --------------------------------------------------

func _get_current_player() -> Node2D:

	var players = get_tree().get_nodes_in_group("Player")

	for p in players:

		if is_instance_valid(p) and p.get("is_player") == true:
			return p

	return null

# --------------------------------------------------
# PROCESS
# --------------------------------------------------

func _process(delta):

	# PHASE 2 FLIGHT (ALWAYS FOLLOWS CURRENT PLAYER)
	if phase2 and can_fly and state != BossState.DEAD:
		fly_behavior(delta)

	# DEATH
	if state == BossState.DEAD:

		death_velocity.y += gravity * delta
		global_position += death_velocity * delta
		sprite.rotation += 8 * delta

		if global_position.y > 1500:
			emit_signal("end")
			queue_free()

# --------------------------------------------------
# PLAYER DETECTION
# --------------------------------------------------

func _on_area_2d_area_entered(area: Area2D):

	if area.is_in_group("Player") and state == BossState.INTRO:

		start_intro()

# --------------------------------------------------
# INTRO
# --------------------------------------------------

func start_intro():

	state = BossState.INTRO

	anim.play("intro")
	await anim.animation_finished

	if state == BossState.DEAD:
		return

	state = BossState.IDLE

	anim.play("idle")

	start_attack_loop()

# --------------------------------------------------
# ATTACK LOOP
# --------------------------------------------------

func start_attack_loop():

	while state != BossState.DEAD:

		if state != BossState.IDLE and state != BossState.FLY:
			await get_tree().process_frame
			continue
			
		if phase2:
			await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
		else:
			await get_tree().create_timer(randf_range(3.0, 5.0)).timeout

		if state == BossState.DEAD:
			break

		if phase2:
			state = BossState.FLY
			await get_tree().create_timer(2.0).timeout
			
		if state == BossState.IDLE or state == BossState.FLY:
			
			if phase2:
						
				match randi() % 2:
					0:
						await do_beam_attack()
					1:
						await do_chase_attack()
						
			else:
				await do_beam_attack()

# --------------------------------------------------
# FLY BEHAVIOR
# --------------------------------------------------

func fly_behavior(delta):

	var center = marker.global_position

	hover_offset += delta * 2.0

	var orbit_radius = 200.0

	var orbit_pos = center + Vector2(
		cos(hover_offset),
		sin(hover_offset)
	) * orbit_radius

	var current_player = _get_current_player()

	var player_bias = Vector2.ZERO

	if current_player:

		player_bias = (
			current_player.global_position - center
		) * 0.2

	var target = orbit_pos + player_bias

	global_position = global_position.lerp(
		target,
		delta * 2.5
	)

# --------------------------------------------------
# BEAM ATTACK
# --------------------------------------------------

func do_beam_attack():
	if dying or state == BossState.DEAD:
		return
		
	if attacking:
		return

	attacking = true
	state = BossState.ATTACK

	anim.play("attack1")
	await anim.animation_finished

	anim.play("attack1to")

	var charge_time := 3.0
	if phase2:
		charge_time = 1.8

	var timer := 0.0

	while timer < charge_time:

		if state == BossState.DEAD:
			return

		var current_player = _get_current_player()

		if current_player:

			var direction = current_player.global_position - global_position

			rotation = lerp_angle(
				rotation,
				direction.angle() + deg_to_rad(-34),
				0.9
			)

		timer += get_process_delta_time()
		await get_tree().process_frame

	can_fly = false

	anim.play("attack1toend")
	await anim.animation_finished

	if state == BossState.DEAD:
		return

	can_fly = true
	rotation = 0
	attacking = false

	if phase2:
		state = BossState.FLY
	else:
		state = BossState.IDLE

	anim.play("idle")

# --------------------------------------------------
# PHASE 2
# --------------------------------------------------
# --------------------------------------------------
# Chase Attack
# --------------------------------------------------
func do_chase_attack():
	if dying or state == BossState.DEAD:
		return
		
	if !phase2:
		return

	if attacking:
		return
	
	attacking = true
	state = BossState.ATTACK

	can_fly = false

	anim.play("attack2")

	var chase_speed := 450.0

	while anim.current_animation == "attack2" and anim.is_playing():

		if state == BossState.DEAD:
			return

		var current_player = _get_current_player()

		if current_player:

			var direction = (
				current_player.global_position
				- global_position
			).normalized()

			global_position += (
				direction
				* chase_speed
				* get_process_delta_time()
			)

			rotation = lerp_angle(
				rotation,
				direction.angle() + deg_to_rad(-34),
				0.25
			)

		await get_tree().process_frame

	rotation = 0

	can_fly = true
	attacking = false

	state = BossState.FLY
	anim.play("idle")


func _on_node_2d_phase_2() -> void:

	if dying or state == BossState.DEAD:
		return

	phase2 = true
	$AudioStreamPlayer2.play()
	state = BossState.FLY
	
	# --------------------------------------------------
# FLASH / HIT
# --------------------------------------------------

func flash_sprite(duration: float = 0.1):

	sprite_mat.set_shader_parameter("flash_amount", 1.0)

	await get_tree().create_timer(duration).timeout

	sprite_mat.set_shader_parameter("flash_amount", 0.0)

	$hitsfx.play()

	health -= 1

	if health <= 0 and not dying:
		start_death()

func _on_hitbox_area_entered(area: Area2D):

	if dying or state == BossState.DEAD:
		return

	if area.is_in_group("item"):

		await flash_sprite()

		if area.get_parent():
			area.get_parent().queue_free()

	if area.is_in_group("Playerattack"):

		await flash_sprite()

		if area.get_parent():
			area.get_parent().can_stomp = true
			area.get_parent().bounce = 0

# --------------------------------------------------
# DEATH
# --------------------------------------------------
func start_death():

	if dying:
		return
		
	GlobalCanvasLayer.tricks += 10
	$AudioStreamPlayer2.stop()
	dying = true
	attacking = false
	state = BossState.DEAD
	anim.play("death")
	get_parent().get_node("TextureRect/AnimationPlayer").play("end")
	# Slow motion
	Engine.time_scale = 0.25

	await get_tree().create_timer(0.35, true).timeout

	Engine.time_scale = 1.0

	# Launch body
	death_velocity.y = -600
	death_velocity.x = randf_range(-150, 150)
