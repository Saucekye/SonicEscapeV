extends Control
# The TV's rhythm game, Friday Night Funkin' style

signal finished
signal graded(grade: String)     # the song finished

const LANE_COLORS := [Color(0.85, 0.45, 1.0), Color(0.3, 0.85, 1.0), Color(0.4, 1.0, 0.45), Color(1.0, 0.4, 0.42)]
# The arrows: the touch screen's own buttons
const ARROW_TEX := ["res://misc/Left.png", "res://misc/Down.png", "res://Sprites/UI/TouchScreen/Up.png", "res://misc/Right.png"]
const ARROW_TEX_ON := ["res://misc/Left2.png", "res://misc/Down2.png", "res://Sprites/UI/TouchScreen/Up2.png", "res://misc/Right2.png"]
const RECEPTOR_TINT := Color(0.6, 0.6, 0.66)
# How far off a press can be
const JUDGES := [[0.05, "SICK!!", 350, 1.0, Color(0.6, 1.0, 1.0)], [0.095, "GOOD", 200, 0.75, Color(0.55, 1.0, 0.45)],
		[0.14, "BAD", 50, 0.4, Color(1.0, 0.75, 0.35)]]
const MISS_AFTER := 0.14
const COUNT_IN := 4                    # beats counted in before the song starts again

var player: Node                      # salvage_player.gd
var music: AudioStreamPlayer3D        # the TV's song
var chart: RhythmChart
var bpm := 150.0
var first_beat := 0.0
var font: Font

var _clock := -10.0                   # seconds into the song
var _started := false
var _last_pos := 0.0
var _next := 0                        # first note not yet hit or missed
var _done: PackedByteArray = []       # 1 = hit or missed
var _notes := {}                      # note index -> its arrow on screen
var _tails := {}                      # hold note index -> its trail
var _holding := {}                    # lane -> the hold note being held down in it
const HOLD_SCORE := 150               # for holding a long note right to its end
var _score := 0
var _combo := 0
var _best_combo := 0
var _misses := 0
var _judged := 0
var _points := 0.0
var _ending := -1.0                   # >= 0: showing the results, seconds left

var _arrow_size := 90.0
var _receptor_y := 120.0
var _speed := 1000.0                  # pixels per second
var _area := Vector2(1280, 720)
var _lane_x: Array[float] = []
var _receptors: Array[Node2D] = []
var _judge: Label
var _combo_label: Label
var _info: Label
var _count: Label
var _score_label: Label              # the score, along the top
var _left: Label                      # how long the song has left
var _bar: ColorRect                   # and how far through it you are
var _end_time := 0.0
var _field: Node2D
var _tex: Array[Texture2D] = []
var _tex_on: Array[Texture2D] = []


func setup(p: Node, song_player: AudioStreamPlayer3D, notes: RhythmChart, tempo: float, beat0: float) -> void:
	player = p
	music = song_player
	chart = notes
	bpm = tempo
	first_beat = beat0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://Fonts/diest64.ttf")
	var area: Vector2 = (get_parent() as Control).size if get_parent() is Control else get_viewport_rect().size
	if area.x <= 0.0:
		area = get_viewport_rect().size
	_area = area
	position = Vector2.ZERO
	size = area
	_arrow_size = area.y * 0.1
	_receptor_y = area.y * 0.15
	_speed = area.y * 1.15
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.size = area
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_field = Node2D.new()
	add_child(_field)
	for i in 4:
		_tex.append(load(ARROW_TEX[i]))
		_tex_on.append(load(ARROW_TEX_ON[i]))
	var gap := _arrow_size * 1.25
	var x0: float = area.x * 0.5 - gap * 1.5   # the arrows down the middle
	for i in 4:
		_lane_x.append(x0 + gap * i)
		var r := _make_arrow(i, RECEPTOR_TINT)
		r.position = Vector2(_lane_x[i], _receptor_y)
		_field.add_child(r)
		_receptors.append(r)
	_judge = _text(area.y * 0.07, Color.WHITE)
	_judge.position = Vector2(area.x * 0.03, area.y * 0.38)
	_judge.size = Vector2(area.x * 0.3, area.y * 0.1)
	_combo_label = _text(area.y * 0.045, Color.WHITE)
	_combo_label.position = Vector2(area.x * 0.03, area.y * 0.48)
	_combo_label.size = Vector2(area.x * 0.3, area.y * 0.07)
	_info = _text(area.y * 0.03, Color(1, 1, 1, 0.9))
	_info.position = Vector2(0, area.y * 0.9)
	_info.size = Vector2(area.x, area.y * 0.05)
	_score_label = _text(area.y * 0.045, Color.WHITE)
	_score_label.position = Vector2(0, area.y * 0.005)
	_score_label.size = Vector2(area.x, area.y * 0.06)
	_count = _text(area.y * 0.16, Color(1.0, 0.8, 0.3))
	_count.position = Vector2(0, area.y * 0.35)
	_count.size = Vector2(area.x, area.y * 0.25)
	# Time left, right of the arrows
	_end_time = _last_note_time() + 1.0
	if music.stream and music.stream.get_length() > 0.0:
		_end_time = minf(_end_time, music.stream.get_length())
	_left = _text(area.y * 0.05, Color(1, 1, 1, 0.9))
	_left.position = Vector2(area.x * 0.67, area.y * 0.38)
	_left.size = Vector2(area.x * 0.3, area.y * 0.08)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.18)
	track.position = Vector2(area.x * 0.72, area.y * 0.47)
	track.size = Vector2(area.x * 0.2, area.y * 0.012)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.get_parent().add_child(track)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.8, 0.3)
	_bar.size = Vector2(0, track.size.y)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_bar)
	_show_left()
	_done.resize(chart.times.size())
	_done.fill(0)
	# Count in over the end of whatever's playing, then the song starts from the top
	music.stop()
	_clock = -COUNT_IN * 60.0 / bpm
	_update_info()


func _text(px: float, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(px))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(int(px * 0.12), 4))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l


# An arrow: the touch screen's button for that direction, in the lane's colour
func _make_arrow(lane: int, color: Color) -> Node2D:
	var spr := Sprite2D.new()
	spr.texture = _tex[lane]
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE * (_arrow_size / float(maxi(_tex[lane].get_height(), 1)))
	spr.self_modulate = color
	var root := Node2D.new()
	root.add_child(spr)
	spr.name = "Fill"
	return root


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.dead or player.escaped or is_instance_valid(player.knocked):
		finished.emit()
		queue_free()
		return
	if _ending >= 0.0:
		_ending -= delta
		if _ending <= 0.0:
			finished.emit()
			queue_free()
		return
	# The clock: counting in, then the song's own position
	if not _started:
		_clock += delta
		var beats_left := ceili(-_clock * bpm / 60.0)
		_count.text = str(beats_left - 1) if beats_left > 1 else "GO!"
		_count.modulate.a = 1.0
		if _clock >= 0.0:
			_started = true
			music.play(0.0)
			_count.text = ""
	else:
		var pos := music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		if pos < _last_pos - 5.0 or not music.playing:
			_finish()   # the song came round again
			return
		_last_pos = pos
		_clock = pos
	# Arrows on their way up, and the ones you let past
	var lead := (_area.y + _arrow_size) / _speed
	while _next < chart.times.size() and _done[_next] == 1:
		_next += 1
	var i := _next
	while i < chart.times.size() and chart.times[i] < _clock + lead:
		if _done[i] == 0:
			if _clock - chart.times[i] > MISS_AFTER:
				_miss(i)
			else:
				var a: Node2D = _notes.get(i)
				if a == null:
					a = _make_arrow(chart.lanes[i], LANE_COLORS[chart.lanes[i]])
					_field.add_child(a)
					_notes[i] = a
					if _is_hold(i):
						var tail := ColorRect.new()
						tail.color = LANE_COLORS[chart.lanes[i]] * Color(1, 1, 1, 0.55)
						tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
						_field.add_child(tail)
						_field.move_child(tail, 0)   # under the arrows
						_tails[i] = tail
				a.position = Vector2(_lane_x[chart.lanes[i]], _receptor_y + (chart.times[i] - _clock) * _speed)
				_place_tail(i, chart.times[i])
		i += 1
	# Long notes being held
	for lane in _holding.keys():
		var h: int = _holding[lane]
		if _clock >= chart.ends[h]:
			_end_hold(lane, true)
		else:
			_place_tail(h, _clock)
	_show_left()
	# The grey arrows ease back after a press
	for r in _receptors:
		r.scale = r.scale.lerp(Vector2.ONE, clampf(delta * 14.0, 0.0, 1.0))
	_judge.scale = _judge.scale.lerp(Vector2.ONE, clampf(delta * 10.0, 0.0, 1.0))
	if chart.times.size() > 0 and _clock > _last_note_time() + 1.0 and _next >= chart.times.size() and _holding.is_empty():
		_finish()


func _input(event: InputEvent) -> void:
	if _ending >= 0.0 or player == null:
		return
	var lane := -1
	var acts: String = player.actions
	if event is InputEventJoypadButton:
		if event.device != player.pad or player.pad < 0:
			return
		var b: int = event.button_index
		if b == JOY_BUTTON_BACK:
			if event.pressed:
				_close()
			get_viewport().set_input_as_handled()
			return
		lane = {JOY_BUTTON_DPAD_LEFT: 0, JOY_BUTTON_X: 0, JOY_BUTTON_DPAD_DOWN: 1, JOY_BUTTON_A: 1,
				JOY_BUTTON_DPAD_UP: 2, JOY_BUTTON_Y: 2, JOY_BUTTON_DPAD_RIGHT: 3, JOY_BUTTON_B: 3}.get(b, -1)
		if lane < 0:
			return
		_press(lane, event.pressed)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or event.echo:
		return
	if event.pressed and event.is_action(acts + "interact"):
		_close()
		get_viewport().set_input_as_handled()
		return
	# The arrow keys always work
	if player.use_mouse:
		var arrow: int = {KEY_LEFT: 0, KEY_DOWN: 1, KEY_UP: 2, KEY_RIGHT: 3}.get(event.physical_keycode, -1)
		if arrow >= 0:
			_press(arrow, event.pressed)
			get_viewport().set_input_as_handled()
			return
	for l in 4:
		if event.is_action([acts + "left", acts + "back", acts + "forward", acts + "right"][l]):
			_press(l, event.pressed)
			get_viewport().set_input_as_handled()
			return


func _press(lane: int, down: bool) -> void:
	var r := _receptors[lane]
	var fill := r.get_node("Fill") as Sprite2D
	if not down:
		fill.texture = _tex[lane]
		fill.self_modulate = RECEPTOR_TINT
		if _holding.has(lane):
			var h: int = _holding[lane]
			_end_hold(lane, _clock >= chart.ends[h] - 0.12)
		return
	fill.texture = _tex_on[lane]
	fill.self_modulate = LANE_COLORS[lane]
	r.scale = Vector2.ONE * 0.9
	if not _started and _clock < -0.2:
		return
	# Judged against the song right now, not where it was at the start of this frame
	if _started and music.playing:
		_clock = music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	# The closest arrow in this lane that's near enough
	var best := -1
	var best_off := 1.0
	var i := _next
	while i < chart.times.size() and chart.times[i] < _clock + MISS_AFTER:
		if _done[i] == 0 and chart.lanes[i] == lane:
			var off := absf(chart.times[i] - _clock)
			if off < best_off:
				best_off = off
				best = i
		i += 1
	if best < 0 or best_off > MISS_AFTER:
		return   # pressing between arrows costs nothing
	for j in JUDGES:
		if best_off <= j[0]:
			_hit(best, j)
			break
	r.scale = Vector2.ONE * 1.12
	fill.self_modulate = Color(1, 1, 1)


func _is_hold(i: int) -> bool:
	return i < chart.ends.size() and chart.ends[i] > chart.times[i] + 0.05


# A long note's trail, from where its top is now down to its end
func _place_tail(i: int, from_time: float) -> void:
	var tail: ColorRect = _tails.get(i)
	if tail == null:
		return
	var w := _arrow_size * 0.3
	var top := _receptor_y + (from_time - _clock) * _speed
	var bottom := _receptor_y + (chart.ends[i] - _clock) * _speed
	tail.position = Vector2(_lane_x[chart.lanes[i]] - w * 0.5, top)
	tail.size = Vector2(w, maxf(bottom - top, 0.0))


# Let go of a long note
func _end_hold(lane: int, held_to_end: bool) -> void:
	var h: int = _holding[lane]
	_holding.erase(lane)
	if _tails.has(h):
		_tails[h].queue_free()
		_tails.erase(h)
	if held_to_end:
		_score += HOLD_SCORE
		_update_info()


func _show_left() -> void:
	var left := maxf(_end_time - maxf(_clock, 0.0), 0.0)
	_left.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	_bar.size.x = _bar.get_parent().size.x * clampf(maxf(_clock, 0.0) / maxf(_end_time, 0.01), 0.0, 1.0)


func _last_note_time() -> float:
	var last := 0.0
	for k in chart.times.size():
		last = maxf(last, maxf(chart.times[k], chart.ends[k] if k < chart.ends.size() else 0.0))
	return last


func _hit(i: int, judge: Array) -> void:
	_done[i] = 1
	if _notes.has(i):
		_notes[i].queue_free()
		_notes.erase(i)
	if _is_hold(i):
		_holding[chart.lanes[i]] = i
	_score += judge[2]
	_points += judge[3]
	_judged += 1
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	_show_judge(judge[1], judge[4])
	_update_info()


func _miss(i: int) -> void:
	_done[i] = 1
	if _notes.has(i):
		_notes[i].queue_free()
		_notes.erase(i)
	if _tails.has(i):
		_tails[i].queue_free()
		_tails.erase(i)
	_misses += 1
	_judged += 1
	_combo = 0
	_show_judge("MISS", Color(1.0, 0.3, 0.35))
	_update_info()


func _show_judge(text: String, color: Color) -> void:
	_judge.text = text
	_judge.add_theme_color_override("font_color", color)
	_judge.pivot_offset = _judge.size * 0.5
	_judge.scale = Vector2.ONE * 1.25
	_combo_label.text = str(_combo) if _combo >= 2 else ""


# The rank this accuracy gets at the end
static func _grade(acc: float) -> String:
	return "S" if acc >= 95.0 else ("A" if acc >= 90.0 else ("B" if acc >= 80.0 else ("C" if acc >= 70.0 else "D")))


func _accuracy() -> float:
	return 100.0 * _points / float(_judged) if _judged > 0 else 100.0


func _update_info() -> void:
	var key := "[E] " if player and player.use_mouse else "[BACK] "
	_score_label.text = "Score %d     Rank %s" % [_score, _grade(_accuracy())]   # the rank you'd end on, as it stands
	_info.text = "Misses %d    Accuracy %.1f%%      %sQuit" % [_misses, _accuracy(), key]


# Walk away: straight out, no results
func _close() -> void:
	finished.emit()
	queue_free()
	set_process(false)
	set_process_input(false)


# The song's over
func _finish() -> void:
	if _ending >= 0.0:
		return
	for a in _notes.values():
		a.queue_free()
	_notes.clear()
	for tail in _tails.values():
		tail.queue_free()
	_tails.clear()
	_holding.clear()
	var acc := _accuracy()
	var grade := _grade(acc)
	if _judged == 0:
		finished.emit()
		queue_free()
		return
	_count.add_theme_font_size_override("font_size", int(_area.y * 0.09))
	_count.text = "%s\n%d   max combo %d" % [grade, _score, _best_combo]
	graded.emit(grade)
	_info.text = "Misses %d    Accuracy %.1f%%" % [_misses, acc]
	_judge.text = ""
	_combo_label.text = ""
	_ending = 4.0
