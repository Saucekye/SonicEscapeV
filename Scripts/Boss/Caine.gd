extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitsfx: AudioStreamPlayer = $hitsfx
@onready var after_death_timer: Timer = $AfterDeathTimer
@onready var hurtbox: Area2D = $Hurtbox
@onready var flash_animation_player: AnimationPlayer = $DefeatFlash/FlashAnimationPlayer

@export var boss_position : Marker2D
@export var projectile : Node2D

var max_health : int = 100

var death : bool = false
var death_velocity : Vector2
var gravity := 600

var active_player

signal update_health_bar(boss_health : int, boss_max_health : int)	## Signal to emit to the boss hp bar UI element
signal start_goku_black		## This signal is what will actually start the fight
signal set_new_boss(new_boss : Node2D, new_boss_name : String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if death:
		death_velocity.y += gravity * delta
		global_position += death_velocity * delta
		animated_sprite.rotation += 8 * delta
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	elif _get_current_player():
		face_player()

	if global_position.y > 1500:
		death_velocity = Vector2.ZERO

func _get_current_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("Player")

	for player in players:
		if is_instance_valid(player) and player.get("is_player") == true:
			active_player = player
			return player

	return null
		
func face_player():
	animated_sprite.flip_h = active_player.global_position.x < global_position.x

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if !area.is_in_group("Playerattack"):
		return
	hitsfx.play()
	update_health_bar.emit(0, max_health)
	#GlobalSignals.disable_boss_ui.emit(true)
	#boss_hp_display.visible = false
	flash_animation_player.play("end")
	GlobalCanvasLayer.tricks += 10
	death = true
	animated_sprite.play("death")
	death_velocity.x = randf_range(-500, 500)
	after_death_timer.start()

func _on_after_death_timer_timeout() -> void:
	death = false
	start_goku_black.emit()
	_move_to_boss_position()
	set_new_boss.emit(null, "Goku Black")
	
	
func _move_to_boss_position() -> void:
	var tween_time : float = 10
	animated_sprite.rotation = 0
	global_position.y = -1500
	global_position.x = boss_position.global_position.x
	animated_sprite.play("background")
	var position_tween = get_tree().create_tween()
	position_tween.tween_property(self, "global_position", boss_position.global_position, tween_time)
	await position_tween.finished
#	projectile.timer.start()
