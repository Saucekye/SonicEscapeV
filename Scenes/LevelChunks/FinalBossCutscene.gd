extends AnimatedSprite2D
signal next
signal music
signal music2
signal skip  # new: other nodes listen to this to jump to the end state

var cutscene_id := 0  # bumping this cancels any running cutscene

# Waits, then returns true if the cutscene is still valid
func wait(seconds: float, id: int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return id == cutscene_id


func _on_node_2d_playcutscene() -> void:
	cutscene_id += 1
	var id := cutscene_id

	visible = false
	#Sage: I need to find Father… please…help me find him…
	if not await wait(5, id): return
	emit_signal("next")
	#Silver: Help you? Why would we ever help you?
	if not await wait(5, id): return
	emit_signal("next")
	visible = true
	play("1")
	# timer-based instead of `await animation_finished`, so skipping can't leave it hanging
	var dur := sprite_frames.get_frame_count("1") / sprite_frames.get_animation_speed("1") / speed_scale
	if not await wait(dur, id): return
	play("2")
	#Sonic: Glad we're on the same page, I'm sure Egghead can take care of himself.
	if not await wait(5, id): return
	emit_signal("next")
	play("6")
	#Hatsune Miku: ...
	if not await wait(5, id): return
	emit_signal("next")
	play("3")
	#Sonic: hmm... well I would hate to see this adventure come to an end though...
	if not await wait(8, id): return
	emit_signal("next")
	play("4")
	if not await wait(4, id): return
	var balloon = get_parent().get_node("ExampleBalloon")
	var new_dialogue: DialogueResource = load("res://FinalCutscene/Final2.dialogue")
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start")
	if not await wait(3, id): return
	emit_signal("next")
	play("5")
	emit_signal("music")
	if not await wait(10, id): return
	emit_signal("next")
	if not await wait(5.5, id): return
	emit_signal("next")
	visible = false


func _on_node_2d_dialogue_2() -> void:
	var id := cutscene_id  # continuation of the cutscene, so don't bump the id

	var balloon = get_parent().get_node("ExampleBalloon")
	var new_dialogue: DialogueResource = load("res://FinalCutscene/Final3.dialogue")
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start")
	if not await wait(3, id): return
	emit_signal("next")
	if not await wait(6, id): return
	emit_signal("next")
	emit_signal("music2")
	if not await wait(8, id): return
	emit_signal("next")
	if not await wait(10, id): return
	emit_signal("next")
	if not await wait(6, id): return
	emit_signal("next")


func _on_button_pressed() -> void:
	cutscene_id += 1  # cancels this script's running cutscene
	stop()
	visible = false

	# close the dialogue balloon if it's showing
	var balloon = get_parent().get_node_or_null("ExampleBalloon")
	if balloon:
		balloon.hide()

	emit_signal("skip")  # tells other nodes to jump to the end state
	emit_signal("music")
