extends Node2D

signal fast
signal hurt
signal slow

var bestTimeFloat := INF
var bestTimeText := ""
var music = false
var mobile = false
var end = false

@onready var camera = preload("res://Scenes/Level/camera.tscn")

var sonic_instance: CharacterBody2D
var tails_instance: CharacterBody2D
var knuckles_instance: CharacterBody2D
var current_character: CharacterBody2D
var camera_instance: Camera2D

# Array to hold all characters for easy cycling
var characters: Array[CharacterBody2D] = []
var current_character_index: int = 0

func _ready() -> void:
	GlobalSignals.connect("black", black)
	var character_order = [Test.characterone, Test.charactertwo, Test.characterthree, Test.characterfour]
	
	for name in character_order:
		var entry := Content.character(name)
		if entry == null or entry.scene == null:
			continue   # empty slot, or a character missing from game_content.tres
		var instance: CharacterBody2D = entry.scene.instantiate()
		instance.set_meta("character_id", name)
		
		if instance:
			instance.scale = Vector2(125, 125)
			add_child(instance)
			characters.append(instance)
			instance.z_index = 0
			# Add to group immediately for easier detection
			instance.add_to_group("all_characters")
	
	if characters.is_empty():
		push_error("No valid characters selected in Select.gd")
		return
	
	# Set initial character index and reference
	self.current_character_index = Test.current_character_index
	current_character = characters[current_character_index]
	current_character.position = Vector2.ZERO

	# Setup characters
	setup_characters()

	# Setup camera
	camera_instance = camera.instantiate()
	current_character.add_child(camera_instance)
	camera_instance.position = Vector2.ZERO
	if camera_instance.enabled:
		camera_instance.make_current()   # the player's camera is the one that shows the level

	update_character_states()
	# Everyone starts facing right, the followers already in their places behind
	for c in characters:
		c.sprite.flip_h = false
		if c != current_character:
			c.position = current_character.position + c.follow_offset

	if not Test.zoom_chosen:
		Test.zoom_level = 1
	# The moves you can do right now, down the right side
	var prompts_layer := CanvasLayer.new()
	prompts_layer.name = "MovePrompts"
	prompts_layer.layer = 11
	add_child(prompts_layer)
	var prompts := preload("res://Scripts/UI/move_prompts.gd").new()
	prompts.controller = self
	prompts_layer.add_child(prompts)
	# A small mark at the bottom of the screen
	var warning := preload("res://Scripts/UI/fall_warning.gd").new()
	warning.name = "FallWarning"
	warning.controller = self
	prompts_layer.add_child(warning)


func setup_characters():
	"""Initialize all characters with proper settings"""
	# Layer mapping: can only be 2, 3, 1
	var character_layers = [2, 3, 1, 1]
	
	for i in range(characters.size()):
		var character = characters[i]
		character.is_player = false
		
		# Each character gets assigned layer 2, 3, or 6
		character.collision_layer = character_layers[i]
		character.stored_layer = character_layers[i]
		
		# All characters can collide with world objects (layer 1)
		character.collision_mask = 4  # World/environment layer
		character.stored_mask = 4
		
		character.hide()
		character.set_physics_process(false)
		
		# Set up partner following for non-active characters
		if i != current_character_index:
			character.player_path = current_character.get_path() if current_character else NodePath()
		
func update_character_states():
	"""Update all character states based on current active character"""
	# First pass: Set all to non-player
	for character in characters:
		character.z_index = 1
		character.is_player = false
		character.remove_from_group("active_player")
	
	# Second pass: Set current character as player
	if current_character and is_instance_valid(current_character):
		current_character.is_player = true
		current_character.add_to_group("active_player")
		current_character.z_index = 10
	
	# Third pass: Update visibility and physics
	var follower_slot := 0
	for i in range(characters.size()):
		var character : Player = characters[i]
		
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
			character.follow_offset = Test.FORMATION_OFFSETS[mini(follower_slot, Test.FORMATION_OFFSETS.size() - 1)]
			
			follower_slot += 1

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
	Test.current_character_index = self.current_character_index
	
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
	
	# Send a signal to update UI elements accordingly to the new character
	GlobalSignals.switch_new_active_player.emit(current_character)
	
	# Update all character states
	update_character_states()
	
	# Move camera to new character
	camera_instance.get_parent().remove_child(camera_instance)
	current_character.add_child(camera_instance)
	camera_instance.position = Vector2.ZERO

# Become a different character where you stand
func swap_character(char_name: String) -> bool:
	var entry := Content.character(char_name)
	if entry == null or entry.scene == null:
		return false
	return swap_to_scene(entry.scene, char_name, false)


# Swap the character you're playing for this scene, where you stand
func swap_to_scene(scene: PackedScene, char_name: String, is_super_form: bool) -> bool:
	if scene == null or current_character == null:
		return false
	var old := current_character
	var fresh: CharacterBody2D = scene.instantiate()
	if is_super_form:
		fresh.add_to_group("super_form")
	fresh.set_meta("character_id", char_name)
	fresh.scale = old.scale
	fresh.add_to_group("all_characters")
	add_child(fresh)
	fresh.global_position = old.global_position
	fresh.collision_layer = old.collision_layer
	fresh.stored_layer = old.stored_layer
	fresh.collision_mask = old.collision_mask
	fresh.stored_mask = old.stored_mask
	if "velocity" in old:
		fresh.velocity = old.velocity
	characters[current_character_index] = fresh
	current_character = fresh
	# Anyone following the old one follows the new one
	for c in characters:
		if c != fresh:
			c.player_path = fresh.get_path()
	camera_instance.get_parent().remove_child(camera_instance)
	fresh.add_child(camera_instance)
	camera_instance.position = Vector2.ZERO
	update_character_states()
	GlobalSignals.switch_new_active_player.emit(fresh)
	old.remove_from_group("active_player")
	old.remove_from_group("all_characters")
	old.queue_free()
	return true


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
	if current_character and current_character.has_meta("character_id"):
		return current_character.get_meta("character_id")
	return "Unknown"

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
			
func black() -> void:
	modulate = Color(0, 0, 0, 1)
	
