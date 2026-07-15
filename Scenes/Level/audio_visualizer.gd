extends Node2D

@export var audio_player: AudioStreamPlayer

var spectrum_instance
const NUM_BARS = 64  # Number of frequency bands to display
const MAX_FREQ = 1000  # Frequency range to analyze
var bars = []
@export var shuffle_freq = false
@export var flip_y = false

var color_gradient := Gradient.new()  # Dynamic color transitions


func _ready():
	scale = Vector2(1.5, 1.5)
	color_gradient.add_point(0.0, Color(0.2, 1.0, 0.8))  # Cyan
	color_gradient.add_point(0.5, Color(0.6, 0.2, 1.0))  # Purple
	color_gradient.add_point(1.0, Color(1.0, 0.2, 0.2))  # Red
	spectrum_instance = AudioServer.get_bus_effect_instance(1, 0)  # Bus 1, Effect 0
	create_bars()

func create_bars():
	for i in range(NUM_BARS):
		var bar = ColorRect.new()
		bar.pivot_offset.y = 25
		bar.color = Color(0.2, 0.8, 1.0)  # Light blue color
		bar.size = Vector2(1, 50)  # Adjust bar size
		bar.position = Vector2(i*1.5, -25)  # Space bars apart
		add_child(bar)
		bars.append(bar)

func _process(_delta):
	if not spectrum_instance:
		return
	var max_freq_amp = bars.reduce(func(m, b): return b if b.size.y > m.size.y else m).size.y 
	var is_audio_playing = MusicManager and MusicManager.playing and not MusicManager.stream_paused
	
	for i in range(NUM_BARS):
		var target_scale_y = 0.1 # Default flat state when silent or paused
		
		if is_audio_playing:
			var freq_start = (i * MAX_FREQ) / NUM_BARS
			var freq_end = ((i + 1) * MAX_FREQ) / NUM_BARS
			
			var magnitude = spectrum_instance.get_magnitude_for_frequency_range(freq_start, freq_end).length()
			target_scale_y = clamp(magnitude * 25.0, 0.1, 10.0)
		
		bars[i].scale.y = lerp(bars[i].scale.y, target_scale_y, 0.2)
		
		var intensity = bars[i].scale.y / max_freq_amp if max_freq_amp > 0 else 0.0
		intensity = clamp(intensity, 0.0, 1.0)
		
		var new_color = color_gradient.sample(intensity)
		bars[i].color = new_color

	if shuffle_freq:
		bars.shuffle()
