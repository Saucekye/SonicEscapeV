extends CanvasLayer

var player = null
var tricks = 0
# Called when the node enters the scene tree for the first time.

	
func _on_button_pressed():
	if $TouchScreenButton.visible == true:
		Test.mobile = true
	else:
		Test.mobile = false
	Test.meter = 100
	Test.rings = 0
	get_tree().reload_current_scene()
	
	
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "restart":
		if $TouchScreenButton.visible == true:
			Test.mobile = true
		else:
			Test.mobile = false
		Test.meter = 100
		get_tree().reload_current_scene()
	elif anim_name == "Game_Over":
		Test.quit = true
	
func _on_button_2_pressed() -> void:
	$TouchScreenButton.visible = !$TouchScreenButton.visible
	Test.mobile = $TouchScreenButton.visible
	
	
func _on_button_3_pressed() -> void:
	var event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true 
	# Parse the input event
	Input.parse_input_event(event)
	# Optional: Also send the release event
	await get_tree().process_frame
	var release_event = InputEventKey.new()
	release_event.keycode = KEY_ESCAPE
	release_event.pressed = false
	Input.parse_input_event(release_event)
