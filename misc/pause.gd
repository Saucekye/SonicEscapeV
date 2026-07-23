extends CanvasLayer

signal resume_game

var camera = null
var current_scene = ""

func _ready():
	# Initially hidden
	visible = false
	
	# Set up focus mode for all buttons
	_setup_button_focus()

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
	print(current_scene)
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
	# Grab focus on first settings element
	if has_node("Panel/Settings/SFX"):
		$Panel/Settings/SFX.grab_focus()
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
	get_tree().reload_current_scene()
