extends Control

@export var next_scene_path: String = "uid://dwkxx7a6fwjqv"  # Replace with your scene path
var fade_rect: ColorRect

func _ready() -> void:
	

	$Title3/AnimationPlayer.play("fade")
	Pause.current_scene = ""

	# Create the black fade overlay
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.size = get_viewport_rect().size
	fade_rect.modulate.a = 0.0  # Start fully transparent
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)  # Add on top
	
	await get_tree().create_timer(8.0).timeout
	$AudioStreamPlayer2D.play()

var has_started := false

func _input(event):
	if has_started:
		return

	if (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
			has_started = true
			$start/AudioStreamPlayer2D.play()
			fade_and_change_scene()


func fade_and_change_scene():
	var tween = create_tween()

	# Fade out the screen
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Fade out the audio
	tween.parallel().tween_property($AudioStreamPlayer2D, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Then change the scene
	tween.tween_callback(change_scene)


func change_scene():
	get_tree().change_scene_to_file(next_scene_path)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
		$Title3/AnimationPlayer.play("start")
		$start/AnimationPlayer.play("start")

	
