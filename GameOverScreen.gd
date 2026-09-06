extends Node2D

var balloon
var new_dialogue: DialogueResource = load("res://dialogue/2.dialogue")

signal next

var wait = 6


func _ready():
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
	await get_tree().create_timer(4).timeout

	# Show the next dialogue
	emit_signal("next")

# Player controls the next 7 dialogue advances
	for i in range(73):
		await wait_for_input()
		emit_signal("next")
		if i == 35:
			$AudioStreamPlayer.stream = load("res://FinalCutscene/Making Peace.MP3")
			$AudioStreamPlayer.volume_db = -80.0
			$AudioStreamPlayer.play()

			var tween = create_tween()
			tween.tween_property($AudioStreamPlayer, "volume_db", 0.0, 12.0)
			
	await get_tree().create_timer(5).timeout

	var new_dialogue: DialogueResource = load("res://dialogue/3.dialogue")
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start") 
	
	for i in range(4):
		await get_tree().create_timer(5).timeout
		emit_signal("next")
		
	await get_tree().create_timer(5).timeout
	var tween = create_tween()
	tween.tween_property($AudioStreamPlayer, "volume_db", -80.0, 12)
	await get_tree().create_timer(8).timeout
	
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
			
	
