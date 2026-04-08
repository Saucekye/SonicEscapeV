extends Node2D

var player: CharacterBody2D
@export var offset: Vector2 = Vector2(-100, -150)
@export var rotation_speed := 5.0
@export var base_speed := 1.5
@export var max_speed := 4
@export var acceleration := 1
@export var direction_change_threshold := 0.3
var current_speed := base_speed
var last_direction := Vector2.ZERO

func _ready() -> void:
	# Wait multiple frames to ensure all character scripts are initialized
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find initial player using group system
	player = _find_active_player()
	
	if player:
		global_position = player.global_position + offset
		
	$AudioStreamPlayer2D.play()

func _find_active_player() -> CharacterBody2D:
	# Use the group system - much more reliable!
	var players = get_tree().get_nodes_in_group("active_player")
	if players.size() > 0 and is_instance_valid(players[0]):
		return players[0]
	
	# Fallback: Check all CharacterBody2D nodes for is_player property
	var all_characters = get_tree().get_nodes_in_group("all_characters")
	for body in all_characters:
		if is_instance_valid(body) and "is_player" in body and body.is_player == true:
			return body
	
	return null

func _process(delta: float) -> void:
	if Test.ridenemies == true:
		queue_free()
		return
	
	# Check every frame for the active player
	var active_player = _find_active_player()
	
	# Switch to new player if it changed
	if active_player != player:
		player = active_player
		# Reset speed when switching targets
		current_speed = base_speed
		last_direction = Vector2.ZERO
	
	if not player or not is_instance_valid(player):
		return
	
	var direction = player.global_position - global_position
	
	if last_direction != Vector2.ZERO:
		var direction_normalized = direction.normalized()
		var angle_difference = abs(direction_normalized.angle_to(last_direction.normalized()))
		
		if angle_difference > direction_change_threshold:
			current_speed = base_speed
		else:
			current_speed = min(current_speed + acceleration * delta, max_speed)
	
	last_direction = direction
	
	global_position = global_position.lerp(player.global_position, current_speed * delta)
	
	var target_rotation = direction.angle()
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	
	if direction.x < 0:
		scale.y = -abs(scale.y)
	else:
		scale.y = abs(scale.y)

func _on_area_2d_body_entered(body: Node2D) -> void:
	# Check if the body is in the active_player group OR has is_player = true
	if body.is_in_group("Player") == true:
		if body.is_player == true:
			var scene = load("res://exe/exescreen.tscn")
			var instance = scene.instantiate()
			get_parent().get_node("CanvasLayer").add_child(instance)
			Test.fail = true
			Test.end = true
