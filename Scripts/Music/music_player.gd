extends Node2D

var playinganim = false

# Audio and dropdown
@onready var dropdown = $OptionButton

var music_options = {
	"V0.1": {"stream": preload("res://Music/Level/Tee Lopes - Stream Zone Act 1 (Live Stream Result).mp3"), "volume": -8},
	"V0.2": {"stream": preload("res://Music/Level/Overcast - Breeze in the Clouds OST.mp3"), "volume": -8},
	"V0.3": {"stream": preload("res://Music/Level/Omega Strikers - A Demon's Thunder (Mako's Theme) (In-Game Version) [16 Minute Extended Version].mp3"), "volume": 0},
	"V0.4": {"stream": preload("res://Music/Level/Drift Back Home.mp3"), "volume": -8}
}

func _ready() -> void:
	# --- Sprite fade in ---
	var sprite = $Sprite2D
	sprite.modulate.a = 0.0  # start fully transparent

	var tween = create_tween()
	tween.tween_interval(2)  # wait 1 second
	tween.tween_property(sprite, "modulate:a", 1.0, 1.0)  # fade to opaque over 1s

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
		)
			# Optional: fade in to target volume
		
		# Remove focus from OptionButton
		dropdown.release_focus()
