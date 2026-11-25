class_name RhythmSong
extends Resource
# A song for the Salvage TV and its rhythm game

@export var title := ""                       ## shown scrolling along the bottom of the TV
@export var song: AudioStream                 ## the music
@export_file("*.osu") var chart := ""         ## the osu!mania chart for it
@export var offset_ms := 0.0                  ## arrows early? raise this
@export var clip_beats := 4.0                 ## the TV's clip dances one loop every this many beats

var _chart: RhythmChart


# The music: yours, or the one the chart was made for
func music() -> AudioStream:
	if song == null and chart != "":
		var file := notes().audio_file
		var path := chart.get_base_dir().path_join(file)
		if file != "" and ResourceLoader.exists(path):
			song = load(path)
	return song


# The name on the TV
func shown_title() -> String:
	return title if title != "" else notes().song_title


# The arrows
func notes() -> RhythmChart:
	if _chart == null:
		_chart = RhythmChart.from_osu(chart, offset_ms / 1000.0) if chart != "" else RhythmChart.new()
	return _chart
