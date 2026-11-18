extends Node2D

@export var force_running_mode : Node

@onready var timer_display: CanvasLayer = $"../TimerDisplay"
@onready var ring_strand: Node2D = $"../Ring Strand"
@onready var left_wall: TileMapLayer = $"../Level/LeftWall"
@onready var wind_effect: ColorRect = $WindTexture
@onready var timer_bar: TextureProgressBar = $"../TimerDisplay/BossUIContainer/ProgressBar"
@onready var area_start_running: Area2D = $AreaStartRunning

const TIMER_DURATION : int = 30

var wind_shader : ShaderMaterial
var wind_fade_time : float = 2

signal finished_running

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer_display.visible = false
	wind_effect.visible = false
	wind_shader = wind_effect.material
	finished_running.connect(_stop_running_phase)

func _stop_running_phase() -> void:
	_play_running_effect(false)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if !body.is_in_group("active_player"):
		return
	area_start_running.set_deferred("monitoring", false)
	_play_running_effect(true)
	_running_phase()
	
func _running_phase() -> void:
	var timer_tween : Tween = get_tree().create_tween()
	timer_tween.tween_property(timer_bar, "value", 0, TIMER_DURATION).set_trans(Tween.TRANS_LINEAR)
	timer_tween.parallel().tween_property(left_wall, "position:x", -1250, TIMER_DURATION)
	timer_tween.parallel().tween_property(ring_strand, "position:x", -6000, TIMER_DURATION)
	await timer_tween.finished
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
