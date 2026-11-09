extends Node2D
## A simple boss to build your own from. It floats between two points, shoots at
## the player, and takes hits from player attacks and thrown Miku/OCs.
##
## Change the numbers in the Inspector, swap the picture in Sprite2D, and add your
## own attacks in _attack(). It starts out as a big Flapper: Sprite2D shows the
## Flapper sprite sheet (14 frames side by side). For your own sheet, set Sprite2D's
## Hframes to how many frames it has, and the frame numbers below. The arena (the scene this boss sits in) needs:
##   - signal "end": connected to the arena's _on_node_2d_end (the floor ends)
##   - signal "update_health_bar": connected to the BossHPDisplay
##   - health and max_health (the health bar and online play read them)

signal end
signal update_health_bar(boss_health: int, boss_max_health: int)

@export var max_health := 12
## Pixels per second while floating between the two points.
@export var move_speed := 220.0
## The two points it floats between, relative to where it starts.
@export var patrol_left := Vector2(-450, 0)
@export var patrol_right := Vector2(450, 0)
## Seconds between attacks.
@export var attack_every := 1.6
## What it shoots (see template_projectile.tscn). Leave empty for no shooting.
@export var projectile_scene: PackedScene = preload("res://Templates/Boss/template_projectile.tscn")
@export var projectile_speed := 650.0
## Seconds it can't be hurt again after a hit.
@export var hit_cooldown := 0.4

@export_group("Animation")
## Frames of the sprite sheet (first, last) for each animation. Frame 0 is the left-most.
@export var idle_frames := Vector2i(0, 6)
@export var attack_frames := Vector2i(11, 13)
@export var hurt_frames := Vector2i(7, 10)
@export var frames_per_second := 10.0
## Turn on if the sheet's frames face left (the Flapper faces right).
@export var faces_left := false

var health := 0
var start := false    # the player walked into the arena
var begin := false    # the fight is on (it can be hurt)
var dying := false

var _home := Vector2.ZERO
var _going_right := true
var _attack_timer := 0.0
var _hurt_timer := 0.0
var _fall_speed := 0.0
var _anim := Vector2i(0, 6)
var _anim_time := 0.0
var _anim_loops := true

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	health = max_health
	_home = position
	_play(idle_frames, true)
	# Asleep until the player walks into the arena (see _on_start_area_entered)
	process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_animate(delta)
	if dying:
		_fall(delta)
		return
	if not begin:
		return
	_hurt_timer -= delta
	_move(delta)
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_every
		_attack()


## The player walked into the arena: wake up and start the fight.
func _on_start_area_entered(area: Area2D) -> void:
	if start or not area.is_in_group("Player"):
		return
	start = true
	process_mode = Node.PROCESS_MODE_INHERIT
	update_health_bar.emit(health, max_health)
	GlobalSignals.disable_boss_ui.emit(false)   # show the health bar
	await get_tree().create_timer(1.0).timeout   # a moment before the first attack
	begin = true
	_attack_timer = attack_every


func _move(delta: float) -> void:
	var target := _home + (patrol_right if _going_right else patrol_left)
	position = position.move_toward(target, move_speed * delta)
	if position.distance_to(target) < 4.0:
		_going_right = not _going_right
	sprite.flip_h = _going_right == faces_left


## One attack. Add your own here: dashes, more bullets, spawning enemies...
func _attack() -> void:
	var player := _find_player()
	if projectile_scene == null or player == null:
		return
	_play(attack_frames, false)
	var shot: Node2D = projectile_scene.instantiate()
	shot.global_position = global_position
	shot.set("velocity", global_position.direction_to(player.global_position) * projectile_speed)
	get_parent().add_child(shot)


## Hit by something: a player attack, or a thrown Miku/OC.
func _on_hit_box_area_entered(area: Area2D) -> void:
	if not begin or dying or _hurt_timer > 0.0:
		return
	if area.is_in_group("Playerattack"):
		take_damage(1)   # (the player bounces off by itself: HitBox is in the "Enemy" group)
	elif area.is_in_group("item") and ItemHit.counts(area, self):
		ItemHit.consume(area.get_parent(), self)
		take_damage(2)


func take_damage(amount: int) -> void:
	if dying:
		return
	health = max(health - amount, 0)
	_hurt_timer = hit_cooldown
	update_health_bar.emit(health, max_health)
	_flash()
	if health <= 0:
		start_death()


func start_death() -> void:
	if dying:
		return
	dying = true
	begin = false
	_fall_speed = -500.0   # a little hop before it falls
	await get_tree().create_timer(2.0).timeout
	end.emit()


func _fall(delta: float) -> void:
	_fall_speed += 1400.0 * delta
	position.y += _fall_speed * delta
	rotation += 4.0 * delta
	modulate.a = move_toward(modulate.a, 0.0, delta * 0.6)


func _flash() -> void:
	_play(hurt_frames, false)
	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group("active_player") as Node2D


## Start an animation (frame range); one that doesn't loop goes back to idle when done.
func _play(frames: Vector2i, loops: bool) -> void:
	_anim = frames
	_anim_loops = loops
	_anim_time = 0.0


func _animate(delta: float) -> void:
	if sprite.hframes * sprite.vframes <= 1:
		return   # a single picture: nothing to animate
	_anim_time += delta
	var count := _anim.y - _anim.x + 1
	var step := int(_anim_time * frames_per_second)
	if step >= count and not _anim_loops:
		_play(idle_frames, true)
		step = 0
	sprite.frame = clampi(_anim.x + step % count, 0, sprite.hframes * sprite.vframes - 1)
