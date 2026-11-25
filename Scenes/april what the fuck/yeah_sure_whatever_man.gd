@tool
extends CanvasLayer

const SECRET_WORD := "masochism"

# Index of each reaction inside reaction_lines. Add new ones to the end.
enum Reaction { TURNED_ON = 0 }
enum ScreenCorner { BOTTOM_LEFT, BOTTOM_RIGHT }

@export var active: bool = false:
	set(value):
		active = value
		_sync_active_state()

@export var Rodney: Sprite2D
@export var notTalking: Texture2D
@export var unfortunatelyTalking: Texture2D
@export var blink: Texture2D

@export_range(0.0, 1.0, 0.05) var speak_chance: float = 0.4

@export_group("Position")
@export var corner: ScreenCorner = ScreenCorner.BOTTOM_LEFT
@export var margin: Vector2 = Vector2(24.0, 24.0)
@export var lift: float = 20.0

@export_group("Tilt")
@export var talk_tilt: float = 15.0
@export var overshoot_min: float = 2.0
@export var overshoot_max: float = 6.0
@export var swing_time: float = 0.15
@export var settle_time: float = 0.12

@export_group("Bob")
@export var bob_amplitude: float = 4.0  # pixels up and down
@export var bob_speed: float = 0.25     # cycles per second (0.25 = 4 sec per bob)

@export_group("Blink")
@export var blink_time: float = 0.15    # how long the eyes stay shut

@export_group("Lines")
# Random chatter, picked at random.
@export var idle_lines: Array[DialogueLines] = []:
	set(value):
		idle_lines = value
		_fill_null_lines(idle_lines)

# Triggered lines. Element 0 = turned on (see Reaction enum).
@export var reaction_lines: Array[DialogueLines] = []:
	set(value):
		reaction_lines = value
		_fill_null_lines(reaction_lines)

var blinking: bool = false
var talking: bool = false
var subtitle: Label
var typed_buffer: String = ""
var _line_id: int = 0
var _sub_id: int = 0
var _base_rotation: float = 0.0
var _base_captured: bool = false
var _rot_tween: Tween
var _counter_local: Dictionary = {}  # child Node2D -> its original local transform
var _pin_pos: Vector2 = Vector2.ZERO
var _pin_set: bool = false
var _bob_time: float = 0.0

@onready var audio_player: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")
@onready var attempt_timer: Timer = get_node_or_null("AttemptTimer")


func _ready() -> void:
	# Keep the layer fixed to the window, not the game camera.
	follow_viewport_enabled = false
	offset = Vector2.ZERO
	scale = Vector2.ONE
	rotation = 0.0

	if Engine.is_editor_hint():
		_sync_active_state()
		return

	if Rodney != null:
		_base_rotation = Rodney.rotation_degrees
		_base_captured = true
		for child in Rodney.get_children():
			if child is Node2D:
				_counter_local[child] = child.transform

	if audio_player == null:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AudioStreamPlayer"
		add_child(audio_player)

	if attempt_timer == null:
		attempt_timer = Timer.new()
		attempt_timer.name = "AttemptTimer"
		add_child(attempt_timer)
	
	if not Engine.is_editor_hint():
		_move_to_bottom.call_deferred()
		get_tree().node_added.connect(_on_node_added)

	_make_subtitle()
	_sync_active_state()
	_pin_to_corner.call_deferred()

	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_pin_to_corner):
		vp.size_changed.connect(_pin_to_corner)

	var root_win := get_tree().root
	if root_win and not root_win.size_changed.is_connected(_pin_to_corner):
		root_win.size_changed.connect(_pin_to_corner)

	if not audio_player.finished.is_connected(_on_audio_finished):
		audio_player.finished.connect(_on_audio_finished)

	attempt_timer.wait_time = 10.0
	attempt_timer.one_shot = false
	if not attempt_timer.timeout.is_connected(_on_attempt_timer_timeout):
		attempt_timer.timeout.connect(_on_attempt_timer_timeout)

	if active:
		attempt_timer.start()

func _on_node_added(node: Node) -> void:
	# A new scene was added to the root, so drop back below it.
	if node != self and node.get_parent() == get_tree().root:
		_move_to_bottom.call_deferred()


func _move_to_bottom() -> void:
	var root := get_tree().root
	if get_parent() != root:
		return
	if root.get_child(root.get_child_count() - 1) != self:
		root.move_child(self, root.get_child_count() - 1)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or Rodney == null:
		return

	# Slow bob. The children follow because they're positioned relative to Rodney.
	if _pin_set:
		_bob_time += delta
		var bob := sin(_bob_time * TAU * bob_speed) * bob_amplitude
		Rodney.position = _pin_pos + Vector2(0.0, bob)

	# Cancel Rodney's tilt on the neck/body so only the head rotates.
	if _counter_local.is_empty():
		return
	var unrotated := Transform2D(deg_to_rad(_base_rotation), Rodney.scale, Rodney.skew, Rodney.position)
	var fix := Rodney.transform.affine_inverse() * unrotated
	for child: Node2D in _counter_local:
		child.transform = fix * _counter_local[child]


# ---------- Input ----------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or active:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.unicode <= 0:
		return

	typed_buffer += char(event.unicode).to_lower()
	if typed_buffer.length() > SECRET_WORD.length():
		typed_buffer = typed_buffer.substr(typed_buffer.length() - SECRET_WORD.length())

	if typed_buffer == SECRET_WORD:
		typed_buffer = ""
		turn_on()


func turn_on() -> void:
	if active:
		return
	active = true
	play_reaction(Reaction.TURNED_ON)


# ---------- State ----------

func _sync_active_state() -> void:
	if Rodney != null:
		Rodney.visible = active and not Engine.is_editor_hint()
	if attempt_timer != null:
		if active and not Engine.is_editor_hint():
			if attempt_timer.is_stopped():
				attempt_timer.start()
		else:
			attempt_timer.stop()
	if not active and audio_player != null and audio_player.playing:
		audio_player.stop()
	if not active:
		_line_id += 1  # cancels any pending blink/line sequences
		_sub_id += 1   # cancels any pending subtitle segments
		talking = false
		blinking = false
		if subtitle:
			subtitle.visible = false
		if Rodney != null and notTalking != null:
			Rodney.texture = notTalking
		# Snap back to the original angle when switched off.
		if _base_captured and Rodney != null:
			if _rot_tween and _rot_tween.is_valid():
				_rot_tween.kill()
			Rodney.rotation_degrees = _base_rotation
	if active:
		_pin_to_corner.call_deferred()


func _fill_null_lines(arr: Array[DialogueLines]) -> void:
	for i in range(arr.size()):
		if arr[i] == null:
			arr[i] = DialogueLines.new()


# ---------- Rotation ----------

# Swings past `target` by a random amount, then settles onto it.
func _rotate_to(target: float) -> void:
	if Rodney == null:
		return
	if _rot_tween and _rot_tween.is_valid():
		_rot_tween.kill()

	var dir := signf(target - Rodney.rotation_degrees)
	if dir == 0.0:
		dir = 1.0
	var overshoot_angle := target + dir * randf_range(overshoot_min, overshoot_max)

	_rot_tween = create_tween()
	_rot_tween.tween_property(Rodney, "rotation_degrees", overshoot_angle, swing_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_rot_tween.tween_property(Rodney, "rotation_degrees", target, settle_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------- Layout ----------

func _pin_to_corner() -> void:
	_place_subtitle()
	if Rodney == null or Rodney.texture == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size == Vector2.ZERO:
		return
	var tex_size: Vector2 = Rodney.texture.get_size() * Rodney.scale.abs()
	var half := tex_size * 0.5 if Rodney.centered else Vector2.ZERO

	var x: float
	if corner == ScreenCorner.BOTTOM_LEFT:
		x = margin.x + half.x
	else:
		x = vp_size.x - tex_size.x + half.x - margin.x

	var y: float = vp_size.y - tex_size.y + half.y - (margin.y + lift)
	_pin_pos = Vector2(x, y)
	_pin_set = true
	Rodney.position = _pin_pos  # _process adds the bob on top of this


func _make_subtitle() -> void:
	subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle.add_theme_constant_override("outline_size", 8)
	subtitle.visible = false
	add_child(subtitle)


func _place_subtitle() -> void:
	if subtitle == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	subtitle.custom_minimum_size.x = vp_size.x * 0.8
	subtitle.size = Vector2(vp_size.x * 0.8, 0.0)
	subtitle.position = Vector2(
		(vp_size.x - subtitle.size.x) * 0.5,
		vp_size.y - subtitle.size.y - 48.0
	)


# Shows each line of text in turn. Uses segment_times when given,
# otherwise splits `total` seconds in proportion to character count.
func _run_subtitles(line: DialogueLines, this_id: int, total: float) -> void:
	var parts: Array[String] = []
	for p in line.text.split("\n"):
		var s := p.strip_edges()
		if s != "":
			parts.append(s)
	if parts.is_empty():
		return

	_sub_id += 1
	var my_id := _sub_id

	var total_chars := 0
	for p in parts:
		total_chars += p.length()

	for i in range(parts.size()):
		if my_id != _sub_id or this_id != _line_id or not active:
			return
		subtitle.text = parts[i]
		subtitle.visible = true
		_place_subtitle.call_deferred()

		var dur: float
		if i < line.segment_times.size():
			dur = line.segment_times[i]
		else:
			dur = total * float(parts[i].length()) / float(total_chars)
		await get_tree().create_timer(dur).timeout


# ---------- Blinking ----------

# Shows the blink texture for blink_time. The caller sets the texture afterwards.
func _blink() -> void:
	if blink == null or Rodney == null:
		return
	blinking = true
	Rodney.texture = blink
	await get_tree().create_timer(blink_time).timeout
	blinking = false


# ---------- Speaking ----------

func _on_attempt_timer_timeout() -> void:
	if Engine.is_editor_hint() or not active or talking or idle_lines.is_empty():
		return
	if randf() < speak_chance:
		play_idle()


func play_idle() -> void:
	if idle_lines.is_empty():
		return
	_play(idle_lines[randi() % idle_lines.size()], false)


func play_reaction(index: int) -> void:
	if index < 0 or index >= reaction_lines.size():
		push_warning("Rodney: no reaction line at index %d" % index)
		return
	# Reactions cut off whatever he was saying.
	_play(reaction_lines[index], true)


func _play(line: DialogueLines, interrupt: bool) -> void:
	if not active or line == null or Rodney == null:
		return
	if talking and not interrupt:
		return

	if audio_player.playing:
		audio_player.stop()

	_line_id += 1
	_sub_id += 1  # cancels subtitles from any line this one interrupts
	var this_id := _line_id
	talking = true  # set now so the idle timer can't start another line mid-blink

	# Blink first, then start moving and talking.
	await _blink()
	if this_id != _line_id or not active:
		return

	if unfortunatelyTalking:
		Rodney.texture = unfortunatelyTalking
	_rotate_to(_base_rotation + talk_tilt)

	print(line.text)

	var total: float
	if line.audio != null:
		total = line.audio.get_length()
	else:
		total = maxf(1.5, line.text.length() * 0.06)

	_run_subtitles(line, this_id, total)

	if line.audio != null:
		audio_player.stream = line.audio
		audio_player.play()
	else:
		# No audio assigned: end the line after a time based on text length.
		get_tree().create_timer(total).timeout.connect(
			func() -> void:
				if this_id == _line_id:
					_on_audio_finished()
		)


func _on_audio_finished() -> void:
	var this_id := _line_id
	_sub_id += 1  # cancels any segment still waiting
	if subtitle:
		subtitle.visible = false

	# Blink first, then return to idle.
	await _blink()
	if this_id != _line_id or not active:
		return

	talking = false
	if Rodney and notTalking:
		Rodney.texture = notTalking
	_rotate_to(_base_rotation)
