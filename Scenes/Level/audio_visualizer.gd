extends Node2D

@export var audio_player: AudioStreamPlayer
var spectrum_instance
const NUM_BARS = 64  # Number of frequency bands to display
const MAX_FREQ = 1000  # Frequency range to analyze
var bars = []
@export var shuffle_freq = false
@export var flip_y = false

var color_gradient := Gradient.new() 
enum TargetSlot { CHARACTER_ONE, CHARACTER_TWO, CHARACTER_THREE }
@export var target_character_slot: TargetSlot = TargetSlot.CHARACTER_ONE

# Colors for the characters
var character_colors = {
	"Sonic": Color(0.0, 0.478, 1.0, 1.0),
	"Tails": Color(1.0, 1.0, 0.322, 1.0),
	"Knuckles": Color(1.0, 0.0, 0.188, 1.0),
	"Amy": Color(1.0, 0.376, 0.592, 1.0),
	"Blaze": Color(0.502, 0.231, 0.729, 1.0),
	"Rouge": Color(0.314, 0.314, 0.314, 1.0),
	"Silver2": Color(1.0, 1.0, 1.0, 1.0),
	"Cream": Color(1.0, 0.992, 0.816, 1.0),
	"Shadow": Color(0.278, 0.0, 0.0, 1.0),
	"MetalSonic": Color(0.0, 0.0, 0.443, 1.0)
}

var ChosenColor = Color(1, 1, 1, 1)

func _ready():
	scale = Vector2(1.5, 1.5)
	color_gradient.add_point(0.0, Color(0.2, 1.0, 0.8))  # Cyan
	color_gradient.add_point(0.5, Color(0.6, 0.2, 1.0))  # Purple
	color_gradient.add_point(1.0, Color(1.0, 0.2, 0.2))  # Red
	spectrum_instance = AudioServer.get_bus_effect_instance(1, 0) 
	
	create_bars() 

func create_bars():
	for i in range(NUM_BARS):
		var bar = ColorRect.new()
		bar.pivot_offset.y = 25
		bar.color = ChosenColor
		bar.size = Vector2(1, 50)  # Adjust bar size
		bar.position = Vector2(i*1.5, -25)  # Space bars apart
		add_child(bar)
		bars.append(bar)

func _process(_delta):
	var active_player = get_tree().get_first_node_in_group("active_player")
	
	if active_player and active_player.get_script():
		var script_path = active_player.get_script().resource_path.to_lower()
		var identified_char = ""
		
		if "sonic" in script_path:
			if "metal" in script_path: identified_char = "MetalSonic"
			else: identified_char = "Sonic"
		elif "tails" in script_path: identified_char = "Tails"
		elif "knuckles" in script_path: identified_char = "Knuckles"
		elif "amy" in script_path: identified_char = "Amy"
		elif "blaze" in script_path: identified_char = "Blaze"
		elif "rouge" in script_path: identified_char = "Rouge"
		elif "silver" in script_path: identified_char = "Silver2"
		elif "cream" in script_path: identified_char = "Cream"
		elif "shadow" in script_path: identified_char = "Shadow"

		if character_colors.has(identified_char):
			ChosenColor = character_colors[identified_char]

	var max_freq_amp = bars.reduce(func(m, b): return b if b.scale.y > m.scale.y else m).scale.y 
	var is_audio_playing = MusicManager and MusicManager.playing and not MusicManager.stream_paused
	
	for i in range(NUM_BARS):
		var target_scale_y = 0.1
		
		if is_audio_playing:
			var freq_start = (i * MAX_FREQ) / NUM_BARS
			var freq_end = ((i + 1) * MAX_FREQ) / NUM_BARS
			
			var magnitude = spectrum_instance.get_magnitude_for_frequency_range(freq_start, freq_end).length()
			target_scale_y = clamp(magnitude * 25.0, 0.1, 10.0)
		
		bars[i].scale.y = lerp(bars[i].scale.y, target_scale_y, 0.2)
		
		var intensity = bars[i].scale.y / max_freq_amp if max_freq_amp > 0 else 0.0
		intensity = clamp(intensity, 0.0, 1.0)
		bars[i].color = ChosenColor

	if shuffle_freq:
		bars.shuffle()
