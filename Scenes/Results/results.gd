extends Node2D

@export var next_scene_path: String = "res://Scenes/Intro/titlescreen.tscn"  # Replace with your scene path
@export var accept_input_start_dialogue = false
var fade_rect: ColorRect
var viewing_dialogue : bool = false

@onready var time_display: Label = $AnimationPlayer/Node2D/Scores/TimeDisplay
@onready var time_score: Label = $AnimationPlayer/Node2D/Scores/TimeScore
@onready var ring_bonus_score: Label = $AnimationPlayer/Node2D/Scores/RingBonusScore
@onready var final_score: Label = $"AnimationPlayer/Node2D/Scores/Final Score"
@onready var rank_rating: Label = $AnimationPlayer/Node2D/Scores/RankRating

func _ready() -> void:
	Pause.current_scene = ""

	# Create the black fade overlay
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.size = get_viewport_rect().size
	fade_rect.modulate.a = 0.0  # Start fully transparent
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)  # Add on top
	
	_calculate_score()
	
	await get_tree().create_timer(3).timeout
	$AnimationPlayer/Node2D/AudioStreamPlayer.play()
	
func _calculate_score() -> void:
	const RING_SCORE_MULTIPLER : int = 100
	const MAX_TIME_BONUS : int = 10000
	var minutes : float = Test.elapsed_sesion_time / 60
	var seconds : float = fmod(Test.elapsed_sesion_time, 60)
	var miliseconds : float = fmod(Test.elapsed_sesion_time, 1) * 100
	## If 15 minutes or less, max rank
	## Otherwise, lose 1000 score every 5 minutes
	var time_bonus_amount : int = int(MAX_TIME_BONUS if minutes <= 10 else MAX_TIME_BONUS - (int((int(minutes) - 10) / 5) * 2000))
	if time_bonus_amount < 0:
		time_bonus_amount = 0
	var ring_bonus_amount : int = Test.rings * RING_SCORE_MULTIPLER
	var total_score_amount : int = time_bonus_amount + ring_bonus_amount
	# Display the time as MINUTES : SECONDS : MILISECONDS
	time_display.text = "%01d : %02d : %02d" % [minutes, seconds, miliseconds]
	time_score.text = str(time_bonus_amount)
	ring_bonus_score.text = str(Test.rings, " x ", RING_SCORE_MULTIPLER, " = ", ring_bonus_amount)
	final_score.text = str(total_score_amount)
	
	if total_score_amount >= 10000:
		rank_rating.text = "S"
	elif total_score_amount >= 8000:
		rank_rating.text = "A"
	elif total_score_amount >= 6000:
		rank_rating.text = "B"
	elif total_score_amount >= 4000:
		rank_rating.text = "C"
	elif total_score_amount >= 2000:
		rank_rating.text = "D"
	else:
		rank_rating.text = "E"

func _input(event):
	if accept_input_start_dialogue:
		if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
				_start_end_dialogue()

func _start_end_dialogue() -> void:
	if viewing_dialogue:
		return
	var resource = preload("uid://cgo5uucvbjxho")
	# Modify and set the dialogue system
	DialogueManager.show_example_dialogue_balloon(resource)

func fade_and_change_scene():
	var tween = create_tween()

	# Fade out the screen
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Fade out the audio
	tween.parallel().tween_property($AnimationPlayer/Node2D/AudioStreamPlayer, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Then change the scene
	tween.tween_callback(change_scene)


func change_scene():
	#Test.level = 24
	get_tree().change_scene_to_file(next_scene_path)


	
