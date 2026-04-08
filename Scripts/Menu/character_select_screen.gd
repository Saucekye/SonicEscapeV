extends Control

var wipe_rect: ColorRect
var fade_rect: ColorRect

func _ready():
	Test.characterone = ""
	Test.charactertwo = ""
	Test.characterthree = ""
	Test.rings = 0
	Test.meter = 100
	Pause.current_scene = "Character_Select_Screen"
	
	create_flashy_intro()
	$Openingsfx.play()
	
func create_flashy_intro():
	# Create wipe overlay
	wipe_rect = ColorRect.new()
	wipe_rect.size = get_viewport().get_visible_rect().size
	wipe_rect.color = Color.WHITE  # Start with bright flash
	wipe_rect.z_index = 100
	add_child(wipe_rect)
	
	var tween = create_tween()
	
	# Flash sequence: White -> Black -> Wipe out
	tween.tween_property(wipe_rect, "color", Color.BLACK, 0.1)
	await get_tree().create_timer(0.05).timeout
	
	# Lightning-fast wipe with bounce
#	tween.tween_method(update_wipe, 0.0, 1.2, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Screen shake effect
	tween.parallel().tween_method(shake_screen, 0.0, 1.0, 0.4)
	
	# Clean up
	tween.tween_callback(func(): wipe_rect.queue_free())

func update_wipe(progress: float):
	if wipe_rect:
		var viewport_size = get_viewport().get_visible_rect().size
		wipe_rect.size.x = viewport_size.x * (1.0 - progress)

func shake_screen(progress: float):
	# Shake intensity decreases over time
	var intensity = (1.0 - progress) * 8.0
	position = Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)

# FIXED: Make this function async and properly handle the scene change
func fade_and_change_scene(scene) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0  # Start transparent
	
	# Set size and position to cover entire viewport
	var viewport_size = get_viewport().get_visible_rect().size
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	overlay.z_index = 1000 
	
	add_child(overlay)
	var tween = create_tween()
	
	# Fade out the screen
	tween.tween_property(overlay, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# FIXED: Check if AudioStreamPlayer2D exists before trying to fade it
	tween.parallel().tween_property(MusicManager, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	
	MusicManager.stop()
	# FIXED: Call the scene change function directly
	get_tree().change_scene_to_file(scene)

# FIXED: Make the click handler properly await the fade
func _on_start_sprite_clicked(sprite: Sprite2D) -> void:
	# Prevent multiple clicks during transition
	set_process_input(false)
	#$Start/AudioStreamPlayer2.play()
	# FIXED: Await the fade and scene change
	await fade_and_change_scene("uid://du8tmmmv1djsb")

func _on_tutorial_tutorial() -> void:
	set_process_input(false)
	await fade_and_change_scene("uid://bx3auj0inifum")
	Test.level = 1
