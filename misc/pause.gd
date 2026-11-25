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
	_load_saved_settings.call_deferred()

func _add_zoom_setting():
	# Zoom option, built here so the scene file doesn't need editing
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
	picker.item_selected.connect(func(index):
		Test.zoom_level = index
		Test.zoom_chosen = true)
	settings.visibility_changed.connect(func(): picker.select(Test.zoom_level))
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
	# Touch controls
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
	# Salvage from above instead of first person
	var td_row := HBoxContainer.new()
	td_row.name = "TopDownBox"
	var td_label := Label.new()
	td_label.text = "Salvage Top-Down"
	td_row.add_child(td_label)
	var td_toggle := CheckButton.new()
	td_toggle.focus_mode = Control.FOCUS_ALL
	td_toggle.button_pressed = Test.salvage_top_down
	td_toggle.toggled.connect(func(on):
		Test.save_top_down(on)
		var here := get_tree().current_scene
		if here and here.has_method("set_top_down"):
			here.set_top_down(on))   # straight away, not next visit
	td_row.add_child(td_toggle)
	settings.add_child(td_row)
	# Window, resolution, brightness, look sensitivity
	var ls_row := Button.new()
	ls_row.name = "DisplayControls"
	ls_row.text = "Display & Controls"
	ls_row.focus_mode = Control.FOCUS_ALL
	ls_row.pressed.connect(_open_display_screen)
	settings.add_child(ls_row)
	# Your own music and playlists
	var music_btn := Button.new()
	music_btn.name = "MusicPlaylists"
	music_btn.text = "Music Playlists"
	music_btn.focus_mode = Control.FOCUS_ALL
	music_btn.pressed.connect(_open_music_screen)
	settings.add_child(music_btn)
	# Download your save / load one
	var save_btn := Button.new()
	save_btn.name = "SaveFile"
	save_btn.text = "Save File"
	save_btn.focus_mode = Control.FOCUS_ALL
	save_btn.pressed.connect(_open_save_screen)
	settings.add_child(save_btn)
	# Sit just above the Keybind button, under the other settings rows
	var keybind = settings.get_node_or_null("Keybind")
	if keybind:
		settings.move_child(row, keybind.get_index())
		settings.move_child(mw_row, keybind.get_index())
		settings.move_child(tc_row, keybind.get_index())
		settings.move_child(td_row, keybind.get_index())
		settings.move_child(ls_row, keybind.get_index())
		settings.move_child(music_btn, keybind.get_index())
		settings.move_child(save_btn, keybind.get_index())

func _open_display_screen() -> void:
	if has_node("DisplayScreen"):
		return
	var screen = load("res://Scripts/UI/display_screen.gd").open(self)
	screen.name = "DisplayScreen"
	$Panel.visible = false
	screen.closed.connect(func() -> void:
		$Panel.visible = true
		if has_node("Panel/Settings/DisplayControls"):
			$Panel/Settings/DisplayControls.grab_focus())


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

	if current_scene == "Salvage":
		# No 2D camera in there
		$Panel.position = get_viewport().get_visible_rect().size * 0.5
		$Panel.scale = Vector2(2, 2)
	else:
		$Panel.scale = Vector2.ONE
		if camera:
			$Panel.global_position = camera.global_position
	# Salvage: no Restart
	if has_node("Panel/Menu/Restart"):
		$Panel/Menu/Restart.visible = current_scene != "Salvage"
		
	if current_scene == "Character_Select_Screen" or current_scene == "Node2D": 
		$Panel/Menu/Quit.visible = true
	else:
		$Panel/Menu/Quit.visible = false
	
func _on_resume_pressed():
	visible = false
	get_tree().call_group("hidden_while_paused", "show")
	get_tree().paused = false
	if current_scene == "Salvage" and not Test.mobile and not Test.salvage_top_down:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # back to looking around
	emit_signal("resume_game")

func _on_quit_pressed():
	if current_scene == "Node2D":
		visible = false
		get_tree().paused = false 
		Test.quit = true

# Toggle pause menu with Esc or controller Start button
func _unhandled_input(event):
	if has_node("MusicScreen") or has_node("SaveScreen") or has_node("DisplayScreen"):
		return   # those screens handle going back themselves
	if event.is_action_pressed("ui_cancel") and (current_scene == "Node2D" or current_scene == "Salvage"):
		if visible:
			_on_resume_pressed()
		else:
			visible = true
			get_tree().call_group("hidden_while_paused", "hide")
			$Panel/Menu.visible = true
			$Panel/Settings.visible = false
			$Panel/Keybind.visible = false
			get_tree().paused = true
			if current_scene == "Salvage":
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			# Set focus to first button when opening menu
			if has_node("Panel/Menu/Resume"):
				$Panel/Menu/Resume.grab_focus()

func _on_settings_pressed() -> void:
	$Panel/Settings.visible = true
	$Panel/Menu.visible = false
	# Grab focus on first settings element
	if has_node("Panel/Settings/HBoxContainer/Music"):
		$Panel/Settings/HBoxContainer/Music.grab_focus()
	elif has_node("Panel/Settings/Back"):
		$Panel/Settings/Back.grab_focus()

func _on_button_3_pressed() -> void:
	if visible:
		_on_resume_pressed()
	else:
		visible = true
		get_tree().call_group("hidden_while_paused", "hide")
		$Panel/Menu.visible = true
		$Panel/Settings.visible = false
		get_tree().paused = true
		# Set focus when opening
		if has_node("Panel/Menu/Resume"):
			$Panel/Menu/Resume.grab_focus()

func _on_sfx_value_changed(value: float) -> void:
	var db = lerp(-50.0, 10.0, value) # if value is 0–1
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)
	if not _loading_settings:
		Test.save_setting("sfx_volume", value)
	
func _on_music_value_changed(value: float) -> void:
	var min_db = -80
	var max_db = 0
	MusicManager.volume_db = lerp(min_db, max_db, value)
	MusicManager.volume = lerp(min_db, max_db, value)
	if not _loading_settings:
		Test.save_setting("music_volume", value)

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
	$Panel/Keybind.use_salvage_keys(current_scene == "Salvage")   # Salvage's own controls in there
	$Panel/Keybind.first_button().grab_focus()
	
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
	get_tree().reload_current_scene()

func _on_check_button_toggled(toggled_on: bool) -> void:
	GlobalSignals.set_teto_display.emit(toggled_on)
	MusicManager.display_teto = toggled_on
	if not _loading_settings:
		Test.save_setting("teto_display", toggled_on)


# Volumes and the Teto display, as they were last time
var _loading_settings := false

func _load_saved_settings() -> void:
	_loading_settings = true
	var music = get_node_or_null("Panel/Settings/HBoxContainer/Music")
	if music:
		music.value = float(Test.load_setting("music_volume", music.value))
		_on_music_value_changed(music.value)
	var sfx = get_node_or_null("Panel/Settings/HBoxContainer2/SFX")
	if sfx:
		sfx.value = float(Test.load_setting("sfx_volume", sfx.value))
		_on_sfx_value_changed(sfx.value)
	var teto = Test.load_setting("teto_display", null)
	if teto != null:
		for c in $Panel/Settings.find_children("*", "CheckButton", true, false):
			if c.toggled.is_connected(_on_check_button_toggled):
				c.button_pressed = bool(teto)
				_on_check_button_toggled(bool(teto))
	_loading_settings = false


func _open_save_screen() -> void:
	if has_node("SaveScreen"):
		return
	var screen = load("res://Scripts/UI/save_screen.gd").new()
	screen.name = "SaveScreen"
	add_child(screen)
	$Panel.visible = false
	screen.closed.connect(func() -> void:
		$Panel.visible = true
		if has_node("Panel/Settings/SaveFile"):
			$Panel/Settings/SaveFile.grab_focus())


# Controller extras
func _input(event: InputEvent) -> void:
	# B steps back one screen while the pause menu is open
	if not visible or not (event is InputEventJoypadButton) or not event.pressed or has_node("MusicScreen") or has_node("SaveScreen") or has_node("DisplayScreen"):
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
	# Change the level music from the pause menu with a controller
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
	# The menu box sat 18px right of the middle
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
	# Hand it to the HUD music box so everything stays in sync
	for n in get_tree().root.find_children("*", "Node2D", true, false):
		if n.has_method("_on_option_button_item_selected") and n.get("dropdown"):
			n.dropdown.select(i)
			n._on_option_button_item_selected(i)
			_song_picker.grab_focus()   # the HUD handler releases focus from its own dropdown only
			return
	# No music box found
	if MusicManager.can_play and i < MusicManager.node2d_music_pool.size():
		MusicManager.stream = MusicManager.node2d_music_pool[i]
		MusicManager.play()
		MusicManager.node2d_track_index = i

