extends Node2D

var levelover = false

var _bosses: Array = []

func _ready() -> void:
	# DIsable ability to change music
	GlobalSignals.disable_music_player.emit(true)
	Test.music_locked = true   # also hides the pause menu's Song row and Teto
	add_to_group("boss_arena")   # Miku and the OCs only blink in here (miku.gd, ocs.gd)
	# Speedrun timer: the boss split stops the moment every boss is out of health,
	# not after the death animation (timer.gd). The final boss refills its health
	# between phases, so it keeps stopping on its end signal instead.
	if Test.level % 20 != 0:
		for n in find_children("*", "", true, false):
			if "health" in n and "max_health" in n:
				_bosses.append(n)


func _exit_tree() -> void:
	Test.music_locked = false


func _process(_delta: float) -> void:
	if _bosses.is_empty() or Test.floor_done:
		return
	for b in _bosses:
		if is_instance_valid(b) and float(b.health) > 0.0:
			return
	Test.floor_done = true

func _on_node_2d_end() -> void:
	Test.floor_done = true   # stops the boss timer (timer.gd)
	if Net.online and not Net.is_host:
		Net.show_waiting()   # online: the host's fight decides when the floor ends
		return
	if Test.level != 20: 
		if Test.level != 16:
			Test.end = true
			# Reenable ability to choose music
			GlobalSignals.disable_music_player.emit(false)
			Test.music_locked = false
			GlobalSignals.disable_boss_ui.emit(true)
			if levelover == false:
				Test.level += 1
				levelover = true
				if Test.level % 4 == 0:
					var tween = create_tween()
					# Fade out the screen
					# FIXED: Check if AudioStreamPlayer2D exists before trying to fade it
					tween.parallel().tween_property(MusicManager, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					await tween.finished
					MusicManager.stop()
					Test.musicplaying = false
		else:
			Test.end = true
			# Reenable ability to choose music
			GlobalSignals.disable_music_player.emit(true)
			GlobalSignals.disable_boss_ui.emit(true)
			if levelover == false:
				Test.level += 4
				Test.final = true
				await get_tree().create_timer(1).timeout
				get_tree().change_scene_to_file("res://FinalCutscene/vision.tscn")
				levelover = true
				
				if Test.level % 4 == 0:
					var tween = create_tween()
					# Fade out the screen
					# FIXED: Check if AudioStreamPlayer2D exists before trying to fade it
					tween.parallel().tween_property(MusicManager, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					await tween.finished
					MusicManager.stop()
					Test.musicplaying = false
					

			else:
				if Test.musicplaying == false:
					Test.musicplaying = false
					MusicManager.play()
	else:
		if levelover == false:
			Test.level += 1
			levelover = true
			if Test.musicplaying == false:
				Test.musicplaying = false
				MusicManager.play()
