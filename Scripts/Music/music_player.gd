extends Node2D 

var playinganim = false

# Audio and dropdown
@onready var dropdown = $OptionButton
@onready var pause_button: TextureRect = $Buttons/PauseButton
@onready var play_button: TextureRect = $Buttons/PlayButton
@onready var music_pause_button: Button = $MusicPauseButton
@onready var teto_sprite_2d: AnimatedSprite2D = $TetoSprite2D
@onready var scroll_container: MusicMarqueeHScrollContainer = $ScrollContainer
@onready var color_rect: ColorRect = $ColorRect
@onready var audio_visualizer: Node2D = $AudioVisualizer
@onready var music_buttons: Control = $Buttons

var music_paused

var music_options = {
	"V0.1": {"stream": preload("res://Music/Level/Tee Lopes - Stream Zone Act 1 (Live Stream Result).mp3"), "volume": -8},
	"V0.2": {"stream": preload("res://Music/Level/Overcast - Breeze in the Clouds OST.mp3"), "volume": -8},
	"V0.3": {"stream": preload("res://Music/Level/Omega Strikers - A Demon's Thunder (Mako's Theme) (In-Game Version) [16 Minute Extended Version].mp3"), "volume": 0},
	"V0.4": {"stream": preload("res://Music/Level/Drift Back Home.mp3"), "volume": -8}
}

func _ready() -> void:
	# Connect the signals
	GlobalSignals.set_teto_display.connect(_enable_teto)
	GlobalSignals.set_teto_animation.connect(_change_teto_animation)
	
	# --- Sprite fade in ---
	teto_sprite_2d.modulate.a = 0.0  # start fully transparent
	audio_visualizer.modulate.a = 0.0
	music_buttons.modulate.a = 0.0

	var tween = create_tween()
	var tween_audio_visualizer = create_tween()
	var tween_buttons = create_tween()
	tween.tween_interval(2)  # wait 1 second
	tween.tween_property(teto_sprite_2d, "modulate:a", 1.0, 1.0)  # fade to opaque over 1s
	tween_audio_visualizer.tween_interval(2)
	tween_audio_visualizer.tween_property(audio_visualizer, "modulate:a", 1.0, 1.0) 
	tween_buttons.tween_interval(2)
	tween_buttons.tween_property(music_buttons, "modulate:a", 1.0, 1.0) 
	
	# Set the Teto animation
	_reset_teto_animation()
	
	# --- Dropdown setup ---
	for option_name in music_options.keys():
		dropdown.add_item(option_name)
	dropdown.connect("item_selected", Callable(self, "_on_dropdown_selected"))
	
"""
func _process(delta: float) -> void:
	if Input.is_action_pressed("trick"):
		$Sprite2D/AnimationPlayer.play("taunt")
		playinganim = true

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	$Sprite2D/AnimationPlayer.play("idle")
	playinganim = false

func _on_player_controller_fast() -> void:
	if playinganim == false:
		$Sprite2D/AnimationPlayer.play("Run")

func _on_player_controller_slow() -> void:
	if playinganim == false:
		$Sprite2D/AnimationPlayer.play("idle")

func _on_player_controller_hurt() -> void:
	$Sprite2D/AnimationPlayer.play("hurt")
	playinganim = true
"""

func _on_option_button_item_selected(index: int) -> void:
	var selected_name = dropdown.get_item_text(index)
	if music_options.has(selected_name):
		var song_data = music_options[selected_name]
		var new_stream = song_data["stream"]
		var tween = create_tween()
		# Optional: fade out current music
		#tween.tween_property(MusicManager, "volume", 0.0, 1.0).as_sequence()
		tween.tween_callback(func():
			MusicManager.stream = new_stream
			MusicManager.play()
			
			var clean_name = new_stream.resource_path.get_basename().get_file()
			MusicManager.song_started.emit(clean_name)
		)
			# Optional: fade in to target volume
		
		# Remove focus from OptionButton
		dropdown.release_focus()

		# Indicate that music is playing again
		pause_button.visible = true
		play_button.visible = false


func _on_music_pause_button_pressed() -> void:
	music_pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.visible = !pause_button.visible
	play_button.visible = !play_button.visible
	if not MusicManager.stream_paused:
		MusicManager.stream_paused = true
		MusicManager.song_stopped.emit()
		GlobalSignals.set_teto_animation.emit("run")
	else:
		MusicManager.stream_paused = false
		GlobalSignals.set_teto_animation.emit("default")
		if MusicManager.stream:
			var clean_name = MusicManager.stream.resource_path.get_basename().get_file()
			MusicManager.song_started.emit(clean_name)
	
func _enable_teto(enabled : bool):
	teto_sprite_2d.visible = enabled
	scroll_container.visible = enabled
	color_rect.visible = enabled
	if enabled:
		pause_button.position = Vector2(-92, 48)
		play_button.position = Vector2(-92, 48)
		audio_visualizer.position = Vector2(-55, 65)
	else:
		pause_button.position = Vector2(-92, -97)
		play_button.position = Vector2(-92, -97)
		audio_visualizer.position = Vector2(-55, -83)

func _on_teto_sprite_2d_animation_finished() -> void:
	_reset_teto_animation()
	
func _reset_teto_animation() -> void:
	if !MusicManager.stream_paused:
		pause_button.visible = true
		play_button.visible = false
		teto_sprite_2d.play("default")
	else:
		pause_button.visible = false
		play_button.visible = true
		teto_sprite_2d.play("run")

func _change_teto_animation(animation_name : String):
	if !teto_sprite_2d.sprite_frames.has_animation(animation_name):
		teto_sprite_2d.play("default")
	teto_sprite_2d.play(animation_name)
