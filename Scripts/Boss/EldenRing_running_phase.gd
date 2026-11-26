extends Node2D

@export var force_running_mode : Node
@export var floor_texture : TextureRect
@export var floor_slowdown_time : float = 2.0

# Arena nodes
@onready var timer_display: CanvasLayer = $"../TimerDisplay"
@onready var ring_strand: Node2D = $"../Ring Strand"
@onready var left_wall: TileMapLayer = $"../Level/LeftWall"
@onready var wind_effect: ColorRect = $WindTexture
@onready var timer_bar: TextureProgressBar = $"../TimerDisplay/BossUIContainer/ProgressBar"
@onready var area_start_running: Area2D = $AreaStartRunning
@onready var end_marker: Marker2D = $"../End"

# Attack nodes
@onready var attack_interval: Timer = $AttackInterval
@onready var cpu_particles_2d_right: CPUParticles2D = $FollowAttack/CPUParticles2DRight
@onready var cpu_particles_2d_left: CPUParticles2D = $FollowAttack/CPUParticles2DLeft
@onready var cpu_particles_2d: CPUParticles2D = $FollowAttack/CPUParticles2D
@onready var cpu_particles_2d_2: CPUParticles2D = $FollowAttack/CPUParticles2D2
@onready var attackbox: Area2D = $FollowAttack/Attackbox
@onready var follow_attack: Node2D = $FollowAttack
@onready var follow_attack_duration: Timer = $FollowAttack/AttackDuration

# General variables
const TIMER_DURATION : int = 30
var wind_shader : ShaderMaterial
var wind_fade_time : float = 2
var floor_shader : ShaderMaterial
var active_player : Node2D

# Attacks
const FOLLOW_ATTACK_SPEED_X : int = 450
var tween_attack_follow : Tween

# Signals
signal finished_running

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer_display.visible = false
	wind_effect.visible = false
	wind_shader = wind_effect.material
	floor_shader = floor_texture.material
	floor_shader.set_shader_parameter("scalar_x", 3.45)
	finished_running.connect(_stop_running_phase)
	
func _physics_process(delta: float) -> void:
	_resync_active_player()
	
	if !follow_attack_duration.is_stopped():
		follow_attack.global_position.x -= delta * FOLLOW_ATTACK_SPEED_X * sign(follow_attack.global_position.x - active_player.global_position.x)

func _stop_running_phase() -> void:
	attack_interval.stop()
	_play_running_effect(false)
	var timer_tween : Tween = get_tree().create_tween()
	timer_tween.tween_property(floor_shader, "shader_parameter/scalar_x", 0, floor_slowdown_time).set_trans(Tween.TRANS_LINEAR)
	await timer_tween.finished
	timer_tween.stop()
	timer_tween.kill()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if !body.is_in_group("active_player"):
		return
	area_start_running.set_deferred("monitoring", false)
	attack_interval.start()
	_play_running_effect(true)
	_running_phase()
	
func _running_phase() -> void:
	var timer_tween : Tween = get_tree().create_tween()
	timer_tween.tween_property(timer_bar, "value", 0, TIMER_DURATION).set_trans(Tween.TRANS_LINEAR)
	timer_tween.parallel().tween_property(left_wall, "position:x", -7000, TIMER_DURATION)
	timer_tween.parallel().tween_property(ring_strand, "position:x", -7500, TIMER_DURATION)
	await timer_tween.finished
	timer_tween.stop()
	timer_tween.kill()
	finished_running.emit()
	
func _play_running_effect(is_running : bool) -> void:
	wind_effect.visible = is_running
	fade_wind(wind_fade_time, is_running)
	timer_display.visible = is_running
	force_running_mode.process_mode = Node.PROCESS_MODE_INHERIT if is_running else ProcessMode.PROCESS_MODE_DISABLED

func fade_wind(time : float = 2, fade_in : bool = true) -> void:
	var fade_tween : Tween = get_tree().create_tween()
	var final_val : float = 0.5 if fade_in else 0.0
	fade_tween.tween_property(wind_shader, "shader_parameter/rain_color/:a", final_val, time)
	await fade_tween.finished
	
func _follow_Attack() -> void:
	var start_pos : Vector2 = end_marker.global_position
	
	if active_player != null:
		start_pos = active_player.global_position
	
	follow_attack.global_position.x = start_pos.x
	follow_attack_duration.start()
	_enable_follow_attack(true)

func _on_attack_duration_timeout() -> void:
	_enable_follow_attack(false)
	
func _enable_follow_attack(is_playing : bool) -> void:
	cpu_particles_2d.emitting = is_playing
	cpu_particles_2d_2.emitting = is_playing
	cpu_particles_2d_left.emitting = is_playing
	cpu_particles_2d_right.emitting = is_playing
	attackbox.monitorable = is_playing

func _on_attack_interval_timeout() -> void:
	_follow_Attack()
	
func _get_current_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("Player")

	for player in players:
		if is_instance_valid(player) and player.get("is_player") == true:
			return player

	return null
	
func _resync_active_player() -> void:
	var current_player = _get_current_player()

	if current_player != null:
		active_player = current_player
