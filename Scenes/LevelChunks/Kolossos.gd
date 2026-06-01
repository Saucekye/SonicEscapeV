extends Node2D

enum BossState {INTRO, IDLE, ATTACK, DEAD}

var state = BossState.INTRO
var health = 30
var active_player: Node2D
var dying = false
var attacking = false

signal phase2

@onready var anim = $Sprite2D/AnimationPlayer2
@onready var sprite = $Sprite2D
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial

@onready var marker_left: Node2D = get_parent().get_node("Marker2D")
@onready var marker_right: Node2D = get_parent().get_node("Marker2D2")

# Death physics
var death_velocity := Vector2.ZERO
var gravity := 900

# --------------------------------------------------
# READY
# --------------------------------------------------

func _ready():
	randomize()

# --------------------------------------------------
# PROCESS
# --------------------------------------------------

func _process(delta):

	if state == BossState.DEAD:

		death_velocity.y += gravity * delta
		global_position += death_velocity * delta

		sprite.rotation += 8 * delta

		if global_position.y > 1500:
			queue_free()

# --------------------------------------------------
# PLAYER DETECTION → START
# --------------------------------------------------

func _on_area_2d_area_entered(area: Area2D):

	if area.is_in_group("Player") and state == BossState.INTRO:

		active_player = area.get_parent()
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

		# Wait until boss is idle
		if state != BossState.IDLE:
			await get_tree().process_frame
			continue

		# Delay before attack
		await get_tree().create_timer(randf_range(1.0, 2.0)).timeout

		if state == BossState.DEAD:
			break

		# Double-check still idle
		if state == BossState.IDLE:
			await do_charge()

# --------------------------------------------------
# CHARGE ATTACK
# --------------------------------------------------

func do_charge():

	if attacking:
		return

	attacking = true
	state = BossState.ATTACK

	# Pick closest marker
	var dist_left = global_position.distance_to(marker_left.global_position)
	var dist_right = global_position.distance_to(marker_right.global_position)

	var from_marker = marker_left if dist_left <= dist_right else marker_right
	var to_marker = marker_right if dist_left <= dist_right else marker_left

	# Teleport to start
	global_position = from_marker.global_position

	# Face direction
	sprite.flip_h = from_marker == marker_right

	# Wind-up
	anim.play("attack1")
	await anim.animation_finished

	if state == BossState.DEAD:
		return

	# Charge
	anim.play("attack1to")

	var tween = create_tween()
	tween.tween_property(self, "global_position:x", to_marker.global_position.x, 1)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	await tween.finished

	if state == BossState.DEAD:
		return

	# Recovery
	anim.play("attack1toend")
	await anim.animation_finished

	if state == BossState.DEAD:
		return

	attacking = false
	state = BossState.IDLE
	anim.play("idle")

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

	if state == BossState.DEAD:
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
	dying = true
	attacking = false
	state = BossState.DEAD
	emit_signal("phase2")

	anim.play("death")
	get_parent().get_node("TextureRect/AnimationPlayer").play("end")
	# Slow motion
	Engine.time_scale = 0.25

	await get_tree().create_timer(0.35, true).timeout

	Engine.time_scale = 1.0

	# Launch body
	death_velocity.y = -600
	death_velocity.x = randf_range(-150, 150)
