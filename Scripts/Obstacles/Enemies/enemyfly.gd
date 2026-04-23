extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -100.0
const GRAVITY = 900
const HURT_JUMP_FORCE = -400.0
const DAMAGE_COOLDOWN = 0.5
const SPIN_SPEED = deg_to_rad(720)  # 720 deg/sec
const TOTAL_SPIN = deg_to_rad(360 * 4)  # 4 full spins

var direction := 0
var player_body = null
var enemy_body = null
var damage_timer = 0.0
var hurt = false
var dying = false
var launch = 0

var spin = false
var spin_amount = 0.0

var smoke = preload("res://misc/explode/explosion.tscn")


func _ready() -> void:
	randomize()
	$Sprite2D/AnimationPlayer.play("idle")

func _physics_process(delta: float) -> void:
	if hurt and not is_on_floor():
		velocity.y += GRAVITY * delta

	if spin:
		var spin_step = SPIN_SPEED * delta
		spin_amount += spin_step
		$Sprite2D.rotation += spin_step
		if spin_amount >= TOTAL_SPIN:
			spin = false
			spin_amount = 0.0
			$Sprite2D.rotation = 0
			
	if is_on_floor() and hurt:
		death()

	if not hurt:
		damage(delta)
	else:
		dead()
		
	

	move_and_slide()

func damage(delta):
	if player_body != null:
		damage_timer -= delta
		if damage_timer <= 0.0:
			if not player_body.invincible:
				player_body.hurt()
				$AudioStreamPlayer2D.stream = load("res://Sounds/Obstacles/Enemies/16_enmsn_egft_sword_ver.wav")
				$AudioStreamPlayer2D.play()
				$Sprite2D/AnimationPlayer.play("attack")
				damage_timer = DAMAGE_COOLDOWN

func dead():
	if not dying:
		dying = true
		velocity.y = HURT_JUMP_FORCE
		velocity.x = launch
		$Sprite2D/AnimationPlayer.play("hurt")
		var sounds = [
			load("res://Sounds/Obstacles/Enemies/01_enmsn_cmn_damage1.wav"),
			load("res://Sounds/Obstacles/Enemies/01_enmsn_cmn_damage3.wav")
		]
		$AudioStreamPlayer2D.stream = sounds[randi() % sounds.size()]
		$AudioStreamPlayer2D.play()
		start_death_check()

func start_death_check() -> void:
	await get_tree().create_timer(0.25).timeout


func death():
	var boom = smoke.instantiate()
	boom.position = position
	get_parent().add_child(boom)
	boom.scale = Vector2(2,2)
	spin = false
	spin_amount = 0.0
	$Sprite2D.rotation = 0
	queue_free()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Enemy"):
		enemy_body = area.get_parent()
		if enemy_body.hurt:
			hurt = true

	if area.is_in_group("Playerattack"):
		hurt = true
		player_body = area.get_parent()
		if player_body.is_in_group("Player"):
			var player_position = player_body.global_position
			var enemy_position = global_position
			
			if "can_stomp" in player_body:
				if not player_body.can_stomp:
					player_body.can_stomp = true
					death()
					return

			if player_position.x < enemy_position.x:
				$Sprite2D.flip_h = true
				if player_body.time_elapsed > 60:
					spin = true
					launch = 650
				else:
					launch = 250
			else:
				$Sprite2D.flip_h = false
				if player_body.time_elapsed > 60:
					spin = true
					launch = -650
				else:
					launch = -250

	if area.is_in_group("Player"):
		player_body = area.get_parent()
		var player_position = player_body.global_position
		var enemy_position = global_position

		$Sprite2D.flip_h = player_position.x < enemy_position.x
		damage_timer = 0.0

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		$Sprite2D/AnimationPlayer.play("idle")

func _on_area_2d_area_exited(area: Area2D) -> void:
	if area.is_in_group("Player"):
		player_body = null
