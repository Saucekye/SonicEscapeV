class_name FloweryLyrics
extends Node2D

# Works with AudioStreamPlayer or AudioStreamPlayer2D
@export var music: Node
@export var label: RichTextLabel
@export var guide: ColorRect # optional editor-only guide, hidden when the game runs
@export var sung_color: Color = Color.YELLOW
@export var highlight_syllables: bool = true
@export var font_size: int = 28
@export var lyric_offset: float = 0.0 # seconds; raise if text feels late, lower if early

# [start_time, text]. "-" splits syllables. Times are the GML values (the -0.02 is applied in _process).
const LINES := [
	[0.0, ""],
	[24.0, "Ten feet twen-ty the Flow-er Man"],
	[27.38, "Is wai-ting for the touch of his hand"],
	[30.75, "Straight-en-ing pe-tals out with-out a plan"],
	[33.75, "Like the eve-ry dai-ly"],
	[36.0, "Wish that both-ers the Flow-er Man"],
	[39.38, "Could I do some-thing to make him laugh"],
	[42.75, "In-side my lit-tle cham-ber made of glass"],
	[45.75, "So he lived the"],
	[47.25, "Flow-er Man, Flow-er Man"],
	[50.25, "With his heart in the sand"],
	[53.06, "So he stands"],
	[55.12, "To watch the whole wide world"],
	[57.94, "From a can"],
	[59.25, "Way up high in the sky"],
	[62.25, "With the sun in his eyes"],
	[65.06, "Ain't it nice"],
	[67.12, "The life for-ev-er for"],
	[70.5, "Flow-ers"],
	[72.0, ""],
	[144.0, "Ten feet twen-ty the Flow-er Man"],
	[147.38, "Is wait-ing for the touch of his hand"],
	[150.75, "Fall-en to pie-ces still with-out a plan"],
	[153.75, "Yet the eve-ry dai-ly"],
	[156.0, "Hope that pow-ered the Flow-er Man"],
	[159.38, "Would nev-er cow-er off of its path"],
	[162.75, "Even if bro-ken I am more than glass"],
	[165.75, "So he lived the"],
	[167.25, "Flow-er Man, Flow-er Man"],
	[170.25, "With his heart in the sand"],
	[173.06, "So he stands"],
	[175.12, "To watch the whole wide world"],
	[177.94, "From a can"],
	[179.25, "Way up high in the sky"],
	[182.25, "With the sun in your eyes"],
	[185.06, "Ain't it nice"],
	[187.12, "The life for-ev-er for"],
	[190.5, "Flow-ers"],
	[192.0, ""],
]

# One entry per syllable for the first half of the song.
# The second half is the same pattern shifted by +120 s (built in _ready).
var _note_time_a: Array = [24, 24.38, 24.75, 25.03, 25.31, 25.5, 25.88, 26.25, 27.38, 27.75, 28.12, 28.5, 28.78, 29.06, 29.44, 29.62, 30, 30.75, 31.03, 31.31, 31.5, 31.78, 32.06, 32.44, 32.62, 32.81, 33, 33.75, 34.12, 34.5, 34.88, 35.25, 35.62, 36, 36.38, 36.75, 37.03, 37.31, 37.5, 37.88, 38.25, 39.38, 39.75, 40.12, 40.5, 40.78, 41.06, 41.44, 41.62, 42, 42.75, 43.03, 43.31, 43.5, 43.78, 44.06, 44.44, 44.62, 44.81, 45, 45.75, 46.12, 46.5, 46.88, 47.25, 47.62, 48, 48.75, 49.12, 49.5, 50.25, 50.53, 50.81, 51.75, 52.03, 52.31, 53.06, 53.62, 54, 55.12, 55.5, 55.88, 56.25, 56.62, 56.91, 57.94, 58.12, 58.31, 59.25, 59.62, 60, 60.75, 61.12, 61.5, 62.25, 62.53, 62.81, 63.75, 64.03, 64.31, 65.06, 65.62, 66, 67.12, 67.5, 67.88, 68.25, 68.62, 69, 70.5, 71.25]

var _note_time: Array = []

var _plain: Array[String] = []         # each line without hyphens
var _syl_ends: Array = []              # per line: char index where each syllable ends
var _line_first_note: Array[int] = []  # index in _note_time of each line's first syllable

var _line := -1


func _ready() -> void:
	# Build the full note list
	for t in _note_time_a:
		_note_time.append(float(t))
	for t in _note_time_a:
		_note_time.append(float(t) + 120.0)

	_parse()

	if guide:
		guide.visible = false

	if label:
		# Make sure nothing inherited from the editor is rotating/squeezing it
		label.rotation = 0.0
		label.scale = Vector2.ONE
		label.set_anchors_preset(Control.PRESET_TOP_LEFT) # anchors back to 0,0 so only position/size matter

		label.bbcode_enabled = true
		label.scroll_active = false
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("normal_font_size", font_size)
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.text = ""

		# Explicit full-width strip near the bottom of the screen
		var vp := get_viewport().get_visible_rect().size
		label.position = Vector2(0.0, vp.y - 120.0)
		label.size = Vector2(vp.x, 90.0)
		
	set_process(false)


func _parse() -> void:
	var note_counter := 0
	for entry in LINES:
		var text: String = entry[1]
		var plain := ""
		var ends: Array[int] = []
		var words := text.split(" ", false)
		for w in words.size():
			if w > 0:
				plain += " "
			for syl in words[w].split("-"):
				plain += syl
				ends.append(plain.length())
		_plain.append(plain)
		_syl_ends.append(ends)
		_line_first_note.append(note_counter)
		note_counter += ends.size()

	if note_counter != _note_time.size():
		push_warning("FloweryLyrics: %d syllables but %d notes" % [note_counter, _note_time.size()])


func start(from_time: float = 0.0) -> void:
	_line = -1
	if label:
		label.text = ""
	music.volume_db = 0.0
	music.play(from_time)
	set_process(true)


func stop(fade_time: float = 0.0) -> void:
	set_process(false)
	if label:
		label.text = ""
	if fade_time > 0.0:
		var tw := create_tween()
		tw.tween_property(music, "volume_db", -60.0, fade_time)
		tw.tween_callback(music.stop)
	else:
		music.stop()


# Song time, compensated for audio latency so the text matches what you hear.
func song_time() -> float:
	return music.get_playback_position() \
		+ AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency() \
		+ lyric_offset


func _process(_delta: float) -> void:
	if not music.playing or label == null:
		return
	var t := song_time()

	# Advance the line
	while _line + 1 < LINES.size() and t >= LINES[_line + 1][0] - 0.02:
		_line += 1

	if _line < 0:
		return

	var plain: String = _plain[_line]

	if not highlight_syllables:
		label.text = "[center]%s[/center]" % plain
		return

	# Advance the syllable highlight inside the current line
	var ends: Array = _syl_ends[_line]
	var first: int = _line_first_note[_line]
	var sung := 0
	while sung < ends.size() and first + sung < _note_time.size() and t >= _note_time[first + sung]:
		sung += 1

	var cut: int = ends[sung - 1] if sung > 0 else 0
	label.text = "[center][color=#%s]%s[/color]%s[/center]" % [
		sung_color.to_html(false), plain.substr(0, cut), plain.substr(cut)]
