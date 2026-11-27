class_name RhythmChart
extends Resource
# The notes for the TV's rhythm game

@export var times: PackedFloat32Array = []
@export var lanes: PackedInt32Array = []
@export var ends: PackedFloat32Array = []
var bpm := 0.0          # the chart's tempo
var first_beat := 0.0   # seconds into the song of the first beat
var audio_file := ""    # the chart's song file
var song_title := ""    # "ARTIST - TITLE", from the chart


# An osu!mania chart
static func from_osu(path: String, offset := 0.0) -> RhythmChart:
	var c := RhythmChart.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("RhythmChart: can't open %s" % path)
		return c
	var section := ""
	var keys := 4
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("//"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line
			continue
		match section:
			"[General]":
				if line.begins_with("AudioFilename:"):
					c.audio_file = line.get_slice(":", 1).strip_edges()
			"[Metadata]":
				if line.begins_with("Title:"):
					c.song_title = line.substr(6).strip_edges() + c.song_title
				elif line.begins_with("Artist:"):
					c.song_title = c.song_title + "|" + line.substr(7).strip_edges()
			"[Difficulty]":
				if line.begins_with("CircleSize:"):
					keys = maxi(int(line.get_slice(":", 1).strip_edges()), 1)
			"[TimingPoints]":
				var tp := line.split(",")
				# The first red line
				if c.bpm == 0.0 and tp.size() >= 2 and (tp.size() < 7 or tp[6] == "1") and float(tp[1]) > 0.0:
					var bpm := 60000.0 / float(tp[1])
					while bpm > 200.0:
						bpm *= 0.5
					while bpm < 100.0:
						bpm *= 2.0
					c.bpm = bpm
					c.first_beat = float(tp[0]) / 1000.0 + offset
			"[HitObjects]":
				var h := line.split(",")
				if h.size() < 5:
					continue
				var lane := clampi(int(float(h[0]) * keys / 512.0), 0, keys - 1) % 4
				var at := float(h[2]) / 1000.0 + offset
				var end := 0.0
				if int(h[3]) & 128 and h.size() >= 6:
					end = float(h[5].get_slice(":", 0)) / 1000.0 + offset   # a hold
				c.times.append(at)
				c.lanes.append(lane)
				c.ends.append(end)
	# "Title|Artist"
	var parts := c.song_title.split("|")
	if parts.size() == 2:
		c.song_title = (parts[1] + " - " + parts[0]) if parts[1] != "" else parts[0]
	c.song_title = c.song_title.replace("|", "").to_upper()
	return c
