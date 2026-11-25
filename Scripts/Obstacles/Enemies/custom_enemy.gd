extends CharacterBody2D
# Enemy configured entirely from the Inspector

enum Movement { STAND_STILL, WALK_BACK_AND_FORTH, FLY_BACK_AND_FORTH, HOVER_UP_AND_DOWN, CHASE_THE_PLAYER }

@export_group("Movement")
@export var movement: Movement = Movement.STAND_STILL
## Pixels per second
@export var speed := 120.0
## How far it goes each way from where you put it
@export var distance := 250.0
## Chase the player
@export var chase_range := 600.0
## Falls and stands on the ground
@export var uses_gravity := true
## Walking: turn around at the edge of a ledge instead of walking off
@export var turn_at_edges := true

@export_group("Fighting")
## Hits it takes to defeat
@export var health := 1
## Hurts a player who touches it
@export var hurts_on_touch := true
## What it shoots
@export var projectile_scene: PackedScene
## Seconds between shots
@export var fire_every := 2.0
@export var projectile_speed := 450.0
## Only shoots when a player is this close
@export var shoot_range := 700.0
## Aim at the player
@export var aim_at_player := true

@export_group("Animation")
## Frames of the sprite sheet
@export var idle_frames := Vector2i(0, 0)
@export var attack_frames := Vector2i(0, 0)
@export var hurt_frames := Vector2i(0, 0)
@export var frames_per_second := 10.0
## Tick if the sheet's frames face left
@export var faces_left := false

const GRAVITY := 900.0
const HURT_JUMP_FORCE := -400.0
const DAMAGE_COOLDOWN := 0.5
const HIT_COOLDOWN := 0.4
const TOTAL_SPIN := deg_to_rad(360 * 4)
const SPIN_SPEED := deg_to_rad(720)
const SMOKE := preload("res://misc/explode/explosion.tscn")

var hurt := false      # defeated, flying off
var dying := false
var player_body: Node2D = null
var _gone := false
var _home := Vector2.ZERO
var _home_set := false
var _dir := 1.0
var _time := 0.0
var _damage_timer := 0.0
var _hit_timer := 0.0
var _fire_timer := 0.0
var _launch := 0.0
var _spin := false
var _spin_amount := 0.0
var _anim := Vector2i.ZERO
var _anim_time := 0.0
var _anim_loops := true

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_fire_timer = fire_every
	_play(idle_frames, true)


func _physics_process(delta: float) -> void:
	_animate(delta)
	if _spin:
		var step := SPIN_SPEED * delta
		_spin_amount += step
		sprite.rotation += step
		if _spin_amount >= TOTAL_SPIN:
			_spin = false
			sprite.rotation = 0.0
	if hurt:
		velocity.y += GRAVITY * delta
		move_and_slide()
		if is_on_floor() and velocity.y >= 0.0:
			death()
		return
	_hit_timer -= delta
	_move(delta)
	_touch_damage(delta)
	_shoot(delta)


func _move(delta: float) -> void:
	if not _home_set:
		_home = global_position
		_home_set = true
	_time += delta
	var target_vx := 0.0
	match movement:
		Movement.WALK_BACK_AND_FORTH, Movement.FLY_BACK_AND_FORTH:
			if (global_position.x - _home.x) * _dir >= distance:
				_dir = -_dir
			elif movement == Movement.WALK_BACK_AND_FORTH and (is_on_wall() or (turn_at_edges and is_on_floor() and not _ground_ahead())):
				_dir = -_dir
			target_vx = _dir * speed
		Movement.HOVER_UP_AND_DOWN:
			var y := _home.y + sin(_time * speed / maxf(distance, 1.0)) * distance
			velocity.y = (y - global_position.y) / maxf(delta, 0.001)
		Movement.CHASE_THE_PLAYER:
			var p := _nearest_player()
			if p and p.global_position.distance_to(global_position) < chase_range:
				var to := global_position.direction_to(p.global_position)
				_dir = signf(to.x) if absf(to.x) > 0.01 else _dir
				target_vx = to.x * speed
				if not uses_gravity:
					velocity.y = to.y * speed
			elif not uses_gravity:
				velocity.y = 0.0
	velocity.x = target_vx
	if uses_gravity:
		velocity.y += GRAVITY * delta
	elif movement != Movement.HOVER_UP_AND_DOWN and movement != Movement.CHASE_THE_PLAYER:
		velocity.y = 0.0
	if target_vx != 0.0:
		sprite.flip_h = (target_vx > 0.0) == faces_left
	move_and_slide()


# Is there ground a little ahead?
func _ground_ahead() -> bool:
	var from := global_position + Vector2(_dir * 30.0, 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 80), collision_mask, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _touch_damage(delta: float) -> void:
	if player_body == null or not hurts_on_touch or not is_instance_valid(player_body):
		return
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		if not player_body.invincible:
			player_body.hurt()
			_sound("res://Sounds/Obstacles/Enemies/16_enmsn_egft_sword_ver.wav")
			_play(attack_frames, false)
		_damage_timer = DAMAGE_COOLDOWN


func _shoot(delta: float) -> void:
	if projectile_scene == null:
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = fire_every
	var p := _nearest_player()
	if p == null or p.global_position.distance_to(global_position) > shoot_range:
		return
	var facing := -1.0 if sprite.flip_h != faces_left else 1.0
	var dir := global_position.direction_to(p.global_position) if aim_at_player else Vector2(facing, 0)
	var shot: Node2D = projectile_scene.instantiate()
	shot.global_position = global_position
	shot.set("velocity", dir * projectile_speed)
	get_parent().add_child(shot)
	_play(attack_frames, false)


func _nearest_player() -> Node2D:
	var best: Node2D = null
	for p in get_tree().get_nodes_in_group("Player"):
		if p is Node2D and p.is_inside_tree() and p.visible and (best == null or \
				p.global_position.distance_squared_to(global_position) < best.global_position.distance_squared_to(global_position)):
			best = p
	return best


# Getting hit
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Enemy"):
		var other = area.get_parent()
		if other != self and other.get("hurt") == true:
			_defeat(0.0)   # hit by a defeated enemy flying past
	if area.is_in_group("Playerattack") and not hurt:
		var attacker = area.get_parent()
		GlobalSignals.emit_signal("camerashake")
		if _hit_timer > 0.0:
			return
		health -= 1
		if health > 0:
			_hit_timer = HIT_COOLDOWN
			_play(hurt_frames, false)
			_flash()
			_sound("res://Sounds/Obstacles/Enemies/01_enmsn_cmn_damage1.wav")
			return
		if attacker.is_in_group("Player"):
			if "can_stomp" in attacker and not attacker.can_stomp:
				attacker.can_stomp = true
				death()
				return
			var from_left: bool = attacker.global_position.x < global_position.x
			sprite.flip_h = from_left
			var fast: bool = float(attacker.get("time_elapsed") if attacker.get("time_elapsed") != null else 0.0) > 60.0
			_spin = fast
			_defeat((650.0 if fast else 250.0) * (1.0 if from_left else -1.0))
		else:
			_defeat(0.0)
	if area.is_in_group("Player"):
		player_body = area.get_parent()
		sprite.flip_h = (player_body.global_position.x > global_position.x) == faces_left
		_damage_timer = 0.0


func _on_area_2d_area_exited(area: Area2D) -> void:
	if area.is_in_group("Player"):
		player_body = null


# Knocked out: flies off in an arc, then explodes when it lands
func _defeat(launch: float) -> void:
	if hurt:
		return
	hurt = true
	dying = true
	_launch = launch
	velocity = Vector2(launch, HURT_JUMP_FORCE)
	_play(hurt_frames, true)
	_sound(["res://Sounds/Obstacles/Enemies/01_enmsn_cmn_damage1.wav", "res://Sounds/Obstacles/Enemies/01_enmsn_cmn_damage3.wav"].pick_random())
	GlobalCanvasLayer.tricks += 1
	get_tree().create_timer(1.5).timeout.connect(death)   # in case it never lands


func death() -> void:
	if _gone:
		return
	_gone = true
	var boom := SMOKE.instantiate()
	boom.position = position
	boom.scale = Vector2(2, 2)
	get_parent().add_child(boom)
	queue_free()

# Looks
func _sound(path: String) -> void:
	if has_node("AudioStreamPlayer2D"):
		$AudioStreamPlayer2D.stream = load(path)
		$AudioStreamPlayer2D.play()


func _flash() -> void:
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _play(frames: Vector2i, loops: bool) -> void:
	_anim = frames
	_anim_loops = loops
	_anim_time = 0.0


func _animate(delta: float) -> void:
	if sprite.hframes * sprite.vframes <= 1:
		return
	_anim_time += delta
	var count := maxi(_anim.y - _anim.x + 1, 1)
	var step := int(_anim_time * frames_per_second)
	if step >= count and not _anim_loops:
		_play(idle_frames, true)
		step = 0
	sprite.frame = clampi(_anim.x + step % count, 0, sprite.hframes * sprite.vframes - 1)
