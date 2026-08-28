extends AnimatedSprite2D
signal next
signal music
signal music2

func _on_node_2d_playcutscene() -> void:
	visible = false
	#Sage: I need to find Father… please…help me find him…
	await get_tree().create_timer(5).timeout
	emit_signal("next")
	#Silver: Help you? Why would we ever help you?
	await get_tree().create_timer(5).timeout
	emit_signal("next")
	visible = true
	play("1")
	await animation_finished
	play("2")
	#Sonic: Glad we’re on the same page, I'm sure Egghead can take care of himself.
	await get_tree().create_timer(5).timeout
	emit_signal("next")
	#Hatsune Miku: ...
	await get_tree().create_timer(5).timeout
	emit_signal("next")
	play("3")
	#Sonic: hmm... well I would hate to see this adventure come to an end though. Maybe we just help her and get out of here!
	await get_tree().create_timer(8).timeout
	emit_signal("next")
	play("4")
	await get_tree().create_timer(4).timeout
	var balloon = get_parent().get_node("ExampleBalloon")
	var new_dialogue: DialogueResource = load("res://FinalCutscene/Final2.dialogue")
	
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start")  # "start" = the title/node to begin at in the new file
	await get_tree().create_timer(3).timeout
	emit_signal("next")
	play("5")
	emit_signal("music")
	await get_tree().create_timer(10).timeout
	emit_signal("next")
	await get_tree().create_timer(5.5).timeout
	emit_signal("next")
	visible = false






func _on_node_2d_dialogue_2() -> void:
	var balloon = get_parent().get_node("ExampleBalloon")
	var new_dialogue: DialogueResource = load("res://FinalCutscene/Final3.dialogue")
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start")
	await get_tree().create_timer(3).timeout
	emit_signal("next")
	await get_tree().create_timer(6).timeout
	emit_signal("next")
	emit_signal("music2")
	await get_tree().create_timer(8).timeout
	emit_signal("next")
	await get_tree().create_timer(10).timeout
	emit_signal("next")
	await get_tree().create_timer(6).timeout
	emit_signal("next")
