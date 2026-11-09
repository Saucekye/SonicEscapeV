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
	var all_rings : int = Test.rings + Test.p2_rings   # co-op: both players' rings
	var ring_bonus_amount : int = all_rings * RING_SCORE_MULTIPLER
	var miku_bonus_amount : int = Test.mikus_saved * Test.MIKU_SCORE
	var trick_bonus_amount : int = Test.tricks_done * Test.TRICK_SCORE
	var total_score_amount : int = time_bonus_amount + ring_bonus_amount + miku_bonus_amount + trick_bonus_amount
	_add_bonus_rows([
		["Miku Bonus", str(Test.mikus_saved, " x ", Test.MIKU_SCORE, " = ", miku_bonus_amount)],
		["Trick Bonus", str(Test.tricks_done, " x ", Test.TRICK_SCORE, " = ", trick_bonus_amount)],
	])
	# Display the time as MINUTES : SECONDS : MILISECONDS
	time_display.text = "%01d : %02d : %02d" % [minutes, seconds, miliseconds]
	time_score.text = str(time_bonus_amount)
	ring_bonus_score.text = str(all_rings, " x ", RING_SCORE_MULTIPLER, " = ", ring_bonus_amount)
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

# Extra bonus rows under Ring Bonus (Miku Bonus, Trick Bonus); Score, Rank and the
# thank-you line move down to make room
func _add_bonus_rows(rows: Array) -> void:
	var names := $AnimationPlayer/Node2D/Node2D
	var ring_name: Label = names.get_node("Label3")
	var name_step := 74.0    # one row in the names column
	var value_step := 62.0   # one row in the numbers column
	var n := rows.size()
	for r in n:
		var title := ring_name.duplicate() as Label
		title.name = "BonusLabel%d" % r
		title.text = rows[r][0]
		names.add_child(title)
		title.position.y += name_step * (r + 1)
		var value := ring_bonus_score.duplicate() as Label
		value.name = "BonusScore%d" % r
		value.text = rows[r][1]
		ring_bonus_score.get_parent().add_child(value)
		value.position.y += value_step * (r + 1)
	for node_name in ["Label2", "Label5", "Label6"]:   # Score, Rank, Thank you for Playing!
		names.get_node(node_name).position.y += name_step * n
	final_score.position.y += value_step * n
	rank_rating.position.y += value_step * n
	# The animations pin the numbers' positions, so move their keys too
	var ap: AnimationPlayer = $AnimationPlayer
	for anim_name in ap.get_animation_list():
		var anim := ap.get_animation(anim_name)
		for i in anim.get_track_count():
			var path := str(anim.track_get_path(i))
			if path.ends_with("Scores/Final Score:position") or path.ends_with("Scores/RankRating:position"):
				for k in anim.track_get_key_count(i):
					anim.track_set_key_value(i, k, anim.track_get_key_value(i, k) + Vector2(0, value_step * n))
			elif path.ends_with("Scores/RingBonusScore:position"):
				# Each new number slides in exactly like Ring Bonus, one row lower per row
				for r in n:
					var t := anim.add_track(Animation.TYPE_VALUE)
					anim.track_set_path(t, NodePath(path.replace("RingBonusScore", "BonusScore%d" % r)))
					anim.track_set_interpolation_type(t, anim.track_get_interpolation_type(i))
					anim.value_track_set_update_mode(t, anim.value_track_get_update_mode(i))
					for k in anim.track_get_key_count(i):
						anim.track_insert_key(t, anim.track_get_key_time(i, k),
								anim.track_get_key_value(i, k) + Vector2(0, value_step * (r + 1)), anim.track_get_key_transition(i, k))

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
	# "Continue" in the closing dialogue (result_screen_continue.dialogue) sets the
	# floor to 24: carry on to the next floor (the rest area after the final boss,
	# then endless floors). "Exit" goes back to the title screen.
	if Test.level == 24:
		Test.final = false
		Test.end = false
		Net.endless_continue()   # online: the host takes everyone along
		get_tree().change_scene_to_file("res://Scenes/Level/test3.tscn")
		return
	get_tree().change_scene_to_file(next_scene_path)


	
