extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var defeat_flash_screen: ColorRect = $DefeatFlashScreen
@onready var flash_animation_player: AnimationPlayer = $DefeatFlashScreen/FlashAnimationPlayer
@onready var music: AudioStreamPlayer = $Music
@onready var action_timer: Timer = $ActionTimer
@onready var attack_spawn_marker: Marker2D = $AttackSpawnMarker

@export var positions : Array[Marker2D]
@export var attack1_projectile : PackedScene = preload("uid://pkgu0rai06d7")
@export var attack2_projectile : PackedScene

enum BossState {INTRO, IDLE, ATTACK_FOLLLOW, ATTACK_BARRAGE, DEAD}

var state = BossState.INTRO
var max_health = 30
var health = 30

var active_player: Node2D
var start = false

var prev_choice : int = 0
var new_pos : Vector2

var sprite_mat : ShaderMaterial

var velocity = Vector2.ZERO
var gravity = 900
var dying = false

signal end
signal update_health_bar(boss_health : int, boss_max_health : int)	## Signal to emit to the boss hp bar UI element
signal boss_defeated

# --------------------------------------------------
# READY
# --------------------------------------------------

func _ready():
	sprite_mat = sprite.material
	defeat_flash_screen.visible = false
	global_position = positions[0].global_position

func _on_caine_start_goku_black() -> void:
	state = BossState.INTRO
	animation_player.play("intro")
	await animation_player.animation_finished
	state = BossState.IDLE
	animation_player.play("idle")
	GlobalSignals.disable_boss_ui.emit(false)
	
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

	if _get_current_player():
		face_player()

	if health <= 0 and not dying:
		start_death()

func _get_current_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("Player")

	for player in players:
		if is_instance_valid(player) and player.get("is_player") == true:
			active_player = player
			return player

	return null
	
# --------------------------------------------------
# DO ATTACK
# --------------------------------------------------

# Wrapper function for when timer ends
func _on_action_timer_timeout() -> void:
	_attack_choice()

func _attack_choice():
	var choices = {"stay" : 0, "move" : 1, "attack_follow" : 2, "attack_barrage" : 3}
	var choice : int = int(randf_range(0, choices.size()))
	
	if prev_choice == choices.stay and choice == prev_choice:
		choice = choices.move
	if prev_choice == choices.move and choice == prev_choice:
		choice = choices.attack_barrage
		
	prev_choice = choice
	
	if choice == choices.stay:
		return
	elif choice == choices.move:
		move_behavior()
	elif choice == choices.attack_follow:
		animation_player.play("attack1")
	else:
		animation_player.play("attack1")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack1":
		attack_behavior()
		animation_player.play("attack1end")
	if anim_name == "attack2":
		animation_player.play("attack2_2")
	if anim_name == "attack2":
		animation_player.play("attack1end")
	elif anim_name == "attack1end":
		move_behavior()
	elif anim_name == "move":
		# Set position after move animation is completed
		move_end_behavior()
	elif anim_name == "move_end":
		animation_player.play("idle")
	elif anim_name == "intro":
		action_timer.start()

# --------------------------------------------------
# MOVE
# --------------------------------------------------

func move_behavior():
	animation_player.play("move")
	# Get new position and set it after the animation is finished
	var new_pos_idx = randf_range(0, positions.size() -1)
	new_pos = positions[new_pos_idx].global_position
	
func move_end_behavior():
	animation_player.play("idle")
	global_position = new_pos
	
# --------------------------------------------------
# FACE PLAYER
# --------------------------------------------------

func face_player():
	sprite.flip_h = active_player.global_position.x < global_position.x

# --------------------------------------------------
# ATTACK 1
# --------------------------------------------------

func attack_behavior() -> void:
	var projecitle = attack1_projectile.instantiate()
	self.get_parent().add_child(projecitle)
	projecitle.global_position = attack_spawn_marker.global_position
	if sprite.flip_h:
		projecitle.global_position.x = attack_spawn_marker.global_position.x - attack_spawn_marker.position.x
	
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

# --------------------------------------------------
# HIT DETECTION
# --------------------------------------------------

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("item"):
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		area.get_parent().queue_free()
		take_damage()
	elif area.is_in_group("Playerattack"):
		update_health_bar.emit(health - 1, max_health)
		await flash_sprite()
		if area.is_in_group("Player"):
			area.get_parent().can_stomp = true
			area.get_parent().bounce = 0
		take_damage()

# --------------------------------------------------
# DAMAGE
# --------------------------------------------------

func take_damage(amount = 1):
	if state == BossState.DEAD:
		return
	flash_animation_player.play("end")
	$hitsfx.play()
	health -= amount
	
	if health <= 0:
		start_death()

# --------------------------------------------------
# DEATH
# --------------------------------------------------

func start_death():
	action_timer.stop()
	GlobalCanvasLayer.tricks += 10
	dying = true
	state = BossState.DEAD
	boss_defeated.emit()
	get_tree().call_group("EnemyProjectile", "queue_free")
	music.stop()
	defeat_flash_screen.visible = true
	animation_player.play("death")
	flash_animation_player.play("end")
	velocity.y = -600
	velocity.x = randf_range(-200, 200)
