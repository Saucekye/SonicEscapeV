extends CanvasLayer

signal resume_game

var camera = null
var current_scene = ""

func _ready():
	# Initially hidden
	visible = false
	
	# Set up focus mode for all buttons
	_setup_button_focus()
	_add_zoom_setting()
	_add_song_picker()
	_apply_rush_style()

func _apply_rush_style():
	# Bold slanted Rush/XG-style buttons, sliders and labels (RushTheme)
	var rush_theme = preload("res://Scripts/UI/rush_theme.gd")
	$Panel.theme = rush_theme.build()
	# Dim the game behind the menus
	if not $Panel.has_node("Backdrop"):
		var backdrop := ColorRect.new()
		backdrop.name = "Backdrop"
		backdrop.color = Color(rush_theme.BLACK, 0.6)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.position = Vector2(-4000, -4000)
		backdrop.size = Vector2(8000, 8000)
		$Panel.add_child(backdrop)
		$Panel.move_child(backdrop, 0)
	# A little more room between buttons so the slanted shapes don't touch
	for box in ["Menu", "Settings", "Keybind"]:
		if $Panel.has_node(box):
			$Panel.get_node(box).add_theme_constant_override("separation", 6)

func _add_zoom_setting():
	# Zoom option (Wide / Close / Closest), built here so the scene
	# file doesn't need editing. Uses the same Label + control row as Music/SFX.
	var settings = get_node_or_null("Panel/Settings")
	if settings == null or settings.has_node("ZoomBox"):
		return
	var row := HBoxContainer.new()
	row.name = "ZoomBox"
	var label := Label.new()
	label.text = "Zoom"
	row.add_child(label)
	var picker := OptionButton.new()
	picker.name = "Zoom"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.focus_mode = Control.FOCUS_ALL
	for option in ["Wide", "Close", "Closest"]:
		picker.add_item(option)
	picker.select(Test.zoom_level)
	picker.item_selected.connect(func(index): Test.zoom_level = index)
	row.add_child(picker)
	settings.add_child(row)
	# Music widget always on screen, or only as a brief card
	var mw_row := HBoxContainer.new()
	mw_row.name = "MusicWidgetBox"
	var mw_label := Label.new()
	mw_label.text = "Music Box"
	mw_row.add_child(mw_label)
	var mw_toggle := CheckButton.new()
	mw_toggle.focus_mode = Control.FOCUS_ALL
	mw_toggle.button_pressed = Test.music_widget_always
	mw_toggle.toggled.connect(func(on): Test.music_widget_always = on)
	mw_row.add_child(mw_toggle)
	settings.add_child(mw_row)
	# CRT on/off
	var crt_row := HBoxContainer.new()
	crt_row.name = "CRTBox"
	var crt_label := Label.new()
	crt_label.text = "CRT"
	crt_row.add_child(crt_label)
	var crt_toggle := CheckButton.new()
	crt_toggle.focus_mode = Control.FOCUS_ALL
	crt_toggle.button_pressed = Test.crt_enabled
	crt_toggle.toggled.connect(func(on): Test.crt_enabled = on)
	crt_row.add_child(crt_toggle)
	settings.add_child(crt_row)
	# Touch controls: thumbstick or d-pad (only shown when touch controls are on)
	var tc_row := HBoxContainer.new()
	tc_row.name = "TouchBox"
	var tc_label := Label.new()
	tc_label.text = "Touch"
	tc_row.add_child(tc_label)
	var tc_picker := OptionButton.new()
	tc_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc_picker.focus_mode = Control.FOCUS_ALL
	for option in ["Thumbstick", "D-Pad"]:
		tc_picker.add_item(option)
	tc_picker.select(Test.touch_style)
	tc_picker.item_selected.connect(func(index): Test.save_touch_style(index))
	tc_row.add_child(tc_picker)
	tc_row.visible = Test.mobile
	settings.add_child(tc_row)
	settings.visibility_changed.connect(func(): tc_row.visible = Test.mobile)
	# Local co-op: the second character picked is Player 2 (coop.gd); applies from the next floor
	var co_row := HBoxContainer.new()
	co_row.name = "CoopBox"
	var co_label := Label.new()
	co_label.text = "Co-op"
	co_row.add_child(co_label)
	var co_toggle := CheckButton.new()
	co_toggle.focus_mode = Control.FOCUS_ALL
	co_toggle.button_pressed = Test.coop_enabled
	co_toggle.toggled.connect(func(on): Test.save_coop(on))
	co_row.add_child(co_toggle)
	settings.add_child(co_row)
	# Your own music and playlists (Scripts/Music/music_screen.gd)
	var music_btn := Button.new()
	music_btn.name = "MusicPlaylists"
	music_btn.text = "Music Playlists"
	music_btn.focus_mode = Control.FOCUS_ALL
	music_btn.pressed.connect(_open_music_screen)
	settings.add_child(music_btn)
	# Sit just above the Keybind button, under the other settings rows
	var keybind = settings.get_node_or_null("Keybind")
	if keybind:
		settings.move_child(row, keybind.get_index())
		settings.move_child(mw_row, keybind.get_index())
		settings.move_child(crt_row, keybind.get_index())
		settings.move_child(tc_row, keybind.get_index())
		settings.move_child(co_row, keybind.get_index())
		settings.move_child(music_btn, keybind.get_index())

func _open_music_screen() -> void:
	if has_node("MusicScreen"):
		return
	var screen = load("res://Scripts/Music/music_screen.gd").open(self)
	screen.name = "MusicScreen"
	$Panel.visible = false
	screen.closed.connect(func() -> void:
		$Panel.visible = true
		if has_node("Panel/Settings/MusicPlaylists"):
			$Panel/Settings/MusicPlaylists.grab_focus())


func _setup_button_focus():
	# Main menu buttons
	if has_node("Panel/Menu/Resume"):
		$Panel/Menu/Resume.focus_mode = Control.FOCUS_ALL
	if has_node("Panel/Menu/Settings"):
		$Panel/Menu/Settings.focus_mode = Control.FOCUS_ALL
	if has_node("Panel/Menu/Keybind"):
		$Panel/Menu/Keybind.focus_mode = Control.FOCUS_ALL
	if has_node("Panel/Menu/Quit"):
		$Panel/Menu/Quit.focus_mode = Control.FOCUS_ALL
	
	# Settings buttons
	if has_node("Panel/Settings/Back"):
		$Panel/Settings/Back.focus_mode = Control.FOCUS_ALL
	if has_node("Panel/Settings/SFX"):
		$Panel/Settings/SFX.focus_mode = Control.FOCUS_ALL
	if has_node("Panel/Settings/Music"):
		$Panel/Settings/Music.focus_mode = Control.FOCUS_ALL
	
	for path in ["Panel/Settings/HBoxContainer/Music", "Panel/Settings/HBoxContainer2/SFX", "Panel/Settings/TetoBox/CheckButton", "Panel/Settings/Keybind", "Panel/Menu/Restart", "Panel/Keybind/Button2"]:
		if has_node(path):
			get_node(path).focus_mode = Control.FOCUS_ALL
	# Keybind buttons
	if has_node("Panel/Keybind/Button"):
		$Panel/Keybind/Button.focus_mode = Control.FOCUS_ALL

func _process(_delta):
	var camera = get_viewport().get_camera_2d()

	if camera:
		$Panel.global_position = camera.global_position
		
	if current_scene == "Character_Select_Screen" or current_scene == "Node2D": 
		$Panel/Menu/Quit.visible = true
	else:
		$Panel/Menu/Quit.visible = false
	
func _on_resume_pressed():
	visible = false
	get_tree().paused = false
	emit_signal("resume_game")

func _on_quit_pressed():
	if current_scene == "Node2D":
		visible = false
		get_tree().paused = false 
		Test.quit = true

# Toggle pause menu with Esc or controller Start button
func _unhandled_input(event):
	if has_node("MusicScreen"):
		return   # the MUSIC screen handles going back itself
	if event.is_action_pressed("ui_cancel") and current_scene == "Node2D":
		if visible:
			_on_resume_pressed()
		else:
			visible = true
			$Panel/Menu.visible = true
			$Panel/Settings.visible = false
			$Panel/Keybind.visible = false
			get_tree().paused = true
			# Set focus to first button when opening menu
			if has_node("Panel/Menu/Resume"):
				$Panel/Menu/Resume.grab_focus()

func _on_settings_pressed() -> void:
	$Panel/Settings.visible = true
	$Panel/Menu.visible = false
	# Grab focus on first settings element (the Music volume slider)
	if has_node("Panel/Settings/HBoxContainer/Music"):
		$Panel/Settings/HBoxContainer/Music.grab_focus()
	elif has_node("Panel/Settings/Back"):
		$Panel/Settings/Back.grab_focus()

func _on_button_3_pressed() -> void:
	if visible:
		_on_resume_pressed()
	else:
		visible = true
		$Panel/Menu.visible = true
		$Panel/Settings.visible = false
		get_tree().paused = true
		# Set focus when opening
		if has_node("Panel/Menu/Resume"):
			$Panel/Menu/Resume.grab_focus()

func _on_sfx_value_changed(value: float) -> void:
	var db = lerp(-50.0, 10.0, value) # if value is 0–1
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)
	
func _on_music_value_changed(value: float) -> void:
	var min_db = -80
	var max_db = 0
	MusicManager.volume_db = lerp(min_db, max_db, value)
	MusicManager.volume = lerp(min_db, max_db, value)

func _on_back_pressed() -> void:
	$Panel/Menu.visible = true
	$Panel/Settings.visible = false
	# Return focus to Settings button in main menu
	if has_node("Panel/Menu/Settings"):
		$Panel/Menu/Settings.grab_focus()
	
func _on_keybind_pressed() -> void:
	$Panel/Menu.visible = false
	$Panel/Settings.visible = false
	$Panel/Keybind.visible = true
	# Grab focus on first keybind button
	if has_node("Panel/Keybind/ForJump/Button"):
		$Panel/Keybind/ForJump/Button.grab_focus()
	
func _on_button_pressed() -> void:
	$Panel/Settings.visible = true
	$Panel/Menu.visible = false
	$Panel/Keybind.visible = false
	# Return focus to back button or first settings element
	if has_node("Panel/Settings/Back"):
		$Panel/Settings/Back.grab_focus()

func _on_restart_pressed() -> void:
	#if $TouchScreenButton.visible == true:
		#Test.mobile = true
	#else:
		#Test.mobile = false
	visible = false
	Test.meter = 100
	Test.rings = 0
	Test.p2_meter = 100
	Test.p2_rings = 0
	get_tree().reload_current_scene()

func _on_check_button_toggled(toggled_on: bool) -> void:
	GlobalSignals.set_teto_display.emit(toggled_on)
	MusicManager.display_teto = toggled_on


# ── Controller extras (B to go back, song picker) ────────────────────────────
func _input(event: InputEvent) -> void:
	# B steps back one screen while the pause menu is open (B is "trick" in play,
	# so it isn't ui_cancel); Start / Esc still opens and closes the menu.
	if not visible or not (event is InputEventJoypadButton) or not event.pressed or has_node("MusicScreen"):
		return
	if event.button_index != JOY_BUTTON_B:
		return
	var kb = get_node_or_null("Panel/Keybind")
	if kb and kb.visible and kb.get("waiting_for_rebind"):
		return    # B is being bound to an action right now
	get_viewport().set_input_as_handled()
	if kb and kb.visible:
		_on_button_pressed()
		if has_node("Panel/Settings/Keybind"):
			$Panel/Settings/Keybind.grab_focus()
	elif $Panel/Settings.visible:
		var open_popup := false
		for o in $Panel/Settings.find_children("*", "OptionButton", true, false):
			if o.get_popup().visible:
				open_popup = true
		if not open_popup:
			_on_back_pressed()
	elif $Panel/Menu.visible:
		if _song_picker and _song_picker.get_popup().visible:
			return
		_on_resume_pressed()


var _song_picker: OptionButton

func _add_song_picker() -> void:
	# Change the level music from the pause menu with a controller: left / right
	# on the Song row skips tracks, A opens the full list. Same tracks as the
	# music box dropdown in the HUD, and it updates that too.
	var menu = get_node_or_null("Panel/Menu")
	if menu == null or menu.has_node("SongBox"):
		return
	var row := HBoxContainer.new()
	row.name = "SongBox"
	var label := Label.new()
	label.text = "Song"
	row.add_child(label)
	_song_picker = OptionButton.new()
	_song_picker.name = "Song"
	_song_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_song_picker.focus_mode = Control.FOCUS_ALL
	_song_picker.clip_text = true
	# Fixed width: long song names are cut off rather than widening the menu
	_song_picker.fit_to_longest_item = false
	_song_picker.custom_minimum_size.x = 360
	_song_picker.item_selected.connect(_on_song_chosen)
	_song_picker.gui_input.connect(_on_song_gui_input)
	row.add_child(_song_picker)
	menu.add_child(row)
	# The menu box sat 18px right of the middle; centre it on the screen
	menu.offset_left = -250.0
	menu.offset_right = 250.0
	if menu.has_node("Resume"):
		menu.move_child(row, menu.get_node("Resume").get_index() + 1)
	visibility_changed.connect(_refresh_song_picker)


func _refresh_song_picker() -> void:
	if _song_picker == null or not visible:
		return
	var row = _song_picker.get_parent()
	row.visible = current_scene == "Node2D" and MusicManager.node2d_music_pool.size() > 0 and not Test.music_locked   # no song changes in boss arenas
	if not row.visible:
		return
	# (listed fresh each time: your playlist may have swapped the songs)
	_song_picker.clear()
	for song in MusicManager.node2d_music_pool:
		var nice := str(song.resource_path if song is Resource else song).get_file().get_basename()
		_song_picker.add_item(nice)
	_song_picker.select(clampi(MusicManager.node2d_track_index, 0, _song_picker.item_count - 1))


func _on_song_gui_input(event: InputEvent) -> void:
	if _song_picker.get_popup().visible:
		return
	var step := 0
	if event.is_action_pressed("ui_left", true):
		step = -1
	elif event.is_action_pressed("ui_right", true):
		step = 1
	if step != 0 and _song_picker.item_count > 0:
		var i := posmod(_song_picker.selected + step, _song_picker.item_count)
		_song_picker.select(i)
		_on_song_chosen(i)
		_song_picker.accept_event()


func _on_song_chosen(i: int) -> void:
	if Test.music_locked:
		return
	# Hand it to the HUD music box so everything (dropdown, now-playing card) stays in sync
	for n in get_tree().root.find_children("*", "Node2D", true, false):
		if n.has_method("_on_option_button_item_selected") and n.get("dropdown"):
			n.dropdown.select(i)
			n._on_option_button_item_selected(i)
			_song_picker.grab_focus()   # the HUD handler releases focus from its own dropdown only
			return
	# No music box found: change the track directly
	if MusicManager.can_play and i < MusicManager.node2d_music_pool.size():
		MusicManager.stream = MusicManager.node2d_music_pool[i]
		MusicManager.play()
		MusicManager.node2d_track_index = i

