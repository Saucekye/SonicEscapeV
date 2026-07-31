extends Node2D 

var playinganim = false

# Audio and dropdown
@onready var dropdown = $OptionButton
@onready var pause_button: TextureRect = $MusicButtons/PauseButton
@onready var play_button: TextureRect = $MusicButtons/PlayButton
@onready var music_pause_button: Button = $MusicPauseButton
@onready var teto_sprite_2d: AnimatedSprite2D = $TetoSprite2D
@onready var scroll_container: MusicMarqueeHScrollContainer = $ScrollContainer
@onready var color_rect: ColorRect = $ColorRect
@onready var audio_visualizer: Node2D = $AudioVisualizer
@onready var music_buttons: Control = $MusicButtons
@onready var music_player: Node2D = $"."

var music_paused

func _ready() -> void:
	# Connect the signals
	GlobalSignals.set_teto_display.connect(_enable_teto)
	GlobalSignals.set_teto_animation.connect(_change_teto_animation)
	GlobalSignals.disable_music_player.connect(_disable_scene)
	
	# Check for Teto if enabled
	_enable_teto(MusicManager.display_teto)
	
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
	for song_name in MusicManager.node2d_music_pool:
		var clean_name = str(song_name).get_basename().get_file()
		dropdown.add_item(clean_name)
		
	dropdown.select(MusicManager.node2d_track_index)
		
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

func _on_option_button_item_selected(music_idx: int) -> void:
	# Remove focus from OptionButton
	dropdown.release_focus()
	
	# Only allow the music to be changed while in a level
	if !MusicManager.can_play:
		return
	
	# Ensure the index is within range
	if music_idx < 0 or music_idx >= MusicManager.node2d_music_pool.size():
		music_idx = 0
	
	var song_data = MusicManager.node2d_music_pool[music_idx]
	
	MusicManager.stream = song_data
	MusicManager.play()
	
	#var new_stream = song_data["stream"]
	#var tween = create_tween()
	## Optional: fade out current music
	##tween.tween_property(MusicManager, "volume", 0.0, 1.0).as_sequence()
	#tween.tween_callback(func():
		#MusicManager.stream = new_stream
		#MusicManager.play()
		#
		#var clean_name = new_stream.resource_path.get_basename().get_file()
		#MusicManager.song_started.emit(clean_name)
	#)
		# Optional: fade in to target volume
		
	# Keep track of music index	
	MusicManager.node2d_track_index = music_idx

	# Indicate that music is playing again
	_reset_teto_animation()

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
	
func _disable_scene(disabled : bool):
	music_player.visible = !disabled
