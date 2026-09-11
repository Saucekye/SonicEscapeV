extends Node2D

var balloon
var new_dialogue: DialogueResource = load("res://dialogue/2.dialogue")

signal next
signal skip

var wait = 6
var fade_rect: ColorRect

func _ready():
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.size = get_viewport_rect().size
	fade_rect.modulate.a = 0.0  # Start fully transparent
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)  # Add on top
	
	balloon = $ExampleBalloon
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start")

	# Automatic dialogue
	for i in range(13):
		await get_tree().create_timer(wait).timeout
		emit_signal("next")

		if i == 2:
			$AudioStreamPlayer.play()

		if i == 4:
			wait = 6

		if i == 5:
			wait = 14.75

	# Wait 5 seconds before the final dialogue
	$AnimationPlayer.play("play1")
	await get_tree().create_timer(4).timeout
	
	# Show the next dialogue
	emit_signal("next")
	$AnimationPlayer.play("play")
# Player controls the next 7 dialogue advances
	for i in range(73):
		await wait_for_input()
		emit_signal("next")
		if i == 21:
			$AnimationPlayer.play("play2")
		if i == 35:
			$AudioStreamPlayer.stream = load("res://FinalCutscene/Making Peace.MP3")
			$AudioStreamPlayer.volume_db = -80.0
			$AudioStreamPlayer.play()

			var tween = create_tween()
			tween.tween_property($AudioStreamPlayer, "volume_db", -5.0, 10.0)
			
	$AnimationPlayer.play("play3")		
	await get_tree().create_timer(5).timeout
	
	var new_dialogue: DialogueResource = load("res://dialogue/3.dialogue")
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start") 
	
	for i in range(4):
		await get_tree().create_timer(3.5).timeout
		emit_signal("next")
		
	for i in range(21):
		$AudioStreamPlayer.stop()
		await wait_for_input()
		emit_signal("next")
		
	new_dialogue = load("res://dialogue/4.dialogue")
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start")
	$AudioStreamPlayer.stream = load("res://FinalCutscene/0908.MP3")
	$AudioStreamPlayer.play()
	$AnimationPlayer.play("play4")
	
		
	for i in range(15):
		await wait_for_input()
		emit_signal("next")
		if i == 1:
			$AnimationPlayer.play("play5")
		if i == 8:
			$AnimationPlayer.play("play6")
		
	var tween = create_tween()
	tween.tween_property($AudioStreamPlayer, "volume_db", -80.0, 12)
	await get_tree().create_timer(3).timeout
	
	get_tree().change_scene_to_file("res://Scenes/Results/Results.tscn")
	
	
			
func wait_for_input():
		while true:
			if Input.is_action_just_pressed("ui_accept"):
				# Wait until the key is released
				await get_tree().process_frame
				while Input.is_action_pressed("ui_accept"):
					await get_tree().process_frame
				return

			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				# Wait until the mouse button is released
				await get_tree().process_frame
				while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
					await get_tree().process_frame
				return

			await get_tree().process_frame
			
func fade_and_change_scene():
	var tween = create_tween()

	# Fade out the screen
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Fade out the audio
	tween.parallel().tween_property($AudioStreamPlayer, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Then change the scene
	tween.tween_callback(change_scene)


func change_scene():
	get_tree().change_scene_to_file("res://Scenes/Results/Results.tscn")


func _on_button_pressed() -> void:
	emit_signal("skip")
	fade_and_change_scene()
	
