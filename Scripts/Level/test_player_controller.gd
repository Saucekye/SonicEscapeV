extends Node2D

signal fast
signal hurt
signal slow

var bestTimeFloat := INF
var bestTimeText := ""
var music = false
var mobile = false
var end = false

@onready var sonic_scene = preload("res://Player.tscn")
@onready var tails_scene = preload("res://Tails/Tails.tscn")
@onready var knuckles_scene = preload("res://Knuckles/Knuckles.tscn")
@onready var amy_scene = preload("res://Amy/amy.tscn")
@onready var blaze_scene = preload("res://Blaze/Blaze.tscn")
@onready var rouge_scene = preload("res://Cream/Cream.tscn")
@onready var metal_scene = preload("res://Metal Sonic/metalsonic.tscn")
@onready var camera = preload("res://camera.tscn")

var sonic_instance: CharacterBody2D
var tails_instance: CharacterBody2D
var knuckles_instance: CharacterBody2D
var amy_instance: CharacterBody2D
var blaze_instance: CharacterBody2D
var metal_instance: CharacterBody2D
var current_character: CharacterBody2D
var camera_instance: Camera2D

# Array to hold all characters for easy cycling
var characters: Array[CharacterBody2D] = []
var current_character_index: int = 0

func _ready() -> void:
	# Spawn Sonic
	sonic_instance = metal_scene.instantiate()
	sonic_instance.scale = Vector2(125, 125)
	sonic_instance.position = Vector2.ZERO
	add_child(sonic_instance)
	characters.append(sonic_instance)
	
	# Spawn Tails
	tails_instance = sonic_scene.instantiate()
	tails_instance.scale = Vector2(125, 125)
	tails_instance.position = Vector2(100, 0)  # Offset slightly from Sonic
	add_child(tails_instance)
	characters.append(tails_instance)
	
	# Set Sonic as the starting character
	current_character_index = 0
	current_character = characters[current_character_index]
	
	# Setup all characters with proper collision layers and states
	setup_characters()
	
	# Set current character as active player
	current_character.is_player = true
	current_character.add_to_group("active_player")
	
	# Setup camera on current character
	camera_instance = camera.instantiate()
	current_character.add_child(camera_instance)
	camera_instance.position = Vector2.ZERO
	
	# Update all character states
	update_character_states()


func setup_characters():
	"""Initialize all characters with proper settings"""
	for i in range(characters.size()):
		var character = characters[i]
		character.is_player = false
		# Each character stays on their own layer: 1, 2, 3
		character.collision_layer = i + 1
		# All characters can collide with world objects (put world objects on layer 4)
		character.collision_mask = 4  # World/environment layer
		character.hide()
		character.set_physics_process(false)
		
		# Set up partner following for non-active characters
		if i != current_character_index:
			character.player_path = current_character.get_path() if current_character else NodePath()

func update_character_states():
	"""Update all character states based on current active character"""
	# First pass: Set all to non-player
	for character in characters:
		character.is_player = false
		character.remove_from_group("active_player")
	
	# Second pass: Set current character as player
	if current_character and is_instance_valid(current_character):
		current_character.is_player = true
		current_character.add_to_group("active_player")
	
	# Third pass: Update visibility and physics
	for i in range(characters.size()):
		var character = characters[i]
		
		if i == current_character_index:
			# Current player character
			character.show()
			character.set_physics_process(true)
		else:
			# Partner characters
			character.show()  # Partners are visible but not controllable
			character.set_physics_process(true)  # They need physics for following
			
			# Set up following behavior
			character.player_path = current_character.get_path()

func _input(event):
	if characters.size() <= 1:
		return  # Don't switch if there's only one character

	if event.is_action_pressed("switch") and current_character.is_on_floor():
		on_player_change()

func on_player_change():
	"""Cycle to the next character in the array"""
	# Store current position for smooth transition
	var current_position = current_character.global_position
	
	# Explicitly remove is_player from old character
	current_character.is_player = false
	current_character.remove_from_group("active_player")
	
	# Move to next character (cycle back to 0 after last character)
	current_character_index = (current_character_index + 1) % characters.size()
	
	# Get new current character
	var new_character = characters[current_character_index]
	
	# Explicitly set is_player on new character BEFORE any other operations
	new_character.is_player = true
	new_character.add_to_group("active_player")
	
	# Optional: Swap positions between old and new character for smooth transition
	# Comment out these lines if you want characters to stay in their current positions
	var temp_position = new_character.global_position
	new_character.global_position = current_position
	current_character.global_position = temp_position
	
	# Update current character reference
	current_character = new_character
	
	# Update all character states
	update_character_states()
	
	# Move camera to new character
	camera_instance.get_parent().remove_child(camera_instance)
	current_character.add_child(camera_instance)
	camera_instance.position = Vector2.ZERO

func on_touch_screen_button_joystick_change(new_pos: Vector2) -> void:
	# Apply input to all characters (current player will use it, partners might need it for following logic)
	for character in characters:
		character.stickdir = new_pos

func on_texture_button_pressed() -> void:
	var input_event = InputEventAction.new()
	input_event.action = "switch"
	input_event.pressed = true
	Input.parse_input_event(input_event)

# Helper function to get current character name (useful for UI/debugging)
func get_current_character_name() -> String:
	match current_character_index:
		0: return "Sonic"
		1: return "Tails"
		2: return "Knuckles"
		3: return "Amy"
		_: return "Unknown"

# Helper function to switch to a specific character by index
func switch_to_character(index: int):
	if index >= 0 and index < characters.size() and index != current_character_index:
		current_character_index = index
		current_character = characters[current_character_index]
		update_character_states()
		
		# Move camera
		camera_instance.get_parent().remove_child(camera_instance)
		current_character.add_child(camera_instance)
		camera_instance.position = Vector2.ZERO

# Collision Setup:
# Character 1 (Sonic): Layer 1, Mask 4 (can collide with world only)
# Character 2 (Tails): Layer 2, Mask 4 (can collide with world only)  
# Character 3 (Knuckles): Layer 3, Mask 4 (can collide with world only)
# World Objects: Should be on Layer 4
# 
# IMPORTANT: Set your platforms, walls, ground, etc. to collision_layer = 4
# This way all characters can walk on platforms but won't collide with each other

func _on_texture_button_pressed() -> void:
	var input_event = InputEventAction.new()
	input_event.action = "switch"
	input_event.pressed = true
	Input.parse_input_event(input_event)


func _on_touch_screen_button_joystick_change(new_pos: Vector2) -> void:
	# Apply input to current character
	if current_character:
		current_character.stickdir = new_pos
	
	# Apply input to all partner characters (non-current characters)
	for i in range(characters.size()):
		if i != current_character_index:  # Skip current character
			characters[i].stickdir = new_pos
			
			
func _process(delta: float) -> void:
	if current_character.time_elpased > 70:
		emit_signal("fast")
	else:
		emit_signal("slow")
		
	if current_character.ouch == true:
		emit_signal("hurt")
