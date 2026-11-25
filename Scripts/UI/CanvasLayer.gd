extends CanvasLayer

var player = null
var tricks = 0
var boost = false

func _ready() -> void:
	# Touch controls switch on automatically on mobile devices
	var mobile_toggle = get_node_or_null("Sprite2D/Button2")
	if mobile_toggle:
		mobile_toggle.visible = false
	_update_pause_button()
	# New touch controls
	var old_touch := get_node_or_null("TouchScreenButton") as Control
	if old_touch:
		var touch = preload("res://Scripts/UI/mobile_controls.gd").new()
		touch.name = "MobileControls"
		touch.old_controls = old_touch
		add_child(touch)
	# The Salvage items you've got, under your icon
	var upgrades = preload("res://Scripts/UI/upgrades_hud.gd").new()
	upgrades.name = "Upgrades"
	add_child(upgrades)
	if MusicManager.has_signal("song_started"):
		MusicManager.song_started.connect(_on_song_started)
	_now_playing_left = NOW_PLAYING_SECONDS   # show the current song briefly at the start
	var ticker := Timer.new()
	ticker.wait_time = 1.0 / 60.0
	ticker.process_mode = Node.PROCESS_MODE_ALWAYS
	ticker.timeout.connect(func():
		_music_widget_tick(ticker.wait_time)
		_idle_fade_tick(ticker.wait_time))
	add_child(ticker)
	ticker.start()
	# Music box parts in red / white / black
	var redscale := ShaderMaterial.new()
	redscale.shader = preload("res://Shaders/ui_redscale.gdshader")
	_redscale = redscale
	# (The character HUD itself, Sprite2D and its boost meter, keeps its original
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
			# Tighter padding than the big menu buttons
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
	# The music widget shows as a brief "now playing" card
	var widget := get_node_or_null("Sprite2D/Node2D") as CanvasItem
	if widget == null:
		return
	_now_playing_left = max(0.0, _now_playing_left - delta)
	# The visualizer bars and music buttons are child nodes
	for holder in ["AudioVisualizer", "MusicButtons"]:
		var h := widget.get_node_or_null(holder)
		if h:
			for c in h.get_children():
				if c is CanvasItem and not c.use_parent_material:
					c.use_parent_material = true
	# Teto, when she's turned on, stays on screen the whole time
	var show: bool = Test.music_widget_always or MusicManager.display_teto or get_tree().paused or Pause.visible or _now_playing_left > 0.0
	if Test.music_locked:
		show = false
	var target := 1.0 if show else 0.0
	widget.modulate.a = move_toward(widget.modulate.a, target, delta * 4.0)
	widget.visible = widget.modulate.a > 0.01

# Stand still without pressing anything for a while and the HUD fades out
const IDLE_FADE_AFTER := 10.0   # seconds of doing nothing
const TIMER_SEE_THROUGH := 0.5  # the timer (and best time) are see-through
const IDLE_FADE_OUT := 1.5      # seconds to fade away
const IDLE_FADE_IN := 0.2       # seconds to come back
var _idle_for := 0.0
var _hud_alpha := 1.0

func _idle_fade_tick(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("active_player") as Node2D
	var still: bool = p != null and not Input.is_anything_pressed() and p.get("motion") is Vector2 \
			and absf(p.motion.x) < 5.0 and (p as CharacterBody2D).is_on_floor() and not get_tree().paused and not Pause.visible
	_idle_for = _idle_for + delta if still else 0.0
	var target := 0.0 if _idle_for >= IDLE_FADE_AFTER else 1.0
	_hud_alpha = move_toward(_hud_alpha, target, delta / (IDLE_FADE_OUT if target < _hud_alpha else IDLE_FADE_IN))
	var panel := get_node_or_null("Sprite2D") as CanvasItem
	if panel:
		panel.self_modulate.a = _hud_alpha
		for c in panel.get_children():

			if c is CanvasItem and c.name != "Node2D" and not (c is Button or c is TouchScreenButton):
				c.modulate.a = _hud_alpha * (TIMER_SEE_THROUGH if c.name in ["Timer", "BestTime"] else 1.0)
	for n in ["Sprite2Dicon", "Upgrades"]:
		var item := get_node_or_null(n) as CanvasItem
		if item:
			item.modulate.a = _hud_alpha
	# The rings count blinks by animating its modulate
	var rings := get_node_or_null("Label") as CanvasItem
	if rings:
		rings.self_modulate.a = _hud_alpha


func _update_pause_button() -> void:
	# Keyboard/controller players pause with Esc/Start
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
	get_tree().reload_current_scene()
	
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "restart":
		if $TouchScreenButton.visible == true:
			Test.mobile = true
		else:
			Test.mobile = false
		# The meter carries over between floors
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
