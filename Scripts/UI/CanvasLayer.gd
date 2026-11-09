extends CanvasLayer

var player = null
var tricks = 0
var boost = false

func _ready() -> void:
	# Touch controls switch on automatically on mobile devices (Test.mobile), so
	# the scene's "Mobile" test toggle is hidden.
	var mobile_toggle = get_node_or_null("Sprite2D/Button2")
	if mobile_toggle:
		mobile_toggle.visible = false
	_update_pause_button()
	# New touch controls: floating stick + big corner buttons (mobile_controls.gd);
	# they take over from the old d-pad, which stays in the scene switched off
	var old_touch := get_node_or_null("TouchScreenButton") as Control
	if old_touch:
		var touch = preload("res://Scripts/UI/mobile_controls.gd").new()
		touch.name = "MobileControls"
		touch.old_controls = old_touch
		add_child(touch)
	if MusicManager.has_signal("song_started"):
		MusicManager.song_started.connect(_on_song_started)
	_now_playing_left = NOW_PLAYING_SECONDS   # show the current song briefly at the start
	var ticker := Timer.new()
	ticker.wait_time = 1.0 / 60.0
	ticker.process_mode = Node.PROCESS_MODE_ALWAYS
	ticker.timeout.connect(func(): _music_widget_tick(ticker.wait_time))
	add_child(ticker)
	ticker.start()
	# Music box parts in red / white / black
	var redscale := ShaderMaterial.new()
	redscale.shader = preload("res://Shaders/ui_redscale.gdshader")
	_redscale = redscale
	# (The character HUD itself, Sprite2D and its boost meter, keeps its original colours.)
	for path in ["Sprite2D/Node2D/ProgressBar", "Sprite2D/Node2D/AudioVisualizer", "Sprite2D/Node2D/MusicButtons"]:
		var item := get_node_or_null(path) as CanvasItem
		if item and item.material == null:
			item.material = redscale
	# Rush/XG-style look for the on-screen buttons and the music picker
	var rush: Theme = preload("res://Scripts/UI/rush_theme.gd").build()
	for path in ["Sprite2D/Button4", "Sprite2D/Node2D/OptionButton"]:
		var control := get_node_or_null(path)
		if control is Control:
			control.theme = rush
			control.add_theme_font_size_override("font_size", 16)  # these sit in small HUD boxes
			# Tighter padding than the big menu buttons, so text isn't cut off
			for state in ["normal", "hover", "focus", "pressed", "disabled"]:
				var box := (rush.get_stylebox(state, "Button") as StyleBoxFlat).duplicate()
				box.content_margin_left = 8
				box.content_margin_right = 8
				box.content_margin_top = 1
				box.content_margin_bottom = 1
				control.add_theme_stylebox_override(state, box)

var _redscale: ShaderMaterial

const NOW_PLAYING_SECONDS := 4.0
var _now_playing_left := 0.0

func _on_song_started(_song_name := "") -> void:
	_now_playing_left = NOW_PLAYING_SECONDS

func _music_widget_tick(delta: float) -> void:
	# The music widget shows as a brief "now playing" card, keeping the play area clear.
	# Runs from a helper that keeps going while paused, so it shows in the pause menu.
	var widget := get_node_or_null("Sprite2D/Node2D") as CanvasItem
	if widget == null:
		return
	_now_playing_left = max(0.0, _now_playing_left - delta)
	# The visualizer bars and music buttons are child nodes: let them share the red recolour
	for holder in ["AudioVisualizer", "MusicButtons"]:
		var h := widget.get_node_or_null(holder)
		if h:
			for c in h.get_children():
				if c is CanvasItem and not c.use_parent_material:
					c.use_parent_material = true
	# Teto, when she's turned on, stays on screen the whole time. Boss arenas hide
	# the music box completely (you can't change the song there).
	var show := Test.music_widget_always or MusicManager.display_teto or get_tree().paused or _now_playing_left > 0.0
	if Test.music_locked:
		show = false
	var target := 1.0 if show else 0.0
	widget.modulate.a = move_toward(widget.modulate.a, target, delta * 4.0)
	widget.visible = widget.modulate.a > 0.01

func _update_pause_button() -> void:
	# Keyboard/controller players pause with Esc/Start, so the on-screen
	# "Pause" button is only shown alongside the touch controls.
	var pause_button = get_node_or_null("Sprite2D/Button4")
	if pause_button:
		pause_button.visible = Test.mobile


func _on_button_pressed():
	if $TouchScreenButton.visible == true:
		Test.mobile = true
	else:
		Test.mobile = false
	Test.meter = 100
	Test.rings = 0
	Test.p2_meter = 100
	Test.p2_rings = 0
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
		#Test.quit = true
		get_tree().change_scene_to_file("res://Scenes/GameOver/GameOver.tscn")
	elif anim_name == "complete":
		get_tree().change_scene_to_file("res://FinalCutscene/Ending.tscn")
		
	
func _on_button_2_pressed() -> void:
	$TouchScreenButton.visible = !$TouchScreenButton.visible
	Test.mobile = $TouchScreenButton.visible
	_update_pause_button()

	
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
