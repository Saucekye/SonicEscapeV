extends Node2D

var balloon
var new_dialogue: DialogueResource

signal next
signal skip

var skip2 = false
var wait = 6
var fade_rect: ColorRect
var leaving_scene = false

var dialogue_count = 0
var effects_started = false

var current_vision = 1
var black_screen_vision = false

var fade_in_tween: Tween

@export var fade_duration: float = 1.5
@export var fade_in_duration: float = 1.5
@export var sprite_fade_duration: float = 1.5
@export var music_fade_duration: float = 2.0
@export var music_target_volume_db: float = -5.0

const DEBUG_VISION := true

const VISION_MUSIC_PATHS: Array[String] = [
	"res://Vision/05 - stargazing.mp3",
	"res://Vision/07 - she smiled, calmly.mp3",
	"res://Vision/08 - mamie Françoise.mp3",
	"res://Vision/24 - joséphine baker.mp3"
]


func _dbg(msg: String) -> void:
	if DEBUG_VISION:
		print("[vision] ", msg)


func _ready() -> void:
	# Final cutscene -> Vision 5.
	# Floors 4, 8, 12, 16 -> Visions 1-4.
	# Floor 20 and beyond -> Vision 6.
	if Test.final:
		current_vision = 5
	elif Test.level >= 20:
		current_vision = 6
	else:
		current_vision = clampi(
			floori(float(Test.level) / 4.0),
			1,
			4
		)

	_dbg("level=%s vision=%s" % [Test.level, current_vision])

	# Load the dialogue.
	new_dialogue = load(
		"res://vision" + str(current_vision) + ".dialogue"
	)

	if new_dialogue == null:
		push_error(
			"Could not load vision dialogue for floor "
			+ str(Test.level)
		)
		return

	# Vision 6 remains black.
	# Vision 5 behaves like the other visions.
	black_screen_vision = current_vision >= 6

	# Set up the screen overlays.
	fade_rect = $CanvasLayer/ColorRect
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hide both overlays only during Vision 5.
	$ColorRect.visible = current_vision != 5
	$ColorRect3.visible = current_vision != 5

	# Set up the AnimatedSprite2D.
	var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
	var animation_name = "vision" + str(current_vision)

	animated_sprite.stop()
	animated_sprite.visible = false
	animated_sprite.modulate.a = 0.0

	if current_vision >= 1 and current_vision <= 5:
		if animated_sprite.sprite_frames != null:
			if animated_sprite.sprite_frames.has_animation(animation_name):
				animated_sprite.animation = animation_name
			else:
				push_warning(
					"AnimatedSprite2D is missing animation: "
					+ animation_name
				)
		else:
			push_warning(
				"AnimatedSprite2D has no SpriteFrames resource."
			)

	# Set up music.
	var music: AudioStreamPlayer = $AudioStreamPlayer
	music.stop()
	music.volume_db = -40.0

	# Visions 1-4 have music.
	if current_vision >= 1 and current_vision <= 4:
		var music_index = current_vision - 1

		if music_index < VISION_MUSIC_PATHS.size():
			var path = VISION_MUSIC_PATHS[music_index]

			_dbg(
				"music path=%s exists=%s"
				% [path, ResourceLoader.exists(path)]
			)

			var stream = load(path)

			if stream != null:
				music.stream = stream
			else:
				push_error("Music failed to load: " + path)
		else:
			push_warning(
				"No music assigned for vision "
				+ str(current_vision)
			)

	# Connect the dialogue-ended signal once.
	if not DialogueManager.dialogue_ended.is_connected(
		_on_dialogue_ended
	):
		DialogueManager.dialogue_ended.connect(
			_on_dialogue_ended
		)

	# Start the dialogue.
	balloon = $ExampleBalloon
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start")

	# Wait for up to 49 dialogue advances.
	for i in range(49):
		if leaving_scene or not is_inside_tree():
			return

		var continue_dialogue = await wait_for_input()

		if not continue_dialogue:
			return

		if leaving_scene or not is_inside_tree():
			return

		next.emit()
		dialogue_count += 1

		# Start effects after two dialogue advances.
		# This applies to Visions 1-5.
		if not black_screen_vision:
			if dialogue_count >= 2 and not effects_started:
				effects_started = true
				start_music_and_sprite(current_vision)

	# Leave after the maximum number of advances.
	if leaving_scene or not is_inside_tree():
		return

	await fade_to_black()
	_go_to_next_scene()


func _on_dialogue_ended(
	_resource: DialogueResource
) -> void:
	if leaving_scene:
		return

	_dbg(
		"dialogue ended after %s advances"
		% dialogue_count
	)

	await fade_to_black()
	_go_to_next_scene()


func _go_to_next_scene() -> void:
	if not is_inside_tree():
		return

	# Reset the final cutscene flag after Vision 5.
	if current_vision == 5:
		Test.final = false

	Test.rest = true

	get_tree().change_scene_to_file(
		"res://Scenes/Level/test3.tscn"
	)


func start_music_and_sprite(
	vision_number: int
) -> void:
	var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
	var music: AudioStreamPlayer = $AudioStreamPlayer
	var animation_name = "vision" + str(vision_number)

	_dbg(
		"start_music_and_sprite vision=%s stream=%s black=%s leaving=%s"
		% [
			vision_number,
			music.stream,
			black_screen_vision,
			leaving_scene
		]
	)

	if black_screen_vision or leaving_scene:
		return

	# Start music when available.
	if music.stream != null:
		music.stop()
		music.volume_db = -40.0
		music.play()

		var music_tween = create_tween()
		music_tween.tween_property(
			music,
			"volume_db",
			music_target_volume_db,
			music_fade_duration
		)
	else:
		# Vision 5 has no assigned music.
		if vision_number != 5:
			push_warning(
				"No music stream loaded for vision "
				+ str(vision_number)
			)

	# Fade out ColorRect for Visions 1-4.
	# During Vision 5, both overlays are already hidden.
	if vision_number != 6:
		fade_in_tween = create_tween()
		fade_in_tween.tween_property(
			fade_rect,
			"color:a",
			0.0,
			fade_in_duration
		)

	# Show and play the correct animation.
	if animated_sprite.sprite_frames != null:
		if animated_sprite.sprite_frames.has_animation(animation_name):
			animated_sprite.visible = true
			animated_sprite.modulate.a = 1.0
			animated_sprite.play(animation_name)
		else:
			push_warning(
				"Cannot play missing animation: "
				+ animation_name
			)


func fade_to_black() -> void:
	if leaving_scene:
		return

	leaving_scene = true

	# Vision 5 has no visible overlays to fade.
	# Vision 6 is already black.
	if current_vision == 5 or black_screen_vision:
		return

	# Stop the current fade-in if it's running.
	if fade_in_tween != null and fade_in_tween.is_valid():
		fade_in_tween.kill()

	# Fade the screen and music out together.
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		fade_rect,
		"color:a",
		1.0,
		fade_duration
	)

	var music: AudioStreamPlayer = $AudioStreamPlayer

	if music.playing:
		tween.tween_property(
			music,
			"volume_db",
			-40.0,
			fade_duration
		)

	await tween.finished

	music.stop()


func wait_for_input() -> bool:
	while true:
		if leaving_scene or not is_inside_tree():
			return false

		# Skip mode.
		if skip2:
			return true

		# Enter or ui_accept.
		if Input.is_action_just_pressed("ui_accept"):
			await get_tree().process_frame

			while Input.is_action_pressed("ui_accept"):
				if leaving_scene or not is_inside_tree():
					return false

				await get_tree().process_frame

			return true

		# Left mouse click.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			await get_tree().process_frame

			while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if leaving_scene or not is_inside_tree():
					return false

				await get_tree().process_frame

			return true

		await get_tree().process_frame

	return false


func _on_button_pressed() -> void:
	if leaving_scene:
		return

	skip.emit()

	await fade_to_black()
	_go_to_next_scene()
